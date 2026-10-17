import type { ReactNode } from "react";

export default function WindowChrome({
  children,
  tools = true,
  className = "",
}: {
  children: ReactNode;
  tools?: boolean;
  className?: string;
}) {
  return (
    <div className={`win ${className}`.trim()}>
      <div className="win-bar">
        <div className="win-dots" aria-hidden="true">
          <i style={{ background: "#ff5f57" }} />
          <i style={{ background: "#febc2e" }} />
          <i style={{ background: "#28c840" }} />
        </div>
        <div className="win-where">
          <div className="win-title">Downloads</div>
          <div className="win-path">~/Downloads</div>
        </div>
        {tools ? (
          <div className="win-tools" aria-hidden="true">
            <span>Undo</span>
            <span>Review trash</span>
          </div>
        ) : null}
      </div>
      {children}
    </div>
  );
}
