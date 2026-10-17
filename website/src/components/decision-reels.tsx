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

function Reel({ children, caption }: { children: ReactNode; caption: ReactNode }) {
  return (
    <motion.div initial="rest" whileInView="play" viewport={viewport}>
      <div className="reel-scene">{children}</div>
      <p className="reel-cap">{caption}</p>
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

/* ---- 01 Stage — left, into the holding area ---- */

export function StageReel() {
  const reduced = useReducedMotion();

  const chip: Variants = {
    rest: { x: 0, opacity: 1, scale: 1 },
    play: {
      x: [0, 0, -168, -168, 0],
      opacity: [1, 1, 0, 0, 1],
      scale: [1, 1, 0.86, 0.86, 1],
      transition: loop([0, 0.18, 0.42, 0.86, 1]),
    },
  };
  const landed: Variants = {
    rest: { opacity: 0.25, scale: 0.98 },
    play: {
      opacity: [0.25, 0.25, 1, 1, 0.25],
      scale: [0.98, 0.98, 1, 1, 0.98],
      transition: loop([0, 0.38, 0.5, 0.88, 1]),
    },
  };

  return (
    <Reel
      caption={
        <>
          <b>Stage</b> Still on disk. Nothing is in the Trash yet.
        </>
      }
    >
      <div className="reel-target reel-target--left">
        <h4>Staging area</h4>
        <div className="reel-row">Archive (4).zip</div>
        <div className="reel-row">setup-arm64.dmg</div>
        <motion.div className="reel-row" variants={reduced ? undefined : landed}>
          Brand assets (2).zip
        </motion.div>
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
    <Reel
      caption={
        <>
          <b>Skip</b> Back of the queue. You will see it again.
        </>
      }
    >
      {[2, 1].map((i) => (
        <Chip
          key={i}
          name={i === 2 ? "Reading list.csv" : "A little more clarity.pdf"}
          meta={i === 2 ? "6 KB" : "284 KB"}
          reduced={reduced}
          variants={behind(i)}
          className="reel-chip--center"
          style={{ marginTop: -28 + i * 20, zIndex: 3 - i }}
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

/* ---- 03 File — up, into a destination ---- */

export function FileReel() {
  const reduced = useReducedMotion();

  const chip: Variants = {
    rest: { y: 0, opacity: 1, scale: 1 },
    play: {
      y: [0, 0, -112, -112, 0],
      opacity: [1, 1, 0, 0, 1],
      scale: [1, 1, 0.84, 0.84, 1],
      transition: loop([0, 0.2, 0.44, 0.88, 1]),
    },
  };
  const hit: Variants = {
    rest: { scale: 1 },
    play: { scale: [1, 1, 1.05, 1, 1], transition: loop([0, 0.4, 0.5, 0.62, 1]) },
  };

  return (
    <Reel
      caption={
        <>
          <b>File</b> One destination, picked once, a keystroke away after that.
        </>
      }
    >
      <div className="reel-target reel-target--top">
        <h4>File into</h4>
        <motion.div className="reel-row" data-hit="true" variants={reduced ? undefined : hit}>
          Projects
        </motion.div>
        <div className="reel-row">Receipts</div>
        <div className="reel-row">Archive</div>
      </div>
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
    <Reel
      caption={
        <>
          <b>Keep</b> Marked as handled. It stops coming back.
        </>
      }
    >
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
