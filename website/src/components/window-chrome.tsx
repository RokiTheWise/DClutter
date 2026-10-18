import type { ReactNode } from "react";
import {
  ChevronIcon,
  EllipsisIcon,
  GearIcon,
  RedoIcon,
  TrayIcon,
  UndoIcon,
} from "./icons";

/**
 * The app's control bar, in the order TriageView builds it: settings, the
 * folder field with its path, undo and redo, the Review trash counter, and
 * the session menu.
 */
export default function WindowChrome({
  children,
  staged = 0,
  canUndo = false,
  canRedo = false,
  onUndo,
  onRedo,
  className = "",
}: {
  children: ReactNode;
  staged?: number;
  canUndo?: boolean;
  canRedo?: boolean;
  onUndo?: () => void;
  onRedo?: () => void;
  className?: string;
}) {
  const live = Boolean(onUndo);

  return (
    <div className={`win ${className}`.trim()}>
      <div className="win-bar">
        <div className="win-dots" aria-hidden="true">
          <i style={{ background: "#ff5f57" }} />
          <i style={{ background: "#febc2e" }} />
          <i style={{ background: "#28c840" }} />
        </div>

        <span className="win-icon" aria-hidden="true">
          <GearIcon />
        </span>

        <div className="win-where">
          <div className="win-title">
            Downloads
            <span className="win-chevron" aria-hidden="true">
              <ChevronIcon />
            </span>
          </div>
          <div className="win-path">~/Downloads</div>
        </div>

        <div className="win-history">
          <button
            type="button"
            className="win-icon"
            onClick={onUndo}
            disabled={!live || !canUndo}
            aria-label="Undo"
            tabIndex={live ? 0 : -1}
          >
            <UndoIcon />
          </button>
          <button
            type="button"
            className="win-icon"
            onClick={onRedo}
            disabled={!live || !canRedo}
            aria-label="Redo"
            tabIndex={live ? 0 : -1}
          >
            <RedoIcon />
          </button>
        </div>

        <span className="win-trash" data-armed={staged > 0} aria-hidden="true">
          <TrayIcon />
          Review trash
          <b>{staged}</b>
        </span>

        <span className="win-icon" aria-hidden="true">
          <EllipsisIcon />
        </span>
      </div>
      {children}
    </div>
  );
}
