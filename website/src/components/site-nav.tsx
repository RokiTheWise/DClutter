"use client";

import { useEffect, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";
import { platforms } from "@/lib/platforms";

const mac = platforms.macos;

export default function SiteNav() {
  const reduced = useReducedMotion();
  const [stuck, setStuck] = useState(false);
  const [pastHero, setPastHero] = useState(false);

  useEffect(() => {
    const onScroll = () => {
      setStuck(window.scrollY > 40);
      setPastHero(window.scrollY > window.innerHeight * 0.9);
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <>
      <div className="nav" data-stuck={stuck}>
        <div className="nav-inner">
          <a className="wordmark" href="#top" aria-label="DClutter, back to top">
            <img src="/logo.png" alt="" width={22} height={22} />
            DClutter
          </a>
          <nav className="nav-links" aria-label="Main">
            <a href="#decisions">How it works</a>
            <a href="#try-it">Try it</a>
            <a href="#privacy">Privacy</a>
          </nav>
          <a
            className="nav-cta"
            href={mac.status === "available" ? mac.downloadUrl : "#download"}
          >
            Download
          </a>
        </div>
      </div>

      <AnimatePresence>
        {pastHero ? (
          <motion.a
            className="tail-cta"
            href={mac.status === "available" ? mac.downloadUrl : "#download"}
            initial={reduced ? { x: "-50%" } : { opacity: 0, y: 28, x: "-50%" }}
            animate={{ opacity: 1, y: 0, x: "-50%" }}
            exit={reduced ? { x: "-50%" } : { opacity: 0, y: 28, x: "-50%" }}
            transition={{ duration: reduced ? 0 : 0.42, ease: [0.22, 1, 0.36, 1] }}
            whileHover={reduced ? undefined : { y: -3 }}
          >
            Download for Mac
            <span aria-hidden="true">↓</span>
          </motion.a>
        ) : null}
      </AnimatePresence>
    </>
  );
}
