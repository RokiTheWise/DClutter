import type { Decision, SampleFile } from "@/lib/samples";
import FileCard from "./file-card";
import WindowChrome from "./window-chrome";
import { CheckIcon, FolderIcon, SkipIcon, TrayIcon, TrashIcon } from "./icons";

const file: SampleFile = {
  name: "Research proposal.pdf",
  type: "PDF document",
  size: "324 KB",
  lastOpened: "Yesterday",
  added: "17 Oct 2026",
  from: "Google Docs",
  preview: "notes",
  chips: [],
};
const actions = [
  { id: "stage", label: "Stage", key: "←", Icon: TrashIcon },
  { id: "skip", label: "Skip", key: "space", Icon: SkipIcon },
  { id: "file", label: "File", key: "↑", Icon: FolderIcon },
  { id: "keep", label: "Keep", key: "→", Icon: CheckIcon },
];
const outcomes = {
  stage: { Icon: TrayIcon, title: "Staged for a second look", detail: "Still in Downloads. You decide what goes to Trash." },
  skip: { Icon: SkipIcon, title: "Back in the queue", detail: "No rush. Come back to this one later." },
  file: { Icon: FolderIcon, title: "A place for everything", detail: "Choose a destination, then press Return to file." },
  keep: { Icon: CheckIcon, title: "Kept, right where it was", detail: "Same folder. Same file. One less decision." },
};

/** A persistent example keeps each action understandable without waiting on a loop. */
export function DecisionPreview({ decision }: { decision: Decision }) {
  const outcome = outcomes[decision];
  const Icon = outcome.Icon;
  return (
    <figure className="dec-example" data-decision={decision}>
      <div aria-hidden="true" inert>
        <WindowChrome className="dec-preview-win win--light" staged={decision === "stage" ? 1 : 0}>
          <div className="dec-file-stage" data-shelf={decision === "file"}>
            <FileCard file={file} preview={<img className="hero-demo-document" src="/demo/research-proposal.svg" alt="" />} />
            {decision === "file" && (
              <div className="dec-folder-shelf">
                <b>File into a folder</b>
                <p>← → to choose · Return to file · Esc to cancel</p>
                <div className="dec-folders">
                  {["Projects", "Receipts", "Archive"].map((name, index) => (
                    <div key={name} data-selected={index === 0}><FolderIcon /><span>{name}</span><kbd>{index + 1}</kbd></div>
                  ))}
                </div>
              </div>
            )}
          </div>
          <div className="dec-sample-actions">
            {actions.map((action) => <div key={action.id} data-selected={decision === action.id} data-hot={action.id === "stage"}><action.Icon /><span>{action.label}</span><kbd>{action.key}</kbd></div>)}
          </div>
          <div className="dec-window-status"><span>3 left</span><span>·</span><span>1 sorted</span></div>
        </WindowChrome>
      </div>
      <figcaption className="dec-outcome" aria-live="polite" aria-atomic="true">
        <span className="dec-outcome-icon"><Icon /></span>
        <span><strong>{outcome.title}</strong><span>{outcome.detail}</span></span>
      </figcaption>
    </figure>
  );
}
