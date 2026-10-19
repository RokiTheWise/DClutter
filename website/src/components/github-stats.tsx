"use client";

import { useEffect, useRef, useState } from "react";
import { animate, motion, useInView, useMotionValue, useReducedMotion, useTransform } from "motion/react";
import { getGitHubStats, repositories, type GitHubStatsResult, type RepositoryStats } from "@/lib/github-stats";
import { DesktopIcon, LaptopIcon } from "./icons";

const number = new Intl.NumberFormat("en-US");
const metrics = [
  { key: "downloads", label: "App downloads" },
  { key: "stars", label: "GitHub stars" },
  { key: "forks", label: "Forks" },
  { key: "releases", label: "Published releases" },
] as const;
const EASE = [0.16, 1, 0.3, 1] as const;

function Count({ value, delay }: { value: number | null; delay: number }) {
  const reduced = useReducedMotion();
  const count = useMotionValue(0);
  const text = useTransform(count, (value) => number.format(Math.round(value)));

  useEffect(() => {
    if (value === null) return;
    if (reduced) {
      count.set(value);
      return;
    }
    const playback = animate(count, value, { duration: 1.1, delay, ease: EASE });
    return () => playback.stop();
  }, [value, delay, reduced, count]);

  return (
    <>
      <span className="visually-hidden">{value === null ? "Unavailable" : number.format(value)}</span>
      {value === null ? <span aria-hidden="true">—</span> : <motion.span aria-hidden="true">{text}</motion.span>}
    </>
  );
}

export default function GitHubStats() {
  const ref = useRef<HTMLElement>(null);
  const visible = useInView(ref, { once: true, amount: 0.2 });
  const reduced = useReducedMotion();
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
    (sum, repo) => ({
      downloads: sum.downloads + repo.downloads,
      stars: sum.stars + repo.stars,
      forks: sum.forks + repo.forks,
      releases: sum.releases + repo.releases,
    }),
    { downloads: 0, stars: 0, forks: 0, releases: 0 },
  );
  const breakdown = (key: keyof Omit<RepositoryStats, "id">) => result?.snapshot.repositories.map((stat) =>
    `${repositories.find((repo) => repo.id === stat.id)?.name}: ${number.format(stat[key])}`,
  ).join(" · ");

  return (
    <section ref={ref} className="band github-band" id="community" aria-labelledby="github-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap">
        <div className="github-layout">
          <div className="github-copy">
            <h2 className="display" id="github-heading">Built in the open.</h2>
            <div className="github-actions">
              {repositories.map((repo) => {
                const Icon = repo.id === "macos" ? LaptopIcon : DesktopIcon;
                return (
                  <a className="github-repo-button" href={repo.url} key={repo.id} target="_blank" rel="noopener noreferrer">
                    <Icon /> GitHub for {repo.name}
                  </a>
                );
              })}
            </div>
          </div>

          <motion.div
            className="github-stat-stage"
            initial={reduced ? false : { opacity: 0, y: 18 }}
            animate={visible ? { opacity: 1, y: 0 } : undefined}
            transition={{ duration: reduced ? 0 : 0.7, ease: EASE }}
          >
            <dl className="github-totals" aria-busy={!result && !failed}>
              {metrics.map((metric, index) => (
                <div className="github-total" key={metric.key} title={breakdown(metric.key)}>
                  <dt>{metric.label}</dt>
                  <dd><Count value={totals?.[metric.key] ?? null} delay={index * 0.06} /></dd>
                </div>
              ))}
            </dl>
          </motion.div>
        </div>

        <div className="github-foot">
          <p>Totals across both repos. Downloads include installers and app archives.</p>
          <p role="status">
            {failed ? "Counts unavailable. View the repos for the latest." :
              result?.stale ? "Showing saved counts. GitHub is temporarily unavailable." : null}
          </p>
        </div>
      </div>
    </section>
  );
}
