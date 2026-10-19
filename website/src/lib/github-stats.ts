import { MAC_REPO, WIN_REPO } from "./platforms";

export const repositories = [
  { id: "macos", name: "macOS", url: MAC_REPO },
  { id: "windows", name: "Windows", url: WIN_REPO },
] as const;

type RepositoryId = (typeof repositories)[number]["id"];
export type RepositoryStats = { id: RepositoryId; downloads: number; stars: number; forks: number; releases: number };
export type GitHubSnapshot = { fetchedAt: number; repositories: RepositoryStats[] };
export type GitHubStatsResult = { snapshot: GitHubSnapshot; stale: boolean };

type Release = { draft?: boolean; assets: { name: string; download_count: number }[] };
const CACHE_KEY = "dclutter:public-github-stats:v2";
const CACHE_MS = 15 * 60 * 1000;
const APP_ASSET = /\.(dmg|zip|exe|msi)$/i;
let pending: Promise<GitHubStatsResult> | null = null;

const isCount = (value: unknown): value is number =>
  typeof value === "number" && Number.isSafeInteger(value) && value >= 0;

function cachedSnapshot(): GitHubSnapshot | null {
  try {
    const raw = sessionStorage.getItem(CACHE_KEY);
    if (!raw) return null;
    const value = JSON.parse(raw) as GitHubSnapshot;
    if (!Number.isFinite(value.fetchedAt) || value.fetchedAt > Date.now() ||
        !Array.isArray(value.repositories) || value.repositories.length !== repositories.length) return null;
    if (!repositories.every((repo) => value.repositories.some((stat) =>
      stat.id === repo.id && isCount(stat.downloads) && isCount(stat.stars) && isCount(stat.forks) && isCount(stat.releases)))) return null;
    return value;
  } catch {
    return null;
  }
}

async function request(path: string, signal: AbortSignal) {
  const response = await fetch(`https://api.github.com/repos/${path}`, {
    headers: { Accept: "application/vnd.github+json" },
    credentials: "omit",
    referrerPolicy: "no-referrer",
    signal,
  });
  if (!response.ok) throw new Error(`GitHub returned ${response.status}`);
  return response.json();
}

async function fetchRepository(repo: (typeof repositories)[number], signal: AbortSignal): Promise<RepositoryStats> {
  const slug = new URL(repo.url).pathname.slice(1);
  const [info, firstPage] = await Promise.all([
    request(slug, signal),
    request(`${slug}/releases?per_page=100&page=1`, signal),
  ]);
  if (!isCount(info.stargazers_count) || !isCount(info.forks_count)) throw new Error("GitHub repository counts unavailable");

  let downloads = 0;
  let publishedReleases = 0;
  let page: Release[] = firstPage;
  let pageNumber = 1;
  while (true) {
    if (!Array.isArray(page)) throw new Error("GitHub releases unavailable");
    for (const release of page) {
      if (release.draft) continue;
      publishedReleases++;
      if (!Array.isArray(release.assets)) throw new Error("GitHub release assets unavailable");
      for (const asset of release.assets) {
        // Count app packages, excluding checksums and update manifests.
        if (APP_ASSET.test(asset.name)) {
          if (!isCount(asset.download_count)) throw new Error("GitHub download count unavailable");
          downloads += asset.download_count;
        }
      }
    }
    if (page.length < 100) break;
    page = await request(`${slug}/releases?per_page=100&page=${++pageNumber}`, signal);
  }
  return { id: repo.id, downloads, stars: info.stargazers_count, forks: info.forks_count, releases: publishedReleases };
}

/** Public aggregate counts only; no credentials, visitor analytics, or backend. */
export function getGitHubStats(): Promise<GitHubStatsResult> {
  if (pending) return pending;
  const cached = cachedSnapshot();
  if (cached && Date.now() - cached.fetchedAt < CACHE_MS) {
    return Promise.resolve({ snapshot: cached, stale: false });
  }

  pending = (async () => {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10000);
    try {
      const stats = await Promise.all(repositories.map((repo) => fetchRepository(repo, controller.signal)));
      const snapshot = { fetchedAt: Date.now(), repositories: stats };
      try {
        sessionStorage.setItem(CACHE_KEY, JSON.stringify(snapshot));
      } catch {
        // Counts still work if browser storage is unavailable.
      }
      return { snapshot, stale: false };
    } catch (error) {
      if (cached) return { snapshot: cached, stale: true };
      throw error;
    } finally {
      clearTimeout(timeout);
      controller.abort();
    }
  })().finally(() => { pending = null; });
  return pending;
}
