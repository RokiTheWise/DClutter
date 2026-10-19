"use client";

import { useEffect, useId, useRef, useState } from "react";
import { AnimatePresence, motion, useInView, useReducedMotion } from "motion/react";
import { decisions, type Decision, type SampleFile } from "@/lib/samples";
import { EASE } from "@/lib/card-motion";
import FileCard from "./file-card";
import WindowChrome from "./window-chrome";
import { CheckIcon, FolderIcon, SkipIcon, TrashIcon } from "./icons";

type Shot = {
  duration: number;
  step: number;
  card: "lecture" | "invoice" | "proposal" | "summary" | "done";
  staged: number;
  resolved: number;
  action?: Decision;
  overlay?: "rename" | "shelf" | "review";
  edited?: boolean;
  renamed?: boolean;
  confirm?: boolean;
};

// A single, repeatable sequence. Every shot describes its complete UI state,
// so wrapping to shot zero also resets names, counts, panels, and the queue.
const SHOTS: Shot[] = [
  { duration: 1100, step: 0, card: "lecture", staged: 0, resolved: 0 },
  { duration: 320, step: 0, card: "lecture", staged: 1, resolved: 1, action: "stage" },
  { duration: 1100, step: 1, card: "invoice", staged: 1, resolved: 1 },
  { duration: 320, step: 1, card: "invoice", staged: 1, resolved: 2, action: "keep" },
  { duration: 450, step: 2, card: "proposal", staged: 1, resolved: 2 },
  { duration: 550, step: 2, card: "proposal", staged: 1, resolved: 2, overlay: "rename" },
  { duration: 800, step: 2, card: "proposal", staged: 1, resolved: 2, overlay: "rename", edited: true },
  { duration: 180, step: 2, card: "proposal", staged: 1, resolved: 2, overlay: "rename", edited: true, confirm: true },
  { duration: 200, step: 3, card: "proposal", staged: 1, resolved: 2, renamed: true },
  { duration: 900, step: 3, card: "proposal", staged: 1, resolved: 2, renamed: true, overlay: "shelf" },
  // Enter closes the shelf and sends the card upward in the same shot.
  { duration: 320, step: 3, card: "proposal", staged: 1, resolved: 3, renamed: true, action: "file" },
  { duration: 450, step: 4, card: "summary", staged: 1, resolved: 3 },
  { duration: 1700, step: 4, card: "summary", staged: 1, resolved: 3, overlay: "review" },
  { duration: 220, step: 5, card: "summary", staged: 1, resolved: 3, overlay: "review", confirm: true },
  { duration: 900, step: 5, card: "done", staged: 0, resolved: 3 },
];

const ICONS = { stage: TrashIcon, skip: SkipIcon, file: FolderIcon, keep: CheckIcon };

const LECTURE: SampleFile = { name: "Lecture 06 - Databases (1).pdf", type: "PDF document", size: "2.4 MB", lastOpened: "Never", added: "3 Sep 2026", from: "Course materials", preview: "notes", chips: ["2 copies", "never opened"] };
const INVOICE: SampleFile = { name: "Invoice - October.pdf", type: "PDF document", size: "86 KB", lastOpened: "14 Oct 2026", added: "14 Oct 2026", from: "Email attachment", preview: "notes", chips: [] };
const PROPOSAL: SampleFile = { name: "Untitled.pdf", type: "PDF document", size: "324 KB", lastOpened: "Yesterday", added: "17 Oct 2026", from: "Google Docs", preview: "notes", chips: [] };
const NEW_NAME = "Research proposal";

function TypedFilename({ reduced }: { reduced: boolean | null }) {
  const [length, setLength] = useState(0);

  useEffect(() => {
    if (reduced) return;
    let typed = 0;
    const timer = window.setInterval(() => {
      typed += 1;
      setLength(typed);
      if (typed === NEW_NAME.length) window.clearInterval(timer);
    }, 24);
    return () => window.clearInterval(timer);
  }, [reduced]);

  return <span className="hero-demo-typing">{reduced ? NEW_NAME : NEW_NAME.slice(0, length)}</span>;
}

