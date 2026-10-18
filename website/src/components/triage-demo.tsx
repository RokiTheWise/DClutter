"use client";

import { useCallback, useEffect, useReducer, useRef, type JSX } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import WindowChrome from "./window-chrome";
import FileCard from "./file-card";
import { CheckIcon, FolderIcon, SkipIcon, TrashIcon } from "./icons";
import { EASE, cardMotion, cardMotionReduced } from "@/lib/card-motion";
import { decisions, exitVector, samples, type Decision } from "@/lib/samples";

const BINS = ["Projects", "Receipts", "Archive"];

const ICONS: Record<Decision, () => JSX.Element> = {
  stage: TrashIcon,
  skip: SkipIcon,
  file: FolderIcon,
  keep: CheckIcon,
};

type Snapshot = {
  queue: number[];
  kept: number;
  staged: number;
  filed: number;
};

type State = {
  now: Snapshot;
  past: Snapshot[];
  future: Snapshot[];
  /** The destination shelf, which File opens rather than deciding. */
  shelf: boolean;
  vector: { x: number; y: number };
  said: string;
};

const first: Snapshot = {
  queue: samples.map((_, i) => i),
  kept: 0,
  staged: 0,
  filed: 0,
};

const initial: State = {
  now: first,
  past: [],
  future: [],
  shelf: false,
  vector: exitVector.keep,
  said: "",
};

type Action =
  | { type: "decide"; id: Decision; bin?: string }
  | { type: "openShelf" }
  | { type: "closeShelf" }
  | { type: "undo" }
  | { type: "redo" }
  | { type: "reset" };

/**
 * One reducer rather than several useStates. The previous version pushed to
 * a history state from inside a setState updater, and React invokes those
 * updaters twice in development to surface exactly that kind of impurity, so
 * every decision was recorded twice and undo needed two presses.
 */
function reduce(state: State, action: Action): State {
  switch (action.type) {
    case "openShelf":
      return state.now.queue.length ? { ...state, shelf: true } : state;

    case "closeShelf":
      return { ...state, shelf: false };

    case "decide": {
      const [head, ...rest] = state.now.queue;
      if (head === undefined) return state;

      const meta = decisions.find((d) => d.id === action.id)!;
      const now: Snapshot = {
        queue: action.id === "skip" ? [...rest, head] : rest,
        kept: state.now.kept + (action.id === "keep" ? 1 : 0),
        staged: state.now.staged + (action.id === "stage" ? 1 : 0),
        filed: state.now.filed + (action.id === "file" ? 1 : 0),
      };

      return {
        now,
        past: [...state.past, state.now],
        future: [],
        shelf: false,
        vector: exitVector[action.id],
        said: `${samples[head].name}: ${
          action.bin ? `Filed into ${action.bin}.` : meta.result
        }`,
      };
    }

    case "undo": {
      const previous = state.past.at(-1);
      if (!previous) return state;
      return {
        ...state,
        now: previous,
        past: state.past.slice(0, -1),
        future: [state.now, ...state.future],
        shelf: false,
        vector: exitVector.skip,
        said: "Undone.",
      };
    }

    case "redo": {
      const [next, ...rest] = state.future;
      if (!next) return state;
      return {
        ...state,
        now: next,
        past: [...state.past, state.now],
        future: rest,
        shelf: false,
        vector: exitVector.keep,
        said: "Redone.",
      };
    }

    case "reset":
      return initial;
  }
}

