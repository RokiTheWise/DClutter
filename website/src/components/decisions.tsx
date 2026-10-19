"use client";

import { useEffect, useRef, useState, type CSSProperties } from "react";
import { useReducedMotion } from "motion/react";
import { decisions } from "@/lib/samples";
import { DecisionPreview } from "./decision-preview";

const descriptions = [
  "Set it aside. Review it before it goes to Trash.",
  "Not sure? Come back to it later.",
  "Pick a folder. Give it a home.",
  "Keep it exactly where it belongs.",
];

export default function Decisions() {
  const [active, setActive] = useState(0);
  const scenes = useRef<(HTMLDivElement | null)[]>([]);
  const reduced = useReducedMotion();

  useEffect(() => {
    const nodes = scenes.current.filter((node): node is HTMLDivElement => Boolean(node));
    const observer = new IntersectionObserver(() => {
      const middle = window.innerHeight / 2;
      const closest = nodes.reduce((best, node, index) => {
        const rect = node.getBoundingClientRect();
        const distance = Math.abs(rect.top + rect.height / 2 - middle);
        return distance < best.distance ? { index, distance } : best;
      }, { index: 0, distance: Infinity });
      setActive(closest.index);
    }, { rootMargin: "-25% 0px -25% 0px", threshold: [0, 0.25, 0.5, 0.75, 1] });
    nodes.forEach((node) => observer.observe(node));
    return () => observer.disconnect();
  }, []);

  return (
    <section className="band dec-band" id="decisions" aria-labelledby="dec-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap">
        <h2 className="display dec-heading" id="dec-heading">One file. Four ways forward.</h2>
        <div className="dec-grid">
          <div className="dec-list" role="group" aria-label="File actions">
            {decisions.map((decision, index) => (
              <button
                key={decision.id}
                type="button"
                className="dec-item"
                style={{ "--pair": index * 2 } as CSSProperties}
                data-active={index === active}
                aria-current={index === active ? "step" : undefined}
                aria-controls={`decision-scene-${decision.id}`}
                onClick={() => scenes.current[index]?.scrollIntoView({ block: "center", behavior: reduced ? "instant" : "smooth" })}
              >
                <span className="dec-head">
                  <span className="dec-num">0{index + 1}</span>
                  <span className="dec-name">{decision.label}</span>
                  <kbd className="dec-key">{decision.keyLabel}</kbd>
                </span>
                <span className="dec-body"><span>{descriptions[index]}</span></span>
              </button>
            ))}
          </div>
          <div className="dec-scenes">
            {decisions.map((decision, index) => (
              <div
                key={decision.id}
                ref={(node) => { scenes.current[index] = node; }}
                id={`decision-scene-${decision.id}`}
                className="dec-scene"
                style={{ "--pair": index * 2 } as CSSProperties}
                data-active={index === active}
              >
                <DecisionPreview decision={decision.id} description={descriptions[index]} />
              </div>
            ))}
          </div>
        </div>
      </div>
    </section>
  );
}
