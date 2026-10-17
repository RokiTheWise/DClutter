"use client";

import { useEffect, useState } from "react";
import { platforms } from "@/lib/platforms";

const mac = platforms.macos;

export default function SiteNav() {
  const [stuck, setStuck] = useState(false);

  useEffect(() => {
    const onScroll = () => setStuck(window.scrollY > 40);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
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
  );
}