export default function TriageDemo() {
  const reduced = useReducedMotion();
  const stageRef = useRef<HTMLDivElement>(null);
  const [state, dispatch] = useReducer(reduce, initial);

  const index = state.now.queue[0];
  const file = index === undefined ? null : samples[index];
  const sorted = state.now.kept + state.now.staged + state.now.filed;

  const onKey = useCallback((event: React.KeyboardEvent) => {
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    const key = event.key;

    if (key === "Escape") {
      event.preventDefault();
      dispatch({ type: "closeShelf" });
      return;
    }
    if (key.toLowerCase() === "z") {
      event.preventDefault();
      dispatch({ type: "undo" });
      return;
    }

    const bin = Number(key);
    if (bin >= 1 && bin <= BINS.length) {
      event.preventDefault();
      dispatch({ type: "decide", id: "file", bin: BINS[bin - 1] });
      return;
    }

    const match = decisions.find((d) => d.key === key);
    if (!match) return;
    event.preventDefault();
    // Up opens the shelf, it does not file anything on its own
    dispatch(
      match.id === "file" ? { type: "openShelf" } : { type: "decide", id: match.id },
    );
  }, []);

  // keep the keys working after the shelf is opened by a click
  useEffect(() => {
    if (state.shelf) stageRef.current?.focus({ preventScroll: true });
  }, [state.shelf]);

  return (
    <div className="demo-shell">
      <WindowChrome
        className="demo-win"
        staged={state.now.staged}
        canUndo={state.past.length > 0}
        canRedo={state.future.length > 0}
        onUndo={() => dispatch({ type: "undo" })}
        onRedo={() => dispatch({ type: "redo" })}
      >
        <div
          className="demo-stage"
          ref={stageRef}
          tabIndex={0}
          onKeyDown={onKey}
          role="group"
          aria-label="Interactive DClutter demo. Arrow keys and space to sort, up for folders, Z to undo."
        >
          <AnimatePresence mode="popLayout" custom={state.vector} initial={false}>
            {file ? (
              <motion.div
                className="demo-card-holder"
                key={`${index}-${state.past.length}-${state.now.queue.length}`}
                custom={state.vector}
                variants={reduced ? cardMotionReduced : cardMotion}
                initial="enter"
                animate="center"
                exit="exit"
              >
                {/* the card recedes behind the shelf, as it does in the app */}
                <motion.div
                  animate={
                    reduced
                      ? undefined
                      : { scale: state.shelf ? 0.85 : 1, opacity: state.shelf ? 0.35 : 1 }
                  }
                  transition={{ duration: 0.2, ease: "easeOut" }}
                >
                  <FileCard file={file} />
                </motion.div>
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
                  {state.now.kept} kept, {state.now.staged} staged,{" "}
                  {state.now.filed} filed. Nothing was deleted, and every move is
                  still reversible.
                </p>
              </motion.div>
            )}
          </AnimatePresence>

          <AnimatePresence>
            {state.shelf ? (
              <motion.div
                className="demo-shelf"
                initial={reduced ? false : { y: -40, opacity: 0 }}
                animate={{ y: 0, opacity: 1 }}
                exit={reduced ? { opacity: 0 } : { y: -40, opacity: 0 }}
                transition={{ duration: 0.2, ease: "easeOut" }}
              >
                <p className="demo-shelf-title">File into a folder</p>
                <div className="demo-bins">
                  {BINS.map((name, i) => (
                    <button
                      key={name}
                      type="button"
                      className="demo-bin"
                      data-hit={i === 0}
                      onClick={() => dispatch({ type: "decide", id: "file", bin: name })}
                    >
                      <FolderIcon />
                      {name}
                      <kbd>{i + 1}</kbd>
                    </button>
                  ))}
                </div>
                <button
                  type="button"
                  className="demo-shelf-cancel"
                  onClick={() => dispatch({ type: "closeShelf" })}
                >
                  Escape to go back
                </button>
              </motion.div>
            ) : null}
          </AnimatePresence>
        </div>

        <div className="demo-actions" data-dim={state.shelf}>
          {decisions.map((d) => {
            const Icon = ICONS[d.id];
            return (
              <button
                key={d.id}
                type="button"
                className="demo-act"
                data-hot={d.id === "stage"}
                disabled={!file || state.shelf}
                onClick={() =>
                  dispatch(
                    d.id === "file"
                      ? { type: "openShelf" }
                      : { type: "decide", id: d.id },
                  )
                }
              >
                <Icon />
                <span>{d.label}</span>
                <kbd>{d.keyLabel}</kbd>
              </button>
            );
          })}
        </div>

        <div className="demo-status">
          <span>
            <b>{state.now.queue.length}</b> left
          </span>
          <span>
            <b>{sorted}</b> sorted
          </span>
          <button
            type="button"
            className="demo-reset"
            onClick={() => dispatch({ type: "reset" })}
            disabled={state.past.length === 0 && state.future.length === 0}
          >
            Start over
          </button>
        </div>
      </WindowChrome>

      <p aria-live="polite" className="visually-hidden">
        {state.said}
      </p>
    </div>
  );
}
