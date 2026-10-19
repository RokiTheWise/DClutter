"use client";

import { useEffect, useRef, useState } from "react";
import { useInView } from "motion/react";
import { getGitHubStats, repositories, type GitHubStatsResult } from "@/lib/github-stats";

const number = new Intl.NumberFormat("en-US");

export default function GitHubStats() {
  const ref = useRef<HTMLElement>(null);
  const visible = useInView(ref, { once: true, amount: 0.2 });
  const [result, setResult] = useState<GitHubStatsResult | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    if (!visible) return;
    let active = true;
    getGitHubStats().then(
      (value) => { if (active) setResult(value); },
      () => { if (active) setFailed(true); },
    );
    return () => { active = false; };
  }, [visible]);

  const totals = result?.snapshot.repositories.reduce(
    (sum, repo) => ({ downloads: sum.downloads + repo.downloads, stars: sum.stars + repo.stars }),
    { downloads: 0, stars: 0 },
  );
  const updated = result ? new Date(result.snapshot.fetchedAt) : null;

  return (
    <section ref={ref} className="band github-band" id="community" aria-labelledby="github-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap">
        <div className="github-header">
          <h2 className="display" id="github-heading">Built in the open.</h2>
          <div className="github-totals" aria-busy={!result && !failed}>
            <div className="github-total">
              <b>{totals ? number.format(totals.downloads) : "—"}</b>
              <span>App downloads</span>
            </div>
            <div className="github-total">
              <b>{totals ? number.format(totals.stars) : "—"}</b>
              <span>GitHub stars</span>
            </div>
          </div>
        </div>

        <div className="github-repos">
          {repositories.map((repo) => {
            const stats = result?.snapshot.repositories.find((item) => item.id === repo.id);
            return (
              <a className="github-repo" href={repo.url} key={repo.id} target="_blank" rel="noopener noreferrer">
                <span className="github-platform">{repo.name}</span>
                <span className="github-repo-name">{new URL(repo.url).pathname.slice(1)}</span>
                <span className="github-repo-counts">
                  <span><b>{stats ? number.format(stats.downloads) : "—"}</b> downloads</span>
                  <span><b>{stats ? number.format(stats.stars) : "—"}</b> stars</span>
                </span>
                <span className="github-repo-link">View on GitHub</span>
              </a>
            );
          })}
        </div>

        <div className="github-foot">
          <p>Installer and app archive downloads across all releases.</p>
          <p role="status">
            {failed ? "Counts unavailable. View the repos for the latest." :
              !updated ? "Loading GitHub counts…" : (
                <>
                  {result?.stale ? "Last available counts · " : "Updated "}
                  <time dateTime={updated.toISOString()}>
                    {updated.toLocaleString("en-US", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" })}
                  </time>
                </>
              )}
          </p>
        </div>
      </div>
    </section>
  );
}