export default function HeroDemo() {
  const ref = useRef<HTMLElement>(null);
  const inView = useInView(ref, { amount: 0.2 });
  const reduced = useReducedMotion();
  const descriptionId = useId();
  const [index, setIndex] = useState(0);
  const [visible, setVisible] = useState(true);
  const shot = SHOTS[index];
  const playing = !reduced && inView && visible;

  useEffect(() => {
    const update = () => setVisible(!document.hidden);
    update();
    document.addEventListener("visibilitychange", update);
    return () => document.removeEventListener("visibilitychange", update);
  }, []);

  useEffect(() => {
    if (!playing) return;
    const timer = window.setTimeout(() => setIndex((current) => (current + 1) % SHOTS.length), shot.duration);
    return () => window.clearTimeout(timer);
  }, [index, playing, shot.duration]);

  const file = shot.card === "lecture" ? LECTURE : shot.card === "invoice" ? INVOICE : {
    ...PROPOSAL,
    name: shot.renamed ? `${NEW_NAME}.pdf` : PROPOSAL.name,
  };
  const departure = shot.action === "stage" ? { x: -760, y: 0 }
    : shot.action === "keep" ? { x: 760, y: 0 }
    : { x: 0, y: -760 };
  const renaming = shot.overlay === "rename";
  const reviewing = shot.overlay === "review";
  const complete = shot.card === "summary" || shot.card === "done";
  const shelving = shot.overlay === "shelf" || shot.action === "file";
  const preview = shot.card === "lecture" ? "lecture-notes" : shot.card === "invoice" ? "invoice" : "research-proposal";

  return (
    <figure className="hero-loop" ref={ref} aria-label="DClutter sample walkthrough" aria-describedby={descriptionId} data-step={shot.step} data-shot={index} data-action={shot.action} data-can-undo={shot.resolved > 0 && shot.card !== "done"}>
      <p className="visually-hidden" id={descriptionId}>
        A looping sample stages duplicate lecture notes, keeps an invoice, renames a proposal, files it into Projects,
        reviews the staged file, and moves it to Trash. Then the sample starts again.
        No files on your computer are used.
      </p>

      {/* This is a demonstration, so its simulated controls never take focus. */}
      <div aria-hidden="true" inert>
        <WindowChrome className="hero-demo-win" staged={shot.staged}>
          <div className="hero-demo-stage">
            <AnimatePresence initial={false} mode="popLayout">
              <motion.div
                key={shot.card}
                className="hero-demo-card"
                initial={reduced ? false : { opacity: 0, y: 20 }}
                animate={shot.action
                  ? { opacity: 0, ...(reduced ? {} : departure) }
                  : { opacity: 1, x: 0, y: 0, rotate: 0, scale: 1 }}
                exit={{ opacity: 0, transition: { duration: reduced ? 0 : 0.08 } }}
                transition={{ duration: reduced ? 0 : 0.26, ease: EASE }}
              >
                {complete ? (
                  <div className="hero-demo-complete">
                    <span className="hero-demo-check"><CheckIcon /></span>
                    <h3>All caught up</h3>
                    <p>{shot.card === "done" ? "Every file in this queue has a decision." : "Review your staged files when you’re ready."}</p>
                  </div>
                ) : (
                  <motion.div animate={{ opacity: shelving ? 0.35 : 1, scale: !reduced && shelving ? 0.85 : 1 }} transition={{ duration: reduced ? 0 : 0.16 }}>
                    <FileCard file={file} preview={<img className="hero-demo-document" src={`/demo/${preview}.svg`} alt="" />} />
                  </motion.div>
                )}
              </motion.div>
            </AnimatePresence>

            <AnimatePresence>
              {shot.overlay === "shelf" && (
                <motion.div className="hero-demo-overlay hero-demo-overlay--shelf" key="shelf" initial={reduced ? false : { opacity: 0, y: -20 }} animate={{ opacity: 1, y: 0 }} exit={reduced ? { opacity: 0 } : { opacity: 0, y: -36 }} transition={{ duration: reduced ? 0 : 0.18, ease: EASE }}>
                    <div className="hero-demo-folders">
                      <h3>File into a folder</h3>
                      <p>← → to choose · Return to file · Esc to cancel</p>
                      <span className="hero-demo-shelf-close">×</span>
                      <div className="hero-demo-bins">
                        {["Projects", "Receipts", "Add folder…"].map((name, i) => <div className="hero-demo-bin" data-selected={i === 0} key={name}><FolderIcon />{i < 2 && <span className="hero-demo-remove">×</span>}<span>{name}</span><kbd>{i < 2 ? i + 1 : "⌘N"}</kbd></div>)}
                      </div>
                    </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>

          <div className="demo-actions hero-demo-actions" data-dim={renaming || shelving || complete}>
            {decisions.map((decision) => {
              const Icon = ICONS[decision.id];
              return <div className="demo-act" data-hot={decision.id === "stage"} data-active={shot.action === decision.id || (shot.overlay === "shelf" && decision.id === "file")} key={decision.id}><Icon /><span>{decision.label}</span><kbd>{decision.keyLabel}</kbd></div>;
            })}
          </div>
          {renaming ? (
            <div className="hero-demo-rename-bar">
              <span>RENAME</span>
              <div className="hero-demo-input">{shot.edited ? <TypedFilename reduced={reduced} /> : <span data-selected>Untitled</span>}</div>
              <span>↩ rename · esc cancel</span>
            </div>
          ) : (
            <div className="hero-demo-status"><span><b>{3 - shot.resolved}</b> left</span><span>·</span><span><b>{shot.card === "done" ? 0 : shot.resolved}</b> sorted</span></div>
          )}

          <AnimatePresence>
            {reviewing && (
              <motion.div className="hero-demo-review-overlay" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} transition={{ duration: reduced ? 0 : 0.2 }}>
                <div className="hero-demo-panel hero-demo-panel--review">
                  <h3>Trash 1 file?</h3>
                  <div className="hero-demo-review-list">
                    <div className="hero-demo-review-file"><span className="hero-demo-checkbox"><CheckIcon /></span><b>{LECTURE.name}</b><span>{LECTURE.size}</span></div>
                  </div>
                  <div className="hero-demo-panel-actions"><span className="hero-demo-untick">Untick All</span><span className="hero-demo-cancel">Cancel</span><span className="hero-demo-confirm hero-demo-confirm--trash" data-active={shot.confirm}>Trash 1 File</span></div>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </WindowChrome>
      </div>

    </figure>
  );
}
