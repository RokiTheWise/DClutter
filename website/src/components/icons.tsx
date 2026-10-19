/** SF Symbols stand-ins, matching the symbols TriageView actually uses. */

const base = {
  viewBox: "0 0 24 24",
  fill: "none",
  stroke: "currentColor",
  strokeWidth: 1.7,
  strokeLinecap: "round" as const,
  strokeLinejoin: "round" as const,
  "aria-hidden": true,
};

export const GearIcon = () => (
  <svg {...base}>
    <circle cx="12" cy="12" r="3.2" />
    <path d="M19.4 14a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-2.9 1.2v.2a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0-1.2-2.9h-.2a2 2 0 1 1 0-4h.1a1.7 1.7 0 0 0 1.2-2.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3h.1A1.7 1.7 0 0 0 10 3.4v-.2a2 2 0 1 1 4 0v.1a1.7 1.7 0 0 0 2.9 1.2l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0 1.2 2.9h.2a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.6 1.1Z" />
  </svg>
);

/** arrow.uturn.backward */
export const UndoIcon = () => (
  <svg {...base}>
    <path d="M9 10 4 15l5 5" />
    <path d="M4 15h11a5 5 0 0 0 5-5V9a5 5 0 0 0-5-5H9" />
  </svg>
);

/** arrow.uturn.forward */
export const RedoIcon = () => (
  <svg {...base} style={{ transform: "scaleX(-1)" }}>
    <path d="M9 10 4 15l5 5" />
    <path d="M4 15h11a5 5 0 0 0 5-5V9a5 5 0 0 0-5-5H9" />
  </svg>
);

/** tray.full */
export const TrayIcon = () => (
  <svg {...base}>
    <path d="M3 14h4l1.5 2.5h7L17 14h4" />
    <path d="M5.4 5.6 3 14v3.5A1.5 1.5 0 0 0 4.5 19h15a1.5 1.5 0 0 0 1.5-1.5V14l-2.4-8.4A2 2 0 0 0 16.7 4H7.3a2 2 0 0 0-1.9 1.6Z" />
  </svg>
);

export const EllipsisIcon = () => (
  <svg {...base}>
    <circle cx="5" cy="12" r="1.1" fill="currentColor" stroke="none" />
    <circle cx="12" cy="12" r="1.1" fill="currentColor" stroke="none" />
    <circle cx="19" cy="12" r="1.1" fill="currentColor" stroke="none" />
  </svg>
);

export const TrashIcon = () => (
  <svg {...base}>
    <path d="M4 7h16M9.5 7V5.2A1.2 1.2 0 0 1 10.7 4h2.6a1.2 1.2 0 0 1 1.2 1.2V7" />
    <path d="M6.5 7l.8 11.3A1.8 1.8 0 0 0 9.1 20h5.8a1.8 1.8 0 0 0 1.8-1.7L17.5 7" />
  </svg>
);

/** arrow.uturn.right */
export const SkipIcon = () => (
  <svg {...base}>
    <path d="M15 5l5 5-5 5" />
    <path d="M20 10H9a5 5 0 0 0-5 5v4" />
  </svg>
);

export const FolderIcon = () => (
  <svg {...base}>
    <path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7Z" />
  </svg>
);

export const CheckIcon = () => (
  <svg {...base}>
    <path d="m4.5 12.5 5 5 10-11" />
  </svg>
);

export const OpenIcon = () => (
  <svg {...base}>
    <path d="M8 16 16 8M9.5 8H16v6.5" />
  </svg>
);

export const ChevronIcon = () => (
  <svg {...base} strokeWidth={2}>
    <path d="m7 10 5 5 5-5" />
  </svg>
);

/** Original device symbols for platform downloads, without third-party logos. */
export const LaptopIcon = () => (
  <svg {...base}>
    <rect x="5" y="4" width="14" height="11" rx="1.5" />
    <path d="m5 15-3 4h20l-3-4M9 19h6" />
  </svg>
);

export const DesktopIcon = () => (
  <svg {...base}>
    <rect x="3" y="4" width="18" height="13" rx="2" />
    <path d="M12 17v4M8 21h8" />
  </svg>
);
