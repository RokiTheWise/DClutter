"use client";

import { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useInView, useReducedMotion, useScroll, useSpring, useTransform } from "motion/react";
import type { Decision, SampleFile } from "@/lib/samples";
import { EASE } from "@/lib/card-motion";
import FileCard from "./file-card";
import WindowChrome from "./window-chrome";
import { CheckIcon, FolderIcon, SkipIcon, TrashIcon } from "./icons";

const files: (SampleFile & { image: string })[] = [
  { name: "Research proposal.pdf", type: "PDF document", size: "324 KB", lastOpened: "Yesterday", added: "17 Oct 2026", from: "Google Docs", preview: "notes", chips: [], image: "research-proposal" },
  { name: "Invoice - October.pdf", type: "PDF document", size: "86 KB", lastOpened: "14 Oct 2026", added: "14 Oct 2026", from: "Email attachment", preview: "notes", chips: [], image: "invoice" },
];
const actions = [
  { id: "stage", label: "Stage", key: "←", Icon: TrashIcon },
  { id: "skip", label: "Skip", key: "space", Icon: SkipIcon },
  { id: "file", label: "File", key: "↑", Icon: FolderIcon },
  { id: "keep", label: "Keep", key: "→", Icon: CheckIcon },
];

type Frame = { duration: number; file: number; phase: "idle" | "act" | "shelf"; resolved: boolean };
const sorting: Frame[] = [
  { duration: 1000, file: 0, phase: "idle", resolved: false },
  { duration: 260, file: 0, phase: "act", resolved: true },
  { duration: 1500, file: 1, phase: "idle", resolved: true },
];
const filing: Frame[] = [
  { duration: 800, file: 0, phase: "idle", resolved: false },
  { duration: 1200, file: 0, phase: "shelf", resolved: false },
  { duration: 260, file: 0, phase: "act", resolved: true },
  { duration: 1400, file: 1, phase: "idle", resolved: true },
];
const directions = {
  stage: { x: -700, y: 0 },
  skip: { x: 0, y: 500 },
  file: { x: 0, y: -500 },
  keep: { x: 700, y: 0 },
};

/** Each visible scene demonstrates its own action; incoming files avoid an empty hold. */
export function DecisionPreview({ decision, description }: { decision: Decision; description: string }) {
  const ref = useRef<HTMLElement>(null);
  const inView = useInView(ref, { amount: 0.35 });
  const reduced = useReducedMotion();
  const [index, setIndex] = useState(0);
  const [visible, setVisible] = useState(true);
  const frames = decision === "file" ? filing : sorting;
  const frame = reduced ? frames[decision === "file" ? 1 : 0] : frames[index];
  const file = files[frame.file];
  const { scrollYProgress } = useScroll({ target: ref, offset: ["start end", "end start"] });
  const driftTarget = useTransform(scrollYProgress, [0, 1], [20, -20]);
  const drift = useSpring(driftTarget, { stiffness: 120, damping: 28, mass: 0.35 });
  const acting = frame.phase === "act";
  const shelving = frame.phase === "shelf";
  const sorted = frame.resolved && decision !== "skip" ? 1 : 0;

  useEffect(() => {
    const update = () => setVisible(!document.hidden);
    update();
    document.addEventListener("visibilitychange", update);
    return () => document.removeEventListener("visibilitychange", update);
  }, []);

  useEffect(() => {
    if (!inView || !visible || reduced) return;
    const timer = window.setTimeout(() => setIndex((current) => (current + 1) % frames.length), frame.duration);
    return () => window.clearTimeout(timer);
  }, [index, inView, visible, reduced, frames, frame.duration]);

  return (
    <motion.figure ref={ref} className="dec-example" data-decision={decision} data-phase={frame.phase} aria-label={`${decision}: ${description}`} style={{ y: reduced ? 0 : drift }}>
      <div aria-hidden="true" inert>
        <WindowChrome className="dec-preview-win win--light" staged={decision === "stage" && frame.resolved ? 1 : 0}>
          <div className="dec-file-stage">
            <AnimatePresence initial={false} mode="popLayout">
              <motion.div
                key={frame.file}
                className="dec-moving-card"
                initial={reduced ? false : { opacity: 0, y: 14 }}
                animate={acting ? { opacity: 0, ...directions[decision] } : { opacity: 1, x: 0, y: 0 }}
                exit={{ opacity: 0, transition: { duration: 0.16 } }}
                transition={{ duration: reduced ? 0 : 0.24, ease: EASE }}
              >
                <motion.div animate={{ opacity: shelving ? 0.3 : 1, scale: shelving && !reduced ? 0.88 : 1 }} transition={{ duration: reduced ? 0 : 0.18 }}>
                  <FileCard file={file} preview={<img className="hero-demo-document" src={`/demo/${file.image}.svg`} alt="" />} />
                </motion.div>
              </motion.div>
            </AnimatePresence>
            <AnimatePresence>
              {shelving && (
                <motion.div className="dec-folder-shelf" initial={reduced ? false : { opacity: 0, y: -18 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -30 }} transition={{ duration: reduced ? 0 : 0.2, ease: EASE }}>
                  <b>File into a folder</b>
                  <p>← → to choose · Return to file · Esc to cancel</p>
                  <div className="dec-folders">
                    {["Projects", "Receipts", "Archive"].map((name, folder) => (
                      <div key={name} data-selected={folder === 0}><FolderIcon /><span>{name}</span><kbd>{folder + 1}</kbd></div>
                    ))}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
          <div className="dec-sample-actions">
            {actions.map((action) => <div key={action.id} data-selected={(acting || shelving || Boolean(reduced)) && decision === action.id} data-hot={action.id === "stage"}><action.Icon /><span>{action.label}</span><kbd>{action.key}</kbd></div>)}
          </div>
          <div className="dec-window-status"><span>{4 - sorted} left</span><span>·</span><span>{sorted} sorted</span></div>
        </WindowChrome>
      </div>
    </motion.figure>
  );
}
