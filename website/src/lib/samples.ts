export type Decision = "stage" | "skip" | "file" | "keep";

export type SampleFile = {
  name: string;
  type: string;
  size: string;
  lastOpened: string;
  added: string;
  from: string;
  preview: "notes" | "poster" | "archive" | "sheet";
};

export const samples: SampleFile[] = [
  {
    name: "Semester planning notes.txt",
    type: "Plain text",
    size: "174 bytes",
    lastOpened: "17 Oct 2026",
    added: "17 Oct 2026",
    from: "—",
    preview: "notes",
  },
  {
    name: "A little more clarity.pdf",
    type: "PDF document",
    size: "284 KB",
    lastOpened: "Never",
    added: "2 Mar 2026",
    from: "Design inspiration",
    preview: "poster",
  },
  {
    name: "Brand assets (2).zip",
    type: "ZIP archive",
    size: "12.4 MB",
    lastOpened: "Never",
    added: "19 Jan 2026",
    from: "dropbox.com",
    preview: "archive",
  },
  {
    name: "Reading list.csv",
    type: "Comma-separated values",
    size: "6 KB",
    lastOpened: "Yesterday",
    added: "4 Sep 2026",
    from: "—",
    preview: "sheet",
  },
];

export const decisions: {
  id: Decision;
  label: string;
  key: string;
  keyLabel: string;
  blurb: string;
  result: string;
}[] = [
  {
    id: "stage",
    label: "Stage",
    key: "ArrowLeft",
    keyLabel: "←",
    blurb:
      "Headed for the bin, but not yet. Swipe left and the file moves to a holding area, still on disk. You get the whole list for a second look, and even then it goes to the Trash.",
    result: "Staged for review. Still on disk.",
  },
  {
    id: "skip",
    label: "Skip",
    key: " ",
    keyLabel: "space",
    blurb:
      "No decision is a decision too. Skipped files drop back into the queue, so you keep moving instead of stalling on the hard one.",
    result: "Skipped. Back in the queue.",
  },
  {
    id: "file",
    label: "File",
    key: "ArrowUp",
    keyLabel: "↑",
    blurb:
      "Press up and your three folders slide in. Pick one and it is filed, or hit 1, 2, or 3 and skip the picking. They stay on the shelf for the rest of the session.",
    result: "Filed into Projects.",
  },
  {
    id: "keep",
    label: "Keep",
    key: "ArrowRight",
    keyLabel: "→",
    blurb:
      "Leave it exactly where it is. Keep marks the file as handled so it stops showing up, without a single byte moving.",
    result: "Kept. Right where it belongs.",
  },
];

/** Where a card leaves the frame, by decision. */
export const exitVector: Record<Decision, { x: number; y: number }> = {
  stage: { x: -420, y: 0 },
  keep: { x: 420, y: 0 },
  file: { x: 0, y: -380 },
  skip: { x: 0, y: 320 },
};
