import { MAC_REPO, platforms } from "@/lib/platforms";

const mac = platforms.macos;
const win = platforms.windows;

export default function SiteEnd() {
  return (
    <section className="end on-ink" id="download" aria-labelledby="download-heading">
      <div className="end-arc" aria-hidden="true" />
      <div className="wrap">
        <div className="end-head">
          <span className="eyebrow" style={{ color: "rgba(247,233,208,.42)" }}>
            Here&rsquo;s to a lighter desktop
          </span>
          <h2 className="display" id="download-heading" style={{ marginTop: 18 }}>
            A little less clutter.
            <br />A little more clarity.
          </h2>
          <p className="lede">
            Free, open source, and yours to read line by line. Built for the end
            of a semester or the end of a project — not for every day.
          </p>

          <div className="end-actions">
            {mac.status === "available" ? (
              <a className="btn btn--invert" href={mac.downloadUrl}>
                Download for Mac
                <span aria-hidden="true">↓</span>
              </a>
            ) : null}
            <a className="btn-note" href={MAC_REPO} style={{ color: "rgba(247,233,208,.62)" }}>
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

        <div className="end-foot">
          <span>DClutter</span>
          {mac.status === "available" ? (
            <a href={mac.releaseNotesUrl}>Release notes</a>
          ) : null}
          <a href={MAC_REPO}>GitHub</a>
          {win.repositoryUrl ? (
            <a href={win.repositoryUrl}>Windows — in development</a>
          ) : null}
          <span className="spacer">Made for the end of a semester.</span>
        </div>
      </div>
    </section>
  );
}
