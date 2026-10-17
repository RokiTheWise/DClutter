"use client";

import { motion, useReducedMotion } from "motion/react";

const points = [
  {
    title: "No account, ever.",
    body: "There is nothing to sign up for. Open the app and it works, offline, on the first launch.",
  },
  {
    title: "Nothing is uploaded.",
    body: "File names, contents and previews are read on your Mac and never leave it. There is no server to send them to.",
  },
  {
    title: "No telemetry.",
    body: "No analytics, no crash pings, no usage counters. The app has no idea what you sorted, and neither does anyone else.",
  },
];

export default function Privacy() {
  const reduced = useReducedMotion();

  return (
    <section className="band privacy-band" id="privacy" aria-labelledby="privacy-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap">
        <span className="eyebrow">Local by construction</span>
        <h2 className="display" id="privacy-heading" style={{ marginTop: 18, maxWidth: "15ch" }}>
          Nothing leaves your Mac.
        </h2>

        <div className="privacy-stage" aria-hidden="true">
          <div className="privacy-fence" />
          <motion.div
            className="pile-chit"
            style={{ position: "relative", left: "auto", top: "auto", margin: 0 }}
            initial={reduced ? false : { x: 0 }}
            whileInView={reduced ? undefined : { x: [0, 260, 260, 0] }}
            viewport={{ once: true, amount: 0.6 }}
            transition={{
              duration: 2.4,
              times: [0, 0.42, 0.58, 1],
              ease: [0.22, 1, 0.36, 1],
              delay: 0.3,
            }}
          >
            <b>Semester planning notes.txt</b>
            <span>174 bytes · stays here</span>
          </motion.div>
        </div>

        <div className="privacy-points">
          {points.map((p) => (
            <div key={p.title}>
              <h3>{p.title}</h3>
              <p>{p.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
