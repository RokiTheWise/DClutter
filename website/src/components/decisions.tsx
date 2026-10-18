"use client";

import { useEffect, useRef, useState, type CSSProperties } from "react";
import { reels } from "./decision-reels";
import { decisions } from "@/lib/samples";

export default function Decisions() {
  const reelRefs = useRef<(HTMLDivElement | null)[]>([]);
  const [active, setActive] = useState(0);

  // Whichever reel is crossing the middle of the viewport owns the list.
  useEffect(() => {
    const nodes = reelRefs.current.filter(Boolean) as HTMLDivElement[];
    if (nodes.length === 0) return;

    const observer = new IntersectionObserver(
      (entries) => {
        const hit = entries
          .filter((e) => e.isIntersecting)
          .sort((a, b) => b.intersectionRatio - a.intersectionRatio)[0];
        if (!hit) return;
        const index = nodes.indexOf(hit.target as HTMLDivElement);
        if (index !== -1) setActive(index);
      },
      { rootMargin: "-42% 0px -42% 0px", threshold: [0, 0.5, 1] },
    );

    nodes.forEach((node) => observer.observe(node));
    return () => observer.disconnect();
  }, []);

  const jumpTo = (index: number) => {
    reelRefs.current[index]?.scrollIntoView({ block: "center", behavior: "smooth" });
  };

  return (
    <section className="band dec-band" id="decisions" aria-labelledby="dec-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap">
        <h2 className="display" id="dec-heading" style={{ maxWidth: "16ch" }}>
          Every file gets the same question.
        </h2>

        <div className="dec-grid">
          <div className="dec-list">
            {decisions.map((d, i) => (
              <button
                key={d.id}
                type="button"
                className="dec-item"
                style={{ "--pair": i * 2 } as CSSProperties}
                data-active={i === active}
                aria-current={i === active}
                onClick={() => jumpTo(i)}
              >
                <span className="dec-head">
                  <span className="dec-num">0{i + 1}</span>
                  <span className="dec-name">{d.label}</span>
                  <span className="dec-key">{d.keyLabel}</span>
                </span>
                <span className="dec-body">
                  <p>{d.blurb}</p>
                </span>
              </button>
            ))}
          </div>

          <div className="dec-reels">
            {reels.map((Reel, i) => (
              <div
                key={decisions[i].id}
                className="dec-reel"
                style={{ "--pair": i * 2 } as CSSProperties}
                data-active={i === active}
                ref={(node) => {
                  reelRefs.current[i] = node;
                }}
              >
                <Reel />
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
