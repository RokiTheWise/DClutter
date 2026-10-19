import SiteNav from "./site-nav";
import Hero from "./hero";
import Pile from "./pile";
import Decisions from "./decisions";
import TriageDemo from "./triage-demo";
import Privacy from "./privacy";
import GitHubStats from "./github-stats";
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
          <div className="wrap demo-layout">
            <h2 className="display" id="try-heading">
              Try it before you download it.
            </h2>
            <p className="lede demo-intro">
              Use the arrow keys, or click the buttons.
            </p>
            <TriageDemo />
          </div>
        </section>

        <Privacy />
        <GitHubStats />
        <SiteEnd />
      </main>
    </>
  );
}
