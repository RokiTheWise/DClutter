import { MAC_REPO, platforms } from "@/lib/platforms";

const mac = platforms.macos;
const win = platforms.windows;

export default function SiteEnd() {
  return (
    <section className="end" id="download" aria-labelledby="download-heading">
      <div className="end-arc" aria-hidden="true" />
      <div className="wrap">
        <div className="end-head">
          <h2 className="display" id="download-heading">
            So what are you waiting for?
            <br />
            Go empty a folder :&#41;
          </h2>
          <p className="lede">
            Free, open source, and built in a week. Eighteen downloads, six stars,
            and one fork from people who trusted it with their own files. Made for
            the end of a semester or the end of a project.
          </p>

          <div className="end-actions">
            {mac.status === "available" ? (
              <a className="btn" href={mac.downloadUrl}>
                Download for Mac
                <span aria-hidden="true">↓</span>
              </a>
            ) : null}
            <a className="btn-note" href={MAC_REPO}>
              View the source →
            </a>
          </div>
        </div>

        <div className="end-facts">
          <div>
            <span>VERSION</span>
            <b>{mac.status === "available" ? `v${mac.version}` : "—"}</b>
          </div>
          <div>
            <span>REQUIRES</span>
            <b>{mac.status === "available" ? mac.requirements : "—"}</b>
          </div>
          <div>
            <span>ARCHITECTURE</span>
            <b>{mac.status === "available" ? mac.architecture : "—"}</b>
          </div>
          <div>
            <span>PRICE</span>
            <b>Free</b>
          </div>
          <div>
            <span>DELETES</span>
            <b>Nothing, ever</b>
          </div>
        </div>

        <p className="end-closer">771 unmade decisions, finally made.</p>

        <div className="end-foot">
          <span>DClutter</span>
          {mac.status === "available" ? (
            <a href={mac.releaseNotesUrl}>Release notes</a>
          ) : null}
          <a href={MAC_REPO}>GitHub</a>
          {win.repositoryUrl ? (
            <a href={win.repositoryUrl}>Windows, in development</a>
          ) : null}
          <span className="spacer">Built in a week, Aug 28 to Sep 4, 2026.</span>
        </div>
      </div>
    </section>
  );
}
