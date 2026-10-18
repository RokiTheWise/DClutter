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
            <h2 className="display" id="try-heading" style={{ maxWidth: "18ch" }}>
              Try it before you download it.
            </h2>
            <p className="lede" style={{ marginTop: 22 }}>
              Click in and use the arrow keys, or the buttons if you&rsquo;d
              rather. These four are stand-ins, and nothing here touches anything
              on your computer.
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
