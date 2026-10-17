"use client";

import type { CSSProperties, ReactNode } from "react";
import { motion, useReducedMotion, type Variants } from "motion/react";

const EASE = [0.22, 1, 0.36, 1] as const;
const CYCLE = 3.8;

/** Replays whenever the reel comes back into view, and loops while it is there. */
const viewport = { once: false, amount: 0.5 } as const;

/**
 * Every scene is one looping timeline that starts and ends in the same place,
 * so a reel is never caught sitting empty after its animation has run.
 */
const loop = (times: number[], delay = 0) => ({
  duration: CYCLE,
  times,
  ease: EASE,
  repeat: Infinity,
  repeatDelay: 0.5,
  delay,
});

function Reel({ children }: { children: ReactNode }) {
  return (
    <motion.div initial="rest" whileInView="play" viewport={viewport}>
      <div className="reel-scene">{children}</div>
    </motion.div>
  );
}

function Chip({
  name,
  meta,
  style,
  className = "",
  variants,
  reduced,
}: {
  name: string;
  meta: string;
  style?: CSSProperties;
  className?: string;
  variants: Variants;
  reduced: boolean | null;
}) {
  return (
    <motion.div
      className={`reel-chip ${className}`.trim()}
      style={style}
      variants={reduced ? undefined : variants}
    >
      <b>{name}</b>
      <span>{meta}</span>
    </motion.div>
  );
}

/* ---- 01 Stage — left, and the Review trash counter ticks up ----
   Staging opens nothing. The only feedback in the app is the toolbar
   button, which reads "Review trash <n>" and gates the commit sheet. */

export function StageReel() {
  const reduced = useReducedMotion();

  const chip: Variants = {
    rest: { x: 0, opacity: 1, scale: 1 },
    play: {
      x: [0, 0, -172, -172, 0],
      opacity: [1, 1, 0, 0, 1],
      scale: [1, 1, 0.86, 0.86, 1],
      transition: loop([0, 0.18, 0.42, 0.86, 1]),
    },
  };
  const before: Variants = {
    rest: { opacity: 1 },
    play: { opacity: [1, 1, 0, 0, 1], transition: loop([0, 0.36, 0.44, 0.9, 1]) },
  };
  const after: Variants = {
    rest: { opacity: 0 },
    play: { opacity: [0, 0, 1, 1, 0], transition: loop([0, 0.36, 0.44, 0.9, 1]) },
  };

  return (
    <Reel>
      <div className="reel-pill" style={{ left: 0, top: "50%", marginTop: -19 }}>
        Review trash
        <b style={{ position: "relative" }}>
          <motion.span variants={reduced ? undefined : before}>2</motion.span>
          <motion.span
            variants={reduced ? undefined : after}
            style={{ position: "absolute", inset: 0, display: "grid", placeItems: "center" }}
          >
            3
          </motion.span>
        </b>
      </div>
      <Chip
        name="Brand assets (2).zip"
        meta="12.4 MB · never opened"
        reduced={reduced}
        variants={chip}
        className="reel-chip--right"
      />
    </Reel>
  );
}

/* ---- 02 Skip — down, to the back of the queue ---- */

export function SkipReel() {
  const reduced = useReducedMotion();

  const front: Variants = {
    rest: { y: 0, opacity: 1, scale: 1 },
    play: {
      y: [0, 0, 128, 128, 0],
      opacity: [1, 1, 0, 0, 1],
      scale: [1, 1, 0.9, 0.9, 1],
      transition: loop([0, 0.18, 0.4, 0.88, 1]),
    },
  };
  const behind = (i: number): Variants => ({
    rest: { y: 0, scale: 1 - i * 0.045, opacity: 1 - i * 0.3 },
    play: {
      y: [0, 0, -20, -20, 0],
      scale: [1 - i * 0.045, 1 - i * 0.045, 1 - (i - 1) * 0.045, 1 - (i - 1) * 0.045, 1 - i * 0.045],
      opacity: [1 - i * 0.3, 1 - i * 0.3, 1 - (i - 1) * 0.3, 1 - (i - 1) * 0.3, 1 - i * 0.3],
      transition: loop([0, 0.34, 0.52, 0.88, 1]),
    },
  });

  return (
    <Reel>
      {[2, 1].map((i) => (
        <Chip
          key={i}
          name={i === 2 ? "Reading list.csv" : "A little more clarity.pdf"}
          meta={i === 2 ? "6 KB" : "284 KB"}
          reduced={reduced}
          variants={behind(i)}
          className="reel-chip--center"
          style={{ marginTop: -30 + i * 20, zIndex: 3 - i }}
        />
      ))}
      <Chip
        name="thesis-draft-FINAL.docx"
        meta="2.8 MB · decide later"
        reduced={reduced}
        variants={front}
        className="reel-chip--center"
        style={{ zIndex: 4 }}
      />
    </Reel>
  );
}

