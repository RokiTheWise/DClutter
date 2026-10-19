"use client";

import { useEffect, useReducer, useRef, type JSX } from "react";
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
  /** Indices, not a count: the commit sheet has to list them. */
  staged: number[];
  filed: number;
  trashed: number;
};

type State = {
  now: Snapshot;
  past: Snapshot[];
  future: Snapshot[];
  /** The destination shelf, which File opens rather than deciding. */
  shelf: boolean;
  /** Which bin the arrows have steered to while the shelf is open. */
  bin: number;
  /** The commit sheet behind Review trash. */
  sheet: boolean;
  /**
   * Unticked files. Held out here rather than in the sheet so it survives
   * closing and reopening, as SessionViewModel.excludedFromCommit does.
   */
  excluded: number[];
  vector: { x: number; y: number };
  said: string;
};

const first: Snapshot = {
  queue: samples.map((_, i) => i),
  kept: 0,
  staged: [],
  filed: 0,
  trashed: 0,
};

const initial: State = {
  now: first,
  past: [],
  future: [],
  shelf: false,
  bin: 0,
  sheet: false,
  excluded: [],
  vector: exitVector.keep,
  said: "",
};

type Action =
  | { type: "decide"; id: Decision; bin?: string }
  | { type: "openShelf" }
  | { type: "closeShelf" }
  | { type: "stepBin"; by: number }
  | { type: "confirmShelf" }
  | { type: "openSheet" }
  | { type: "closeSheet" }
  | { type: "toggleCommit"; index: number }
  | { type: "tickAll"; ticked: boolean }
  | { type: "confirmCommit" }
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

    // stepBin in TriageView: clamped to the row, no wrapping
    case "stepBin":
      return state.shelf
        ? { ...state, bin: Math.min(Math.max(state.bin + action.by, 0), BINS.length - 1) }
        : state;

    case "confirmShelf":
      return state.shelf
        ? reduce(state, { type: "decide", id: "file", bin: BINS[state.bin] })
        : state;

    case "decide": {
      const [head, ...rest] = state.now.queue;
      if (head === undefined) return state;

      const meta = decisions.find((d) => d.id === action.id)!;
      const now: Snapshot = {
        queue: action.id === "skip" ? [...rest, head] : rest,
        kept: state.now.kept + (action.id === "keep" ? 1 : 0),
        staged:
          action.id === "stage" ? [...state.now.staged, head] : state.now.staged,
        filed: state.now.filed + (action.id === "file" ? 1 : 0),
        trashed: state.now.trashed,
      };

      return {
        now,
        past: [...state.past, state.now],
        future: [],
        shelf: false,
        bin: state.bin,
        sheet: false,
        excluded: state.excluded,
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

    case "openSheet":
      return state.now.staged.length ? { ...state, sheet: true, shelf: false } : state;

    case "closeSheet":
      return { ...state, sheet: false };

    case "toggleCommit":
      return {
        ...state,
        excluded: state.excluded.includes(action.index)
          ? state.excluded.filter((i) => i !== action.index)
          : [...state.excluded, action.index],
      };

    case "tickAll":
      return { ...state, excluded: action.ticked ? [] : [...state.now.staged] };

    case "confirmCommit": {
      const toTrash = state.now.staged.filter((i) => !state.excluded.includes(i));
      const toKeep = state.now.staged.length - toTrash.length;
      return {
        ...state,
        now: {
          ...state.now,
          // Unticking unstages to kept; it does not put the file back in
          // the queue. DClutterSession.unstage.
          kept: state.now.kept + toKeep,
          staged: [],
          trashed: state.now.trashed + toTrash.length,
        },
        // Trashing clears undo history, as the session does.
        past: [],
        future: [],
        sheet: false,
        excluded: [],
        said: toTrash.length
          ? `${toTrash.length} moved to the Trash.`
          : "Nothing trashed. Those files stay where they are.",
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
  const sorted =
    state.now.kept + state.now.staged.length + state.now.filed + state.now.trashed;
  // Start over keys off whether anything has happened, not off undo history:
  // committing a trash clears that history, which used to disable the button
  // at exactly the point it was most wanted.
  const pristine =
    state.now.queue.length === samples.length &&
    state.now.kept === 0 &&
    state.now.staged.length === 0 &&
    state.now.filed === 0 &&
    state.now.trashed === 0;
  const unticked = state.excluded.length;
  const toTrash = state.now.staged.length - unticked;

  const onKey = (event: React.KeyboardEvent) => {
    if (event.metaKey || event.ctrlKey || event.altKey) return;
    const key = event.key;
    const take = (action: Action) => {
      event.preventDefault();
      dispatch(action);
    };

    if (state.sheet) {
      if (key === "Escape") take({ type: "closeSheet" });
      return;
    }

    // 1 to 3 file into a destination whether or not the shelf is open
    const digit = Number(key);
    if (digit >= 1 && digit <= BINS.length) {
      take({ type: "decide", id: "file", bin: BINS[digit - 1] });
      return;
    }

    // While the shelf is open the arrows steer it rather than deciding,
    // Return files into the highlighted bin, and up, down or escape back out.
    if (state.shelf) {
      if (key === "ArrowLeft") take({ type: "stepBin", by: -1 });
      else if (key === "ArrowRight") take({ type: "stepBin", by: 1 });
      else if (key === "Enter") take({ type: "confirmShelf" });
      else if (key === "Escape" || key === "ArrowUp" || key === "ArrowDown")
        take({ type: "closeShelf" });
      return;
    }

    if (key.toLowerCase() === "z") {
      take({ type: "undo" });
      return;
    }

    const match = decisions.find((d) => d.key === key);
    if (!match) return;
    // Up opens the shelf, it does not file anything on its own
    take(match.id === "file" ? { type: "openShelf" } : { type: "decide", id: match.id });
  };

  // keep the keys working after the shelf is opened by a click
  useEffect(() => {
    if (state.shelf) stageRef.current?.focus({ preventScroll: true });
  }, [state.shelf]);

  return (
    <div className="demo-shell">
      <WindowChrome
        className="demo-win win--light"
        staged={state.now.staged.length}
        onReviewTrash={() => dispatch({ type: "openSheet" })}
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
                  {state.now.kept} kept, {state.now.staged.length} staged,{" "}
                  {state.now.filed} filed
                  {state.now.trashed ? `, ${state.now.trashed} trashed` : ""}.
                  Nothing was deleted outright, and the Trash still has whatever
                  you sent there.
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
                      data-hit={i === state.bin}
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
                  Arrows to choose · Return to file · Escape to go back
                </button>
              </motion.div>
            ) : null}
          </AnimatePresence>
        </div>

        <AnimatePresence>
          {state.sheet ? (
            <motion.div
              className="demo-sheet-layer"
              initial={reduced ? false : { opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.16 }}
            >
              <motion.div
                className="demo-sheet"
                role="dialog"
                aria-modal="true"
                aria-label="Review staged files"
                initial={reduced ? false : { y: 10, scale: 0.98 }}
                animate={{ y: 0, scale: 1 }}
                exit={reduced ? undefined : { y: 10, scale: 0.98 }}
                transition={{ duration: 0.18, ease: "easeOut" }}
              >
                <h3>
                  {toTrash === 1 ? "Trash 1 file?" : `Trash ${toTrash} files?`}
                </h3>
                {unticked > 0 ? (
                  <p className="demo-sheet-note">
                    {unticked} unticked, those stay where they are.
                  </p>
                ) : null}

                <ul className="demo-sheet-list">
                  {state.now.staged.map((i) => {
                    const on = !state.excluded.includes(i);
                    return (
                      <li key={i}>
                        <label>
                          <input
                            type="checkbox"
                            checked={on}
                            onChange={() => dispatch({ type: "toggleCommit", index: i })}
                          />
                          <span className="demo-sheet-name">{samples[i].name}</span>
                          <span className="demo-sheet-size">{samples[i].size}</span>
                        </label>
                      </li>
                    );
                  })}
                </ul>

                <div className="demo-sheet-foot">
                  <button
                    type="button"
                    className="demo-sheet-link"
                    onClick={() =>
                      dispatch({ type: "tickAll", ticked: state.excluded.length > 0 })
                    }
                  >
                    {state.excluded.length > 0 ? "Tick All" : "Untick All"}
                  </button>
                  <button
                    type="button"
                    className="demo-sheet-btn"
                    onClick={() => dispatch({ type: "closeSheet" })}
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    className="demo-sheet-btn demo-sheet-btn--go"
                    onClick={() => dispatch({ type: "confirmCommit" })}
                  >
                    {toTrash === 1 ? "Trash 1 File" : `Trash ${toTrash} Files`}
                  </button>
                </div>
              </motion.div>
            </motion.div>
          ) : null}
        </AnimatePresence>

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
          <span className="dot" aria-hidden="true">
            ·
          </span>
          <span>
            <b>{sorted}</b> sorted
          </span>
          <button
            type="button"
            className="demo-reset"
            onClick={() => dispatch({ type: "reset" })}
            disabled={pristine}
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
