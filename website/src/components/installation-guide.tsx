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

const macScreenshots = [
  { src: "mac-dmg-light.png", width: 1286, height: 884 },
  { src: "mac-blocked-light.png", width: 522, height: 540, action: "done" },
  { src: "mac-privacy-security-light.png", width: 1450, height: 362, action: "settings" },
  { src: "mac-confirm-open-light.png", width: 522, height: 716, action: "confirm" },
];

/** Real Mac screenshots and illustrative Windows guides, with accessible captions outside. */
export default function InstallationGuide({ platform, version, step }: { platform: Platform; version: string; step: number }) {
  if (platform === "macos") {
    const screenshot = macScreenshots[step];
    if (!screenshot) return null;
    return (
      <div className="installation-visual installation-visual--macos" aria-hidden="true">
        <div className="guide-screenshot-frame" data-action={screenshot.action}>
          <img className="guide-mac-screenshot" src={`/install/${screenshot.src}`} width={screenshot.width} height={screenshot.height} alt="" />
          {screenshot.action && <><span className="guide-action-highlight" /><Pointer /></>}
        </div>
      </div>
    );
  }

  return (
    <div className={`installation-visual installation-visual--${platform}`} aria-hidden="true">
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
