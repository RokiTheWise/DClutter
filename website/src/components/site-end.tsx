import { MAC_REPO, releases } from "@/lib/platforms";
import DownloadButton from "./download-button";

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
            Free, open source, and still being tuned.
            Made for the end of a semester or the end of a project.
          </p>

          <div className="end-actions">
            {releases.map((release) =>
              release.status === "available" ? (
                <DownloadButton
                  key={release.name}
                  release={release}
                />
              ) : null,
            )}
          </div>
        </div>

        <div className="end-releases">
          {releases.map((release) =>
            release.status === "available" ? (
              <div className="end-release" key={release.name}>
                <h3>{release.name}</h3>
                <dl>
                  <div>
                    <dt>Version</dt>
                    <dd>v{release.version}</dd>
                  </div>
                  <div>
                    <dt>Requires</dt>
                    <dd>{release.requirements}</dd>
                  </div>
                  <div>
                    <dt>Architecture</dt>
                    <dd>{release.architecture}</dd>
                  </div>
                </dl>
              </div>
            ) : (
              <div className="end-release" key={release.name}>
                <h3>{release.name}</h3>
                <p className="end-release-soon">In development.</p>
              </div>
            ),
          )}
          <div className="end-release">
            <h3>Both</h3>
            <dl>
              <div>
                <dt>Price</dt>
                <dd>Free</dd>
              </div>
              <div>
                <dt>License</dt>
                <dd>Apache 2.0</dd>
              </div>
              <div>
                <dt>Deletes</dt>
                <dd>Nothing, ever</dd>
              </div>
            </dl>
          </div>
        </div>

        <p className="end-closer">771 unmade decisions, finally made.</p>

        <div className="end-foot">
          <span>DClutter</span>
          {releases.map((release) =>
            release.status === "available" && release.releaseNotesUrl ? (
              <a href={release.releaseNotesUrl} key={release.name}>
                {release.name} release notes
              </a>
            ) : null,
          )}
          <a href={MAC_REPO}>GitHub</a>
          <a href="/privacy">Privacy policy</a>
          <span className="spacer">Made for the end of a semester.</span>
        </div>
      </div>
    </section>
  );
}
