"use client";

import { useId, useState } from "react";

const log = [
  { name: "Semester planning notes.txt", verb: "Kept" },
  { name: "A little more clarity.pdf", verb: "Filed" },
  { name: "Brand assets (2).zip", verb: "Staged" },
  { name: "Reading list.csv", verb: "Kept" },
  { name: "setup-arm64.dmg", verb: "Staged" },
];

export default function UndoSection() {
  const sliderId = useId();
  // how many of the moves above are still applied
  const [applied, setApplied] = useState(log.length);

  return (
    <section className="band undo-band" aria-labelledby="undo-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap undo-grid">
        <div>
          <h2 className="display" id="undo-heading">
            Room to change your mind.
          </h2>
          <p className="lede" style={{ marginTop: 22 }}>
            Staged files stay on disk. They sit in a holding area until you
            review the whole batch, and every move gets registered for undo before
            it runs. Drag the handle and watch the session come apart.
          </p>
          <p className="lede" style={{ marginTop: 18 }}>
            When you do empty the staging area, files go to the Trash, where you
            can still fish them out. A file that was never deleted is a lot easier
            to bring back than one you have to dig for.
          </p>
        </div>

        <div className="undo-panel">
          <div className="undo-log">
            {log.map((entry, i) => (
              <div className="undo-row" key={entry.name} data-undone={i >= applied}>
                <b>{entry.name}</b>
                <span className="undo-verb">{i >= applied ? "Undone" : entry.verb}</span>
              </div>
            ))}
          </div>

          <label className="undo-scrub-label" htmlFor={sliderId}>
            <span>Start of session</span>
            <span>
              {applied} of {log.length} applied
            </span>
          </label>
          <input
            id={sliderId}
            className="undo-scrub"
            type="range"
            min={0}
            max={log.length}
            step={1}
            value={applied}
            onChange={(event) => setApplied(Number(event.target.value))}
            aria-label="Rewind the session"
          />
        </div>
      </div>
    </section>
  );
}
