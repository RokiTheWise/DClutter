"use client";

import { useRef } from "react";
import {
  motion,
  useReducedMotion,
  useScroll,
  useTransform,
  type MotionValue,
} from "motion/react";

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
          <span className="eyebrow">The honest starting point</span>
          <h2 className="display" id="pile-heading" style={{ marginTop: 18 }}>
            Eight months of
            <br />
            &ldquo;I&rsquo;ll deal with it later.&rdquo;
          </h2>
          <p className="lede" style={{ marginTop: 22 }}>
            Downloads is where files go when a decision feels too small to make
            and too annoying to repeat. The folder isn&rsquo;t the problem. Making
            four hundred tiny choices in a row is.
          </p>
          <div className="pile-count">
            <b>412</b>
            <span className="lede" style={{ margin: 0 }}>
              files, give or take
            </span>
          </div>
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
