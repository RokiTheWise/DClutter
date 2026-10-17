"use client";

import { useRef, useState } from "react";
import {
  AnimatePresence,
  motion,
  useMotionValueEvent,
  useReducedMotion,
  useScroll,
} from "motion/react";
import FileCard from "./file-card";
import { cardMotion, cardMotionReduced } from "@/lib/card-motion";
import { decisions, exitVector, samples } from "@/lib/samples";

export default function Decisions() {
  const ref = useRef<HTMLElement>(null);
  const reduced = useReducedMotion();
  const [active, setActive] = useState(0);

  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start 60%", "end 90%"],
  });

  useMotionValueEvent(scrollYProgress, "change", (p) => {
    const next = Math.min(decisions.length - 1, Math.max(0, Math.floor(p * decisions.length)));
    setActive((current) => (current === next ? current : next));
  });

  const current = decisions[active];
  // The exiting card reads the direction of the decision that was just made,
  // not the one it arrived under — so `custom` has to be the new active.
  const vector = exitVector[current.id];

  return (
    <section className="band dec-band" id="decisions" ref={ref} aria-labelledby="dec-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap">
        <span className="eyebrow">One question, four answers</span>
        <h2 className="display" id="dec-heading" style={{ marginTop: 18, maxWidth: "16ch" }}>
          Every file gets the same question.
        </h2>

        <div className="dec-grid">
          <div className="dec-list">
            {decisions.map((d, i) => (
              <button
                key={d.id}
                type="button"
                className="dec-item"
                data-active={i === active}
                aria-pressed={i === active}
                onClick={() => setActive(i)}
                onMouseEnter={() => setActive(i)}
                onFocus={() => setActive(i)}
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

          <div className="dec-stage">
            <div className="dec-card-holder">
              <AnimatePresence mode="popLayout" custom={vector} initial={false}>
                <motion.div
                  key={active}
                  custom={vector}
                  variants={reduced ? cardMotionReduced : cardMotion}
                  initial="enter"
                  animate="center"
                  exit="exit"
                >
                  <FileCard file={samples[active % samples.length]} />
                </motion.div>
              </AnimatePresence>
            </div>
            <p className="dec-hint" aria-live="polite">
              {current.result}
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
