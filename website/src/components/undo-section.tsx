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
          <span className="eyebrow">Staged, not deleted</span>
          <h2 className="display" id="undo-heading" style={{ marginTop: 18 }}>
            Room to change your mind.
          </h2>
          <p className="lede" style={{ marginTop: 22 }}>
            Staging isn&rsquo;t deleting. Files you stage sit in a holding area until
            you review the whole batch, and every move the app makes is registered
            for undo before it happens — not after. Drag the handle and watch the
            session come apart.
          </p>
          <p className="lede" style={{ marginTop: 18 }}>
            When you do empty the staging area, files go to the Trash. DClutter
            never deletes anything outright.
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
