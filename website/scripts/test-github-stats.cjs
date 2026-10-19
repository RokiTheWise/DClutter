const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const ts = require("typescript");

const source = fs.readFileSync(path.join(__dirname, "../src/lib/github-stats.ts"), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2020 },
}).outputText;
const repoURLs = {
  MAC_REPO: "https://github.com/RokiTheWise/DClutter",
  WIN_REPO: "https://github.com/RokiTheWise/DClutter-Windows",
};

function memoryStorage() {
  const values = new Map();
  return { values, getItem: (key) => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) };
}

function load(fetcher, storage) {
  const exports = {};
  const run = new Function("exports", "require", "fetch", "sessionStorage", compiled);
  run(exports, (id) => {
    assert.equal(id, "./platforms");
    return repoURLs;
  }, fetcher, storage);
  return exports;
}

(async () => {
  const calls = [];
  const asset = (name, download_count) => ({ name, download_count });
  const fetcher = async (url, options) => {
    calls.push(url);
    assert.equal(options.credentials, "omit");
    assert.equal(options.referrerPolicy, "no-referrer");
    const endpoint = new URL(url);
    const windows = endpoint.pathname.includes("DClutter-Windows");
    let data;
    if (!endpoint.pathname.endsWith("/releases")) {
      data = { stargazers_count: windows ? 0 : 6, forks_count: windows ? 0 : 1 };
    } else if (windows) {
      data = [{ assets: [asset("setup.exe", 10), asset("setup.msi", 1)] }];
    } else if (endpoint.searchParams.get("page") === "1") {
      data = Array.from({ length: 100 }, (_, index) => ({
        assets: index ? [] : [asset("DClutter.dmg", 5), asset("DClutter.dmg.sha256", 999), asset("latest.yml", 999)],
      }));
    } else {
      data = [21, 14, 8].map((count) => ({ assets: [asset("DClutter.zip", count)] }));
      data.push({ draft: true, assets: [asset("unpublished.zip", 999)] });
    }
    return { ok: true, json: async () => data };
  };
  const storage = memoryStorage();
  const api = load(fetcher, storage);
  const result = await api.getGitHubStats();
  assert.deepEqual(result.snapshot.repositories, [
    { id: "macos", downloads: 48, stars: 6, forks: 1, releases: 103 },
    { id: "windows", downloads: 11, stars: 0, forks: 0, releases: 1 },
  ]);
  assert.equal(result.stale, false);
  assert.equal(calls.length, 5, "all release pages are counted");
  assert.equal(result.snapshot.repositories.reduce((sum, repo) => sum + repo.downloads, 0), 59);
  console.log("PASS: all release pages, published releases only, app assets, stars, and forks");

  await api.getGitHubStats();
  assert.equal(calls.length, 5, "fresh session cache avoids repeat GitHub requests");
  console.log("PASS: 15-minute public session cache");

  for (const [key, raw] of storage.values) {
    storage.setItem(key, JSON.stringify({ ...JSON.parse(raw), fetchedAt: Date.now() - 16 * 60 * 1000 }));
  }
  const unavailable = async () => ({ ok: false, status: 403 });
  const fallback = await load(unavailable, storage).getGitHubStats();
  assert.equal(fallback.stale, true);
  assert.deepEqual(fallback.snapshot.repositories, result.snapshot.repositories);
  console.log("PASS: rate limits retain dated previous counts");

  await assert.rejects(load(unavailable, memoryStorage()).getGitHubStats(), /403/);
  console.log("PASS: unavailable data never becomes a fabricated zero");
})().catch((error) => { console.error(error); process.exitCode = 1; });
