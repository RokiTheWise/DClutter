"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import WindowChrome from "./window-chrome";
import FileCard from "./file-card";
import { EASE, cardMotion, cardMotionReduced } from "@/lib/card-motion";
import { decisions, exitVector, samples, type Decision } from "@/lib/samples";

type Snapshot = {
  queue: number[];
  kept: number;
  staged: number;
  filed: number;
  announcement: string;
};

const initial: Snapshot = {
  queue: samples.map((_, i) => i),
  kept: 0,
  staged: 0,
  filed: 0,
  announcement: "",
};

export default function TriageDemo() {
  const reduced = useReducedMotion();
  const stageRef = useRef<HTMLDivElement>(null);
  const [state, setState] = useState<Snapshot>(initial);
  const [history, setHistory] = useState<Snapshot[]>([]);
  const [vector, setVector] = useState(exitVector.keep);

  const currentIndex = state.queue[0];
  const currentFile = currentIndex === undefined ? null : samples[currentIndex];

  const decide = useCallback(
    (id: Decision) => {
      setState((prev) => {
        const [head, ...rest] = prev.queue;
        if (head === undefined) return prev;

        const meta = decisions.find((d) => d.id === id)!;
        const next: Snapshot = {
          queue: id === "skip" ? [...rest, head] : rest,
          kept: prev.kept + (id === "keep" ? 1 : 0),
          staged: prev.staged + (id === "stage" ? 1 : 0),
          filed: prev.filed + (id === "file" ? 1 : 0),
          announcement: `${samples[head].name}: ${meta.result}`,
        };
        setHistory((h) => [...h, prev]);
        return next;
      });
      setVector(exitVector[id]);
    },
    [],
  );

  const undo = useCallback(() => {
    setHistory((h) => {
      if (h.length === 0) return h;
      setState(h[h.length - 1]);
      return h.slice(0, -1);
    });
    setVector(exitVector.skip);
  }, []);

  const reset = useCallback(() => {
    setState(initial);
    setHistory([]);
  }, []);

  // Keyboard lives on the stage, not the window, so the page keeps its
  // normal arrow-key scrolling until you actually focus the demo.
  useEffect(() => {
    const node = stageRef.current;
    if (!node) return;

    const onKey = (event: KeyboardEvent) => {
      if (event.metaKey || event.ctrlKey || event.altKey) return;

      if (event.key.toLowerCase() === "z") {
        event.preventDefault();
        undo();
        return;
      }

      const match = decisions.find((d) => d.key === event.key);
      if (match && currentFile) {
        event.preventDefault();
        decide(match.id);
      }
    };

    node.addEventListener("keydown", onKey);
    return () => node.removeEventListener("keydown", onKey);
  }, [decide, undo, currentFile]);

  const sorted = state.kept + state.staged + state.filed;

  return (
    <div className="demo-shell">
      <WindowChrome className="demo-win" tools={false}>
        <div
          className="demo-stage"
          ref={stageRef}
          tabIndex={0}
          role="group"
          aria-label="Interactive DClutter demo. Use arrow keys and space to sort four sample files."
        >
          <AnimatePresence mode="popLayout" custom={vector} initial={false}>
            {currentFile ? (
              <motion.div
                className="demo-card-holder"
                key={`${currentIndex}-${state.queue.length}-${history.length}`}
                custom={vector}
                variants={reduced ? cardMotionReduced : cardMotion}
                initial="enter"
                animate="center"
                exit="exit"
              >
                <FileCard file={currentFile} />
              </motion.div>
            ) : (
              <motion.div
                className="demo-done"
                key="done"
                initial={reduced ? false : { opacity: 0, y: 18 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{ duration: 0.5, ease: EASE }}
              >
                <p className="display">Folder&rsquo;s empty.</p>
                <p>
                  {state.kept} kept · {state.staged} staged · {state.filed} filed.
                  Nothing was deleted, and every move is still reversible.
                </p>
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        <div className="demo-actions">
          {decisions.map((d) => (
            <button
              key={d.id}
              type="button"
              className="demo-act"
              disabled={!currentFile}
              onClick={() => decide(d.id)}
            >
              {d.label}
              <kbd>{d.keyLabel}</kbd>
            </button>
          ))}
        </div>

        <div className="demo-status">
          <span>
            <b>{state.queue.length}</b> left
          </span>
          <span>
            <b>{sorted}</b> sorted
          </span>
          <span className="demo-tools">
            <button
              type="button"
              className="demo-reset"
              onClick={undo}
              disabled={history.length === 0}
            >
              Undo <kbd>Z</kbd>
            </button>
            <button
              type="button"
              className="demo-reset"
              onClick={reset}
              disabled={history.length === 0}
            >
              Start over
            </button>
          </span>
        </div>
      </WindowChrome>

      <p aria-live="polite" className="visually-hidden">
        {state.announcement}
      </p>
    </div>
  );
}
