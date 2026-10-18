import type { Metadata } from "next";
import SiteNav from "@/components/site-nav";
import { MAC_REPO } from "@/lib/platforms";

export const metadata: Metadata = {
  title: "Privacy · DClutter",
  description:
    "DClutter has no account, no server, and no analytics. This page says exactly what stays on your Mac and what does not.",
};

const UPDATED = "18 October 2026";

export default function Privacy() {
  return (
    <>
      <SiteNav />
      <main id="main" className="doc">
        <div className="wrap">
          <h1 className="display">Privacy</h1>
          <p className="lede doc-lede">
            DClutter has no account, no server, and no analytics. There is no
            code in the app that opens a network connection, so there is nothing
            for it to send and nowhere to send it.
          </p>

          <h2>What the app touches</h2>
          <p>
            DClutter runs inside the macOS App Sandbox. It can read and write
            your Downloads folder, plus any folder you pick yourself as a
            destination. It cannot reach anything else on your Mac.
          </p>
          <p>
            When you choose a destination folder, macOS hands the app a
            security-scoped bookmark so that folder is still reachable the next
            time you open it. The bookmark covers that folder and nothing
            around it.
          </p>
          <p>
            File names, file contents, and the previews you see are read on your
            Mac while the app is open. None of it is copied anywhere else.
          </p>

          <h2>What the app stores</h2>
          <p>
            Your progress through a folder is saved so you can close the app
            and pick the session back up. It is one JSON file per source folder,
            written inside the app&rsquo;s own sandbox container under{" "}
            <code>~/Library/Application Support</code>. The file is named after
            a hash of the folder&rsquo;s path rather than the path itself.
          </p>
          <p>
            It holds the decisions you made and which files are still staged.
            Deleting the app removes it.
          </p>

          <h2>What the app deletes</h2>
          <p>
            Nothing, directly. Staged files stay on disk until you confirm, and
            confirming moves them to the Trash, where you can still get them
            back. The app has no code path that erases a file outright.
          </p>

          <h2>This website</h2>
          <p>
            The site is a set of static files. It sets no cookies, runs no
            analytics, and has no forms or sign-ins. The two typefaces are
            served from the same place as the page, so loading it does not call
            out to a font service or anyone else.
          </p>
          <p>
            Whoever hosts the site will keep ordinary server logs, which
            normally include IP addresses. That is the host&rsquo;s doing rather
            than something the page asks for.
          </p>

          <h2>Downloading the app</h2>
          <p>
            The download button points at GitHub Releases, so the file comes
            from GitHub rather than from here. GitHub can see your IP address
            and browser when you fetch it, under{" "}
            <a href="https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement">
              their privacy statement
            </a>
            . This is the one part of using DClutter that another company
            observes, which is why it is on this page.
          </p>

          <h2>Your rights</h2>
          <p>
            There is no account to close and no data of yours held anywhere to
            request, correct, or erase. Everything DClutter knows about your
            files is on your own Mac, and deleting the app takes it with it.
          </p>

          <h2>Changes</h2>
          <p>
            If this ever stops being true, this page changes first, and the
            reason will be in the release notes. The source is public, so you
            can check any of the above yourself:{" "}
            <a href={MAC_REPO}>{MAC_REPO.replace("https://", "")}</a>.
          </p>

          <p className="doc-updated">Last updated {UPDATED}.</p>

          <p className="doc-back">
            <a href="/">Back to DClutter</a>
          </p>
        </div>
      </main>
    </>
  );
}
