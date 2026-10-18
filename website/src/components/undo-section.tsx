"use client";

import { useEffect, useRef, useState } from "react";
import {
  animate,
  motion,
  useMotionValue,
  useMotionValueEvent,
  useReducedMotion,
} from "motion/react";

const log = [
  { name: "Semester planning notes.txt", verb: "Kept" },
  { name: "A little more clarity.pdf", verb: "Filed" },
  { name: "Brand assets (2).zip", verb: "Staged" },
  { name: "Reading list.csv", verb: "Kept" },
  { name: "setup-arm64.dmg", verb: "Staged" },
];

const STOPS = log.length;
const KNOB = 26;

export default function UndoSection() {
  const reduced = useReducedMotion();
  const trackRef = useRef<HTMLDivElement>(null);
  const x = useMotionValue(0);
  const [span, setSpan] = useState(0);
  // how many of the moves above are still applied
  const [applied, setApplied] = useState(STOPS);
  const dragging = useRef(false);
  // read inside the resize handler, which must not re-subscribe on every
  // change: an effect that depended on `applied` re-ran mid-drag and reset
  // x to the current stop, fighting the pointer all the way to an end.
  const stop = useRef(STOPS);
  stop.current = applied;

  // the handle travels the track minus its own width
  useEffect(() => {
    const node = trackRef.current;
    if (!node) return;
    const measure = () => {
      const width = Math.max(node.clientWidth - KNOB, 1);
      setSpan(width);
      // keep the handle on its stop when the track resizes
      if (!dragging.current) x.set((stop.current / STOPS) * width);
    };
    measure();
    const observer = new ResizeObserver(measure);
    observer.observe(node);
    return () => observer.disconnect();
  }, [x]);

  // rows follow the nearest stop while the drag is still in flight
  useMotionValueEvent(x, "change", (value) => {
    if (!span) return;
    const next = Math.round((value / span) * STOPS);
    setApplied((current) =>
      current === next ? current : Math.min(Math.max(next, 0), STOPS),
    );
  });

  /** Magnet to the nearest stop, with enough spring left to read as a pull. */
  const settle = (stop: number) => {
    const target = (stop / STOPS) * span;
    if (reduced) {
      x.set(target);
      return;
    }
    animate(x, target, { type: "spring", stiffness: 420, damping: 22, mass: 0.6 });
  };

  const step = (by: number) => {
    const next = Math.min(Math.max(applied + by, 0), STOPS);
    setApplied(next);
    settle(next);
  };

  return (
    <section className="band undo-band" aria-labelledby="undo-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap undo-grid">
        <div>
          <h2 className="display" id="undo-heading">
            Room to change your mind.
          </h2>
          <p className="lede" style={{ marginTop: 22 }}>
            Staged files stay on disk. They sit in a holding area until you
            review the whole batch, and every move gets registered for undo before
            it runs. Drag the handle and watch the session come apart.
          </p>
          <p className="lede" style={{ marginTop: 18 }}>
            When you do empty the staging area, files go to the Trash, where you
            can still fish them out. A file that was never deleted is a lot easier
            to bring back than one you have to dig for.
          </p>
        </div>

        <div className="undo-panel">
          <div className="undo-log">
            {log.map((entry, i) => (
              <div className="undo-row" key={entry.name} data-undone={i >= applied}>
                <b>{entry.name}</b>
                <span className="undo-verb">{i >= applied ? "Undone" : entry.verb}</span>
              </div>
            ))}
          </div>

          <div className="undo-scrub-label">
            <span>Start of session</span>
            <span>
              {applied} of {STOPS} applied
            </span>
          </div>

          <div className="undo-track" ref={trackRef}>
            <div className="undo-stops" aria-hidden="true">
              {Array.from({ length: STOPS + 1 }, (_, i) => (
                <i key={i} data-past={i <= applied} />
              ))}
            </div>
            <motion.div
              className="undo-knob"
              style={{ x }}
              drag="x"
              dragConstraints={{ left: 0, right: span }}
              dragElastic={0.03}
              dragMomentum={false}
              onDragStart={() => {
                dragging.current = true;
              }}
              onDragEnd={() => {
                dragging.current = false;
                settle(Math.round((x.get() / span) * STOPS));
              }}
              whileDrag={{ scale: 1.12 }}
              role="slider"
              tabIndex={0}
              aria-label="Rewind the session"
              aria-valuemin={0}
              aria-valuemax={STOPS}
              aria-valuenow={applied}
              aria-valuetext={`${applied} of ${STOPS} moves applied`}
              onKeyDown={(event) => {
                const by =
                  event.key === "ArrowLeft" || event.key === "ArrowDown"
                    ? -1
                    : event.key === "ArrowRight" || event.key === "ArrowUp"
                      ? 1
                      : 0;
                if (by) {
                  event.preventDefault();
                  step(by);
                } else if (event.key === "Home") {
                  event.preventDefault();
                  setApplied(0);
                  settle(0);
                } else if (event.key === "End") {
                  event.preventDefault();
                  setApplied(STOPS);
                  settle(STOPS);
                }
              }}
            />
          </div>
        </div>
      </div>
    </section>
  );
}