/* ---- 03 File — up, and three destination bins drop in ----
   DestinationShelf: at most three folders, each with a 1-3 shortcut,
   sliding down from the top edge as the drag rises. */

const bins = ["Projects", "Receipts", "Archive"];

function FolderIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.6" aria-hidden="true">
      <path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7Z" />
    </svg>
  );
}

export function FileReel() {
  const reduced = useReducedMotion();

  const chip: Variants = {
    rest: { y: 0, opacity: 1, scale: 1 },
    play: {
      y: [0, 0, -104, -104, 0],
      opacity: [1, 1, 0, 0, 1],
      scale: [1, 1, 0.84, 0.84, 1],
      transition: loop([0, 0.2, 0.44, 0.88, 1]),
    },
  };
  // the shelf is "attached to the drag, not triggered by it"
  const shelf: Variants = {
    rest: { y: -40, opacity: 0 },
    play: {
      y: [-40, -40, 0, 0, -40],
      opacity: [0, 0, 1, 1, 0],
      transition: loop([0, 0.16, 0.36, 0.88, 1]),
    },
  };
  const hit: Variants = {
    rest: { scale: 1 },
    play: { scale: [1, 1, 1.06, 1, 1], transition: loop([0, 0.42, 0.5, 0.62, 1]) },
  };

  return (
    <Reel>
      <motion.div className="reel-bins" variants={reduced ? undefined : shelf}>
        {bins.map((name, i) => (
          <motion.div
            key={name}
            className="reel-bin"
            data-hit={i === 0}
            variants={reduced || i !== 0 ? undefined : hit}
          >
            <FolderIcon />
            {name}
            <kbd>{i + 1}</kbd>
          </motion.div>
        ))}
      </motion.div>
      <Chip
        name="lecture-07-slides.pdf"
        meta="6.2 MB"
        reduced={reduced}
        variants={chip}
        className="reel-chip--bottom"
      />
    </Reel>
  );
}

/* ---- 04 Keep — right, and nothing moves ---- */

export function KeepReel() {
  const reduced = useReducedMotion();

  const chip: Variants = {
    rest: { x: 0 },
    play: { x: [0, 0, 16, 16, 0], transition: loop([0, 0.2, 0.34, 0.86, 1]) },
  };
  const tick: Variants = {
    rest: { scale: 0, opacity: 0 },
    play: {
      scale: [0, 0, 1, 1, 0],
      opacity: [0, 0, 1, 1, 0],
      transition: loop([0, 0.3, 0.42, 0.86, 1]),
    },
  };
  const note: Variants = {
    rest: { opacity: 0 },
    play: { opacity: [0, 0, 1, 1, 0], transition: loop([0, 0.42, 0.54, 0.86, 1]) },
  };

  return (
    <Reel>
      <Chip
        name="Semester planning notes.txt"
        meta="174 bytes · ~/Downloads"
        reduced={reduced}
        variants={chip}
        className="reel-chip--center"
      />
      <motion.div
        className="reel-tick"
        variants={reduced ? undefined : tick}
        style={{ position: "absolute", left: "calc(50% + 92px)", top: "calc(50% - 15px)" }}
        aria-hidden="true"
      >
        ✓
      </motion.div>
      <motion.p
        className="reel-note"
        variants={reduced ? undefined : note}
        style={reduced ? { opacity: 1 } : undefined}
      >
        Path unchanged · 0 bytes moved
      </motion.p>
    </Reel>
  );
}

export const reels = [StageReel, SkipReel, FileReel, KeepReel];
