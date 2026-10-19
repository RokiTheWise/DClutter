import PrivacyFolder from "./privacy-folder";

export default function Privacy() {
  return (
    <section className="band privacy-band" id="privacy" aria-labelledby="privacy-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap">
        <div className="privacy-grid">
          <div className="privacy-copy">
            <h2 className="display" id="privacy-heading">
              <span>Fully offline.</span>
              <span>Nothing uploaded.</span>
            </h2>
            <a className="doc-link privacy-policy-link" href="/privacy">
              Read more in the privacy policy.
            </a>
          </div>
          <PrivacyFolder />
        </div>
      </div>
    </section>
  );
}
