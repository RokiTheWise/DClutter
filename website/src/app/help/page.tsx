import SiteNav from "@/components/site-nav";
import { MAC_REPO, platforms, WIN_REPO } from "@/lib/platforms";
import { pageMetadata } from "@/lib/site";

export const metadata = pageMetadata("Help · DClutter", "What DClutter does, supported Mac and Windows versions, offline privacy, file staging, undo, and Mac installation.", "/help");

export default function Help() {
  return (
    <>
      <SiteNav />
      <main id="main" className="doc">
        <div className="wrap">
          <h1 className="display">A little help.</h1>
          <p className="lede doc-lede">The essentials, before you start sorting.</p>

          <h2>What is DClutter?</h2>
          <p>DClutter is a free, open-source file organizer for Mac and Windows. Review one file at a time: keep it, skip it, file it into a folder, or stage it for a second look.</p>

          <h2>Which computers does it support?</h2>
          <p>The Mac app requires {platforms.macos.requirements} and supports {platforms.macos.architecture}. The Windows app supports {platforms.windows.requirements} on {platforms.windows.architecture} computers.</p>

          <h2>Does DClutter work offline?</h2>
          <p>Yes. Sorting and previews happen on your device. You don’t need an account, and the app doesn’t upload your file names or contents. <a href="/privacy">Read the privacy policy.</a></p>

          <h2>Does it delete files automatically?</h2>
          <p>No. Staging sets a file aside for review; it stays on disk. You choose which staged files to send to Trash.</p>

          <h2>Can I undo a decision?</h2>
          <p>Yes. Use Undo to step back through sorting decisions in your session. Redo reapplies an undone decision.</p>

          <h2>How do I install it on a Mac?</h2>
          <p>Open the downloaded DMG, drag DClutter into Applications, then eject the disk image. The current release isn’t Developer ID signed or notarized, so the first launch requires approval in System Settings → Privacy &amp; Security → Open Anyway. The download dialog walks through each step.</p>

          <h2>Where is the source code?</h2>
          <p>Both versions are on GitHub: <a href={MAC_REPO}>DClutter for macOS</a> and <a href={WIN_REPO}>DClutter for Windows</a>. DClutter uses the <a href="/license">Apache License 2.0</a>.</p>

          <p className="doc-back"><a href="/#download">Download DClutter</a></p>
        </div>
      </main>
    </>
  );
}
