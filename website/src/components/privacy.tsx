import { LaptopIcon } from "./icons";

const points = [
  {
    title: "No account.",
    body: "Open the app and get straight to your files.",
  },
  {
    title: "No uploads.",
    body: "File names, contents, and previews stay on your device.",
  },
  {
    title: "No tracking.",
    body: "No analytics, crash pings, or usage counters.",
  },
];

export default function Privacy() {
  return (
    <section className="band privacy-band" id="privacy" aria-labelledby="privacy-heading">
      <div className="band-arc" aria-hidden="true" />
      <div className="wrap">
        <div className="privacy-grid">
          <div className="privacy-copy">
            <h2 className="display" id="privacy-heading">
              Nothing leaves your computer.
            </h2>
            <p className="lede">
              Sort your files, even offline. Everything happens on your device.
            </p>
            <a className="doc-link privacy-policy-link" href="/privacy">
              Read the privacy policy <span aria-hidden="true">↗</span>
            </a>
          </div>

          <div className="privacy-visual" aria-hidden="true">
            <div className="privacy-folder-back" />
            <img className="privacy-paper privacy-paper--left" src="/demo/invoice.svg" alt="" width={144} height={190} />
            <img className="privacy-paper privacy-paper--right" src="/demo/lecture-notes.svg" alt="" width={144} height={190} />
            <img className="privacy-paper privacy-paper--center" src="/demo/research-proposal.svg" alt="" width={144} height={190} />
            <div className="privacy-folder-front">
              <span className="privacy-device"><LaptopIcon /> On your device</span>
            </div>
          </div>
        </div>

        <div className="privacy-points">
          {points.map((point) => (
            <div key={point.title}>
              <h3>{point.title}</h3>
              <p>{point.body}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
