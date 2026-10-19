"use client";

import { useEffect, useId, useRef, useState } from "react";
import type { PlatformRelease } from "@/lib/platforms";
import { DesktopIcon, LaptopIcon } from "./icons";
import InstallationGuide from "./installation-guide";

const installation = {
  macos: [
    { title: "Open the ZIP", text: "In Downloads, double-click the DClutter ZIP to unpack the app." },
    { title: "Move to Applications", text: "Drag DClutter.app into your Applications folder." },
    { title: "Allow the first launch", text: "Open DClutter once. If macOS blocks it, go to System Settings → Privacy & Security → Open Anyway, then confirm Open." },
  ],
  windows: [
    { title: "Open the installer", text: "In Downloads, double-click the DClutter setup .exe to begin." },
    { title: "Allow setup to run", text: "If you see “Windows protected your PC,” click More info, then Run anyway." },
    { title: "Finish and open", text: "Follow setup and click Finish. No administrator rights needed. You can also open DClutter from Start." },
  ],
};

export default function DownloadButton({
  release,
}: {
  release: PlatformRelease;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const dialogId = useId();
  const downloadTarget = `download-${dialogId}`;
  const titleId = useId();
  const descriptionId = useId();
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (!open) return;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = previous; };
  }, [open]);

  if (release.status !== "available") return null;

  const PlatformIcon = release.id === "macos" ? LaptopIcon : DesktopIcon;

  return (
    <>
      <a
        href={release.downloadUrl}
        target={downloadTarget}
        referrerPolicy="no-referrer"
        className="btn btn--download"
        data-platform={release.id}
        aria-haspopup="dialog"
        aria-controls={dialogId}
        aria-expanded={open}
        onClick={() => {
          dialog.current?.showModal();
          setOpen(true);
        }}
      >
        <span className="download-platform-icon" aria-hidden="true"><PlatformIcon /></span>
        <span>Download for {release.shortName}</span>
      </a>

      {/* Attachments download in this frame without opening an empty browser tab. */}
      <iframe name={downloadTarget} title={`DClutter for ${release.shortName} download`} hidden />

      <dialog
        ref={dialog}
        id={dialogId}
        className="download-modal"
        aria-labelledby={titleId}
        aria-describedby={descriptionId}
        onClose={() => setOpen(false)}
        onClick={(event) => {
          if (event.target === event.currentTarget) dialog.current?.close();
        }}
      >
        <div className="download-modal-panel">
          <button
            type="button"
            className="download-modal-close"
            aria-label="Close installation instructions"
            autoFocus
            onClick={() => dialog.current?.close()}
          >
            <span aria-hidden="true">×</span>
          </button>
          <p className="download-modal-eyebrow"><span aria-hidden="true">↧</span> Your download is starting</p>
          <h2 id={titleId}>How to install DClutter</h2>
          <p className="download-modal-description" id={descriptionId}>
            Three steps to install DClutter for {release.shortName}.
          </p>

          <ol className="installation-steps">
            {installation[release.id].map((step, index) => (
              <li key={step.title}>
                <div className="installation-image-wrap">
                  <InstallationGuide platform={release.id} version={release.version} step={index} />
                  <span className="installation-number" aria-hidden="true">{index + 1}</span>
                </div>
                <h3>{step.title}</h3>
                <p>{step.text}</p>
              </li>
            ))}
          </ol>

          <p className="download-modal-retry">Download didn’t start? <a href={release.downloadUrl} target={downloadTarget} referrerPolicy="no-referrer">Download again</a></p>
          <p className="download-modal-footer">
            {release.requirements} · {release.architecture} · v{release.version}
          </p>
        </div>
      </dialog>
    </>
  );
}
