"use client";

import { useRef, useState } from "react";
import {
  AnimatePresence,
  animate,
  motion,
  useMotionValue,
  useReducedMotion,
  useScroll,
  useTransform,
  type MotionValue,
} from "motion/react";

const START = 771;
const END = 3;

/**
 * The number does what the section describes: 771 collapses to the 3 that
 * were worth keeping. Fast at first and slow to settle, so it reads as a
 * count running out rather than a progress bar filling.
 */
function Countdown() {
  const reduced = useReducedMotion();
  const count = useMotionValue(reduced ? END : START);
  const shown = useTransform(count, (v) => Math.round(v));
  const [sorted, setSorted] = useState(Boolean(reduced));

  return (
    <motion.div
      className="pile-count"
      // Runs once and keeps the settled state. Replaying it on the way back up
      // put the pile back to 771, undoing the thing the section just said.
      viewport={{ once: true, amount: 0.8 }}
      onViewportEnter={() => {
        if (reduced) return;
        // A hard ease-out lands on the value well before the duration is up,
        // so the label follows the number rather than onComplete. Otherwise it
        // sits reading "3 files in Downloads" for half a second.
        animate(count, END, {
          duration: 1.6,
          ease: [0.16, 1, 0.3, 1],
          onUpdate: (v) => {
            if (Math.round(v) <= END) setSorted(true);
          },
        });
      }}
    >
      <b>
        <motion.span>{shown}</motion.span>
      </b>
      <span className="pile-count-label">
        <AnimatePresence mode="wait" initial={false}>
          <motion.span
            key={sorted ? "after" : "before"}
            initial={reduced ? false : { opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            exit={reduced ? { opacity: 0 } : { opacity: 0, y: -6 }}
            transition={{ duration: reduced ? 0 : 0.3 }}
          >
            {sorted ? `left. Down from ${START}.` : "files in Downloads"}
          </motion.span>
        </AnimatePresence>
      </span>
    </motion.div>
  );
}

/** Deterministic scatter, so the server and client render the same thing. */
const chits = [
  { name: "IMG_4417.HEIC", meta: "3.1 MB", x: -168, y: -122, r: -13 },
  { name: "invoice-final-v3.pdf", meta: "88 KB", x: 142, y: -148, r: 9 },
  { name: "Screen Shot 2026-04-02.png", meta: "1.4 MB", x: -46, y: -168, r: 4 },
  { name: "dataset_cleaned (1).csv", meta: "640 KB", x: 186, y: -34, r: -7 },
  { name: "lecture-07-slides.pdf", meta: "6.2 MB", x: -198, y: 18, r: 11 },
  { name: "setup-arm64.dmg", meta: "142 MB", x: 58, y: 36, r: -4 },
  { name: "thesis-draft-FINAL.docx", meta: "2.8 MB", x: -120, y: 136, r: 7 },
  { name: "Archive (4).zip", meta: "54 MB", x: 164, y: 148, r: -11 },
  { name: "receipt_9823.pdf", meta: "72 KB", x: 6, y: 166, r: 14 },
  { name: "profile-pic-crop.png", meta: "880 KB", x: -238, y: -42, r: -6 },
];

function Chit({
  chit,
  index,
  progress,
  reduced,
}: {
  chit: (typeof chits)[number];
  index: number;
  progress: MotionValue<number>;
  reduced: boolean | null;
}) {
  // each card lands on a slightly different beat, so the pile collapses
  // in a ripple rather than all at once
  const start = index * 0.045;
  const end = start + 0.5;

  const x = useTransform(progress, [start, end], [chit.x, index * 2 - 9]);
  const y = useTransform(progress, [start, end], [chit.y, index * 10 - 48]);
  const rotate = useTransform(progress, [start, end], [chit.r, 0]);
  const scale = useTransform(progress, [start, end], [1, 0.97]);

  if (reduced) {
    return (
      <div
        className="pile-chit"
        style={{ transform: `translate(${chit.x}px, ${chit.y}px)` }}
      >
        <b>{chit.name}</b>
        <span>{chit.meta}</span>
      </div>
    );
  }

  return (
    <motion.div
      className="pile-chit"
      style={{ x, y, rotate, scale, zIndex: index }}
    >
      <b>{chit.name}</b>
      <span>{chit.meta}</span>
    </motion.div>
  );
}

export default function Pile() {
  const ref = useRef<HTMLDivElement>(null);
  const reduced = useReducedMotion();

  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start 78%", "end 52%"],
  });

  return (
    <section className="band pile-band" aria-labelledby="pile-heading">
      <div className="wrap pile-grid">
        <div>
          <h2 className="display" id="pile-heading">
            771 files, and no
            <br />
            idea where to start.
          </h2>
          <p className="lede" style={{ marginTop: 22 }}>
            I opened my Mac after finals and wondered when I’d last organized
            anything. Then I opened Downloads. Whiplash. Deciding what to keep was
            easy. Opening files, dragging them around, and finding my place again
            was what turned it into an afternoon.
          </p>
          <p className="lede" style={{ marginTop: 18 }}>
            So I built DClutter. That afternoon became a few minutes here and
            there, one file at a time. Somewhere between old assignments and
            forgotten projects, cleaning up started to feel like going down
            memory lane.
          </p>
          <p className="lede" style={{ marginTop: 18 }}>
            Who would’ve thought sorting files could be a little enjoyable?
          </p>
          <Countdown />
        </div>

        <div className="pile-stage" ref={ref} aria-hidden="true">
          {chits.map((chit, i) => (
            <Chit
              key={chit.name}
              chit={chit}
              index={i}
              progress={scrollYProgress}
              reduced={reduced}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
