import { releases } from "@/lib/platforms";
import DownloadButton from "./download-button";

export default function SiteEnd() {
  return (
    <section className="end" id="download" aria-labelledby="download-heading">
      <div className="end-arc" aria-hidden="true" />
      <div className="wrap">
        <div className="end-cta">
          <div className="end-head">
            <h2 className="display" id="download-heading">Start with one file.</h2>
            <p className="lede">A clearer Downloads folder, a few minutes at a time.</p>
          </div>
          <div className="end-actions">
            {releases.map((release) =>
              release.status === "available" ? (
                <div className="end-platform" key={release.id}>
                  <DownloadButton release={release} />
                  <p>{release.requirements}<br />{release.architecture}</p>
                </div>
              ) : null,
            )}
            <p className="end-free">Free and open source.</p>
          </div>
        </div>
        <footer className="end-foot">
          <a className="end-brand" href="/" aria-label="DClutter, back to top">
            <img src="/logo.png" alt="" width={28} height={28} />
            DClutter
          </a>
          <nav className="end-links" aria-label="GitHub repositories">
            <h3>Source code</h3>
            {releases.map((release) => release.repositoryUrl ? (
              <a href={release.repositoryUrl} key={release.id}>{release.name}</a>
            ) : null)}
          </nav>
          <nav className="end-links" aria-label="Release notes">
            <h3>Release notes</h3>
            {releases.map((release) => release.status === "available" ? (
              <a href={release.releaseNotesUrl} key={release.id}>{release.name} · v{release.version}</a>
            ) : null)}
          </nav>
          <div className="end-bottom">
            <span>Open source under Apache 2.0.</span>
            <a href="/privacy">Privacy policy</a>
          </div>
        </footer>
      </div>
    </section>
  );
}
