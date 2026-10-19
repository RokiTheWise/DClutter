import { releases } from "@/lib/platforms";
import DownloadButton from "./download-button";

export default function SiteEnd() {
  return (
    <section className="end" id="download" aria-labelledby="download-heading">
      <div className="end-arc" aria-hidden="true" />
      <div className="wrap">
        <div className="end-cta">
          <div className="end-head">
            <h2 className="display" id="download-heading">Ready to start with one file?</h2>
            <p className="lede">A clearer folder, a few minutes at a time.</p>
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
          </div>
        </div>
        <footer className="end-foot">
          <a className="end-brand" href="#top" aria-label="DClutter, back to top">
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
            <span className="end-attribution">Built by <a href="https://www.djenriquez.dev/">Dexter Jethro Enriquez</a></span>
            <nav className="end-legal" aria-label="Legal">
              <a href="/license">License</a>
              <a href="/privacy">Privacy policy</a>
            </nav>
          </div>
        </footer>
      </div>
    </section>
  );
}
