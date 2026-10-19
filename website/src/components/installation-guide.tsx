import type { ReactNode } from "react";
import type { Platform } from "@/lib/platforms";

function Pointer() {
  return (
    <svg className="guide-pointer" viewBox="0 0 24 30" fill="none">
      <path d="M3 2v22l6-5 4 9 4-2-4-8h8L3 2Z" fill="#fff" stroke="#20242b" strokeWidth="1.8" strokeLinejoin="round" />
    </svg>
  );
}

function AppIcon() {
  return <span className="guide-app-icon" />;
}

function Folder() {
  return (
    <svg className="guide-folder" viewBox="0 0 88 70" fill="none">
      <path d="M4 15a8 8 0 0 1 8-8h22l9 9h33a8 8 0 0 1 8 8v36a7 7 0 0 1-7 7H11a7 7 0 0 1-7-7V15Z" fill="#66b9ec" />
      <path d="M4 28a7 7 0 0 1 7-7h66a7 7 0 0 1 7 7v32a7 7 0 0 1-7 7H11a7 7 0 0 1-7-7V28Z" fill="#8dd1f6" />
      <path d="m32 52 12-21 12 21M36 45h16" stroke="#4d9ccc" strokeWidth="4" strokeLinecap="round" />
    </svg>
  );
}

function MacWindow({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="guide-mac-window">
      <div className="guide-window-bar"><span className="guide-traffic"><i /><i /><i /></span><span>{title}</span></div>
      {children}
    </div>
  );
}

/** Focused, illustrative OS guides. The surrounding captions carry all instructions. */
export default function InstallationGuide({ platform, version, step }: { platform: Platform; version: string; step: number }) {
  return (
    <div className={`installation-visual installation-visual--${platform}`} aria-hidden="true">
      {platform === "macos" && step === 0 && (
        <MacWindow title="Downloads">
          <div className="guide-finder-layout">
            <div className="guide-finder-sidebar"><span>Favorites</span><span>Downloads</span><strong><Folder />Applications<Pointer /></strong></div>
            <span className="guide-finder-drag">←</span>
            <div className="guide-file-item"><AppIcon /><span>DClutter.app</span></div>
          </div>
        </MacWindow>
      )}
      {platform === "macos" && step === 1 && (
        <div className="guide-warning-shot">
          <img className="guide-mac-screenshot guide-mac-screenshot--warning" src="/install/mac-blocked.png" alt="" />
          <span className="guide-done-highlight" />
          <Pointer />
        </div>
      )}
      {platform === "macos" && step === 2 && (
        <img className="guide-mac-screenshot" src="/install/mac-privacy-security.png" alt="" />
      )}
      {platform === "macos" && step === 3 && (
        <div className="guide-mac-confirm">
          <AppIcon />
          <strong>Confirm the first launch</strong>
          <span className="guide-ui-button guide-ui-button--mac">Open<Pointer /></span>
          <p>Touch ID or password, if asked</p>
        </div>
      )}
      {platform === "windows" && step === 0 && (
        <div className="guide-explorer">
          <div className="guide-explorer-title">Downloads <span>−　□　×</span></div>
          <div className="guide-explorer-path">⌂　 ›　Downloads</div>
          <div className="guide-explorer-file"><AppIcon /><div><strong>DClutter_{version}_x64-setup.exe</strong><span>Application</span></div><Pointer /></div>
        </div>
      )}
      {platform === "windows" && step === 1 && (
        <div className="guide-smartscreen">
          <strong>Windows protected your PC</strong>
          <p>Microsoft Defender SmartScreen prevented an unrecognized app from starting.</p>
          <span className="guide-more-info">More info</span>
          <div className="guide-smartscreen-app">App: DClutter_{version}_x64-setup.exe</div>
          <div className="guide-smartscreen-actions"><span>Don’t run</span><span className="guide-run-anyway">Run anyway<Pointer /></span></div>
        </div>
      )}
      {platform === "windows" && step === 2 && (
        <div className="guide-setup">
          <div className="guide-explorer-title">DClutter Setup <span>×</span></div>
          <div className="guide-setup-body"><AppIcon /><div><strong>Completing DClutter Setup</strong><p>DClutter has been installed on your computer.</p><span className="guide-setup-check">☑ Run DClutter</span></div></div>
          <div className="guide-setup-footer"><span className="guide-ui-button guide-ui-button--windows">Finish<Pointer /></span></div>
        </div>
      )}
    </div>
  );
}
