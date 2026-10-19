"use client";

import { useLayoutEffect, useRef, useState } from "react";
import Folder from "./react-bits/folder";

const privacyPoints = [
  { title: "No account.", body: "Open the app and get straight to your files." },
  { title: "No uploads.", body: "File names, contents, and previews stay on your device." },
  { title: "No tracking.", body: "No analytics, crash pings, or usage counters." },
];

const cards = privacyPoints.map((point) => ({
  content: (
    <div className="privacy-folder-card">
      <h3>{point.title}</h3>
      <p>{point.body}</p>
    </div>
  ),
}));

export default function PrivacyFolder() {
  const hostRef = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState(1);

  useLayoutEffect(() => {
    const host = hostRef.current;
    if (!host) return;
    // Reserve room for the privacy cards when they fan out of the folder.
    const fit = () => setSize(Math.min(1.4, Math.max(0.65, (host.clientWidth - 32) / 365)));
    const observer = new ResizeObserver(fit);
    observer.observe(host);
    fit();
    return () => observer.disconnect();
  }, []);

  return (
    <div className="privacy-visual" ref={hostRef}>
      <Folder
        items={cards}
        label="Privacy"
        mode="flap"
        variant="glass"
        color="#83b9de"
        theme="light"
        size={size}
        openOn="click"
        defaultOpen
        closeOnOutsideClick={false}
        draggable={false}
        tilt={0.35}
        bounce={0.25}
        speed={1.15}
        frost={0.35}
      />
    </div>
  );
}
