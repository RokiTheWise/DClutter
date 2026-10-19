"use client";

import { useRef, useState, type KeyboardEvent } from "react";
import { decisions } from "@/lib/samples";
import { DecisionPreview } from "./decision-preview";
import { CheckIcon, FolderIcon, SkipIcon, TrashIcon } from "./icons";

const details = [
  { summary: "Review before you remove.", body: "Set it aside for a final look. Nothing leaves your folder until you review the list and send it to Trash." },
  { summary: "Decide later. Keep moving.", body: "Not sure yet? The file goes to the back of the queue, so you can come back to it with a clearer head." },
  { summary: "Give it a home.", body: "Press up, pick a folder, and it’s filed. Your destinations stay close for the next file, too." },
  { summary: "Right where it belongs.", body: "Keep leaves the file exactly where it is and marks it as handled. One less decision in your queue." },
];
const icons = [TrashIcon, SkipIcon, FolderIcon, CheckIcon];

export default function Decisions() {
  const [active, setActive] = useState(0);
  const tabs = useRef<(HTMLButtonElement | null)[]>([]);

  const onKey = (event: KeyboardEvent<HTMLButtonElement>, index: number) => {
    let next = index;
    if (event.key === "ArrowDown" || event.key === "ArrowRight") next = (index + 1) % decisions.length;
    else if (event.key === "ArrowUp" || event.key === "ArrowLeft") next = (index + decisions.length - 1) % decisions.length;
    else if (event.key === "Home") next = 0;
    else if (event.key === "End") next = decisions.length - 1;
    else return;
    event.preventDefault();
    setActive(next);
    tabs.current[next]?.focus();
  };

  return (
    <section className="band dec-band" id="decisions" aria-labelledby="dec-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap">
        <div className="dec-grid">
          <div className="dec-copy">
            <div className="dec-intro">
              <p className="dec-eyebrow">A little less dragging. A lot more deciding.</p>
              <h2 className="display" id="dec-heading">One file.<br />Four ways forward.</h2>
              <p className="dec-lede">You make the call. DClutter takes care of the moving.</p>
            </div>

            <div className="dec-list" role="tablist" aria-label="Ways to sort a file" aria-orientation="vertical">
              {decisions.map((decision, index) => {
                const Icon = icons[index];
                return (
                  <button
                    key={decision.id}
                    ref={(node) => { tabs.current[index] = node; }}
                    id={`decision-tab-${decision.id}`}
                    type="button"
                    role="tab"
                    className="dec-item"
                    data-active={index === active}
                    data-decision={decision.id}
                    aria-label={decision.label}
                    aria-describedby={`decision-summary-${decision.id}${index === active ? ` decision-detail-${decision.id}` : ""}`}
                    aria-selected={index === active}
                    aria-controls="decision-preview"
                    tabIndex={index === active ? 0 : -1}
                    onClick={() => setActive(index)}
                    onKeyDown={(event) => onKey(event, index)}
                  >
                    <span className="dec-head">
                      <span className="dec-icon"><Icon /></span>
                      <span className="dec-label"><span className="dec-name">{decision.label}</span><span className="dec-summary" id={`decision-summary-${decision.id}`}>{details[index].summary}</span></span>
                      <kbd className="dec-key" aria-label={`Shortcut: ${decision.keyLabel}`}>{decision.keyLabel}</kbd>
                    </span>
                    {index === active && <span className="dec-body" id={`decision-detail-${decision.id}`}>{details[index].body}</span>}
                  </button>
                );
              })}
            </div>
          </div>

          <div id="decision-preview" className="dec-preview" role="tabpanel" aria-labelledby={`decision-tab-${decisions[active].id}`} tabIndex={0}>
            <DecisionPreview decision={decisions[active].id} />
          </div>
        </div>
        <a className="dec-try" href="#try-it">Give it a try below <span aria-hidden="true">↘</span></a>
      </div>
    </section>
  );
}
