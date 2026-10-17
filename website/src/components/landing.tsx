import SiteNav from "./site-nav";
import Hero from "./hero";
import Pile from "./pile";
import Decisions from "./decisions";
import TriageDemo from "./triage-demo";
import Privacy from "./privacy";
import UndoSection from "./undo-section";
import SiteEnd from "./site-end";

export default function Landing() {
  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <SiteNav />
      <main id="main">
        <Hero />
        <Pile />
        <Decisions />

        <section className="band demo-band" id="try-it" aria-labelledby="try-heading">
          <div className="band-arc" aria-hidden="true" />
          <div className="wrap">
            <span className="eyebrow">Four sample files, your keyboard</span>
            <h2 className="display" id="try-heading" style={{ marginTop: 18, maxWidth: "18ch" }}>
              Try it before you download it.
            </h2>
            <p className="lede" style={{ marginTop: 22 }}>
              This is the real thing, running in the page. Click into it and use
              the arrow keys — or the buttons, if you&rsquo;d rather. Nothing here
              touches anything on your computer.
            </p>
            <TriageDemo />
          </div>
        </section>

        <Privacy />
        <UndoSection />
        <SiteEnd />
      </main>
    </>
  );
}
