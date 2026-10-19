"use client";

import { useRef } from "react";
import { motion, useReducedMotion, useScroll, useTransform } from "motion/react";
import HeroDemo from "./hero-demo";
import { MAC_REPO, releases } from "@/lib/platforms";
import DownloadButton from "./download-button";

const EASE = [0.22, 1, 0.36, 1] as const;

export default function Hero() {
  const ref = useRef<HTMLElement>(null);
  const reduced = useReducedMotion();

  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start start", "end start"],
  });

  // the two ridges travel at different rates, so the horizon has depth
  const ridgeBack = useTransform(scrollYProgress, [0, 1], ["0%", "18%"]);
  const ridgeFront = useTransform(scrollYProgress, [0, 1], ["0%", "38%"]);
  const copyFade = useTransform(scrollYProgress, [0, 0.55], [1, 0]);
  const copyLift = useTransform(scrollYProgress, [0, 1], ["0%", "-22%"]);

  const line = (i: number) => ({
    initial: reduced ? false : { y: "105%" },
    animate: { y: "0%" },
    transition: { duration: 0.9, ease: EASE, delay: 0.1 + i * 0.09 },
  });

  return (
    <section className="hero" id="top" ref={ref}>
      <div className="hero-sun" aria-hidden="true" />

      <div className="hero-ridge" aria-hidden="true">
        <svg viewBox="0 0 1440 320" preserveAspectRatio="none">
          <motion.path
            style={reduced ? undefined : { y: ridgeBack }}
            d="M0,212 L170,122 L300,198 L430,98 L560,192 L700,142 L860,206 L1010,120 L1160,200 L1290,134 L1440,206 L1440,320 L0,320 Z"
            fill="var(--sage)"
            opacity="0.85"
          />
          <motion.path
            style={reduced ? undefined : { y: ridgeFront }}
            d="M0,248 L190,174 L340,240 L520,162 L690,236 L880,180 L1060,248 L1240,188 L1440,250 L1440,320 L0,320 Z"
            fill="var(--blush)"
            opacity="0.8"
          />
        </svg>
      </div>

      <motion.div
        className="wrap hero-copy"
        style={reduced ? undefined : { opacity: copyFade, y: copyLift }}
      >
        <h1>
          <span className="line-mask">
            <motion.span style={{ display: "block" }} {...line(0)}>
              Meet your files. Again.
            </motion.span>
          </span>
        </h1>

        <motion.p
          className="lede"
          initial={reduced ? false : { opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, ease: EASE, delay: 0.42 }}
        >
          Rediscover what’s worth keeping. Clear out what isn’t
        </motion.p>

        <motion.div
          className="hero-actions"
          initial={reduced ? false : { opacity: 0, y: 14 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, ease: EASE, delay: 0.54 }}
        >
          <div className="hero-downloads">
            {releases.map((release) =>
              release.status === "available" ? (
                <DownloadButton
                  key={release.name}
                  release={release}
                />
              ) : null,
            )}
          </div>
          <span className="btn-note">Free and <a href={MAC_REPO}>open source</a></span>
        </motion.div>
      </motion.div>

      <motion.div
        className="hero-tray"
        initial={reduced ? false : { opacity: 0, y: 70 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 1.1, ease: EASE, delay: 0.3 }}
      >
        <HeroDemo />
      </motion.div>
    </section>
  );
}
