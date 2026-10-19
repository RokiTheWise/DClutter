"use client";

import { useRef, useState, type KeyboardEvent, type PointerEvent } from "react";
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
  const triggers = useRef<(HTMLButtonElement | null)[]>([]);

  const onHover = (event: PointerEvent<HTMLDivElement>, index: number) => {
    if (event.pointerType !== "mouse" || active === index) return;
    if (window.matchMedia("(min-width: 901px) and (hover: hover) and (pointer: fine)").matches) {
      setActive(index);
    }
  };

  const onKey = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    let next = index;
    if (event.key === "ArrowRight" || event.key === "ArrowDown") next = (index + 1) % decisions.length;
    else if (event.key === "ArrowLeft" || event.key === "ArrowUp") next = (index + decisions.length - 1) % decisions.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = decisions.length - 1;
    else return;
    event.preventDefault();
    setActive(next);
    triggers.current[next]?.focus({ preventScroll: true });
  };

  return (
    <section className="band dec-band" id="decisions" aria-labelledby="dec-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap">
        <h2 className="display dec-heading" id="dec-heading">One file. Four ways forward.</h2>
        <div className="dec-accordion">
          {decisions.map((decision, index) => {
            const open = active === index;
            return (
              <div
                className="dec-pane"
                data-open={open}
                data-decision={decision.id}
                key={decision.id}
                // Expanding panels can move under a stationary pointer; only real movement selects one.
                onPointerMove={(event) => onHover(event, index)}
              >
                <h3 className="dec-pane-heading">
                  <button
                    ref={(node) => { triggers.current[index] = node; }}
                    id={`decision-trigger-${decision.id}`}
                    className="dec-pane-trigger"
                    type="button"
                    aria-label={decision.label}
                    aria-expanded={open}
                    aria-disabled={open}
                    aria-controls={`decision-panel-${decision.id}`}
                    onClick={() => setActive(index)}
                    onFocus={() => setActive(index)}
                    onKeyDown={(event) => onKey(event, index)}
                  >
                    <span className="dec-pane-num" aria-hidden="true">0{index + 1}</span>
                    <span className="dec-pane-label">{decision.label}</span>
                    <kbd className="dec-pane-key" aria-hidden="true">{decision.keyLabel}</kbd>
                  </button>
                </h3>
                <div
                  id={`decision-panel-${decision.id}`}
                  className="dec-pane-content"
                  role="region"
                  aria-labelledby={`decision-trigger-${decision.id}`}
                  aria-hidden={!open}
                  inert={!open}
                >
                  <div className="dec-pane-inner">
                    <p className="dec-pane-description">{descriptions[index]}</p>
                    <DecisionPreview decision={decision.id} description={descriptions[index]} enabled={open} />
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </section>
  );
}
