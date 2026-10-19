"use client";

import { useLayoutEffect, useRef, useState } from "react";
import Folder from "./react-bits/folder";

const documents = [
  { image: "/demo/invoice.svg", title: "October invoice", alt: "Sample October invoice" },
  { image: "/demo/research-proposal.svg", title: "Research proposal", alt: "Sample research proposal" },
  { image: "/demo/lecture-notes.svg", title: "Lecture notes", alt: "Sample lecture notes" },
];

export default function PrivacyFolder() {
  const hostRef = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState(1);

  useLayoutEffect(() => {
    const host = hostRef.current;
    if (!host) return;
    // Reserve room for the documents when they fan out of the folder.
    const fit = () => setSize(Math.min(1.4, Math.max(0.65, (host.clientWidth - 32) / 365)));
    const observer = new ResizeObserver(fit);
    observer.observe(host);
    fit();
    return () => observer.disconnect();
  }, []);

  return (
    <div className="privacy-visual" ref={hostRef}>
      <Folder
        items={documents}
        label="Your files"
        mode="flap"
        variant="glass"
        color="#83b9de"
        theme="light"
        size={size}
        openOn="click"
        draggable={false}
        tilt={0.35}
        bounce={0.25}
        speed={1.15}
        frost={0.35}
      />
    </div>
  );
}
