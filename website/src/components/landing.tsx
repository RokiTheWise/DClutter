"use client";

import {
  useEffect,
  useRef,
  useState,
  type CSSProperties,
  type ReactNode,
} from "react";
import {
  AnimatePresence,
  MotionConfig,
  motion,
  useReducedMotion,
} from "motion/react";
import {
  ArrowDown,
  ArrowDownToLine,
  ArrowUpRight,
  Check,
  ChevronDown,
  Code2,
  Folder,
  Layers,
  LockKeyhole,
  Pause,
  Play,
  RotateCcw,
  ShieldCheck,
  SkipForward,
  Trash2,
  Undo2,
} from "lucide-react";

const REPO = "https://github.com/RokiTheWise/DClutter";
const DOWNLOAD = `${REPO}/releases/download/v1.1.0/DClutter-1.1.0.zip`;
const release = `${REPO}/releases/tag/v1.1.0`;

function Reveal({
  children,
  className = "",
  delay = 0,
}: {
  children: ReactNode;
  className?: string;
  delay?: number;
}) {
  const reduced = useReducedMotion();
  return (
    <motion.div
      className={className}
      initial={{ opacity: 1, y: reduced ? 0 : 24 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-40px" }}
      transition={{ duration: reduced ? 0 : 0.7, delay }}
    >
      {children}
    </motion.div>
  );
}

function DownloadLink({
  className = "",
  children = "Download for Mac",
}: {
  className?: string;
  children?: ReactNode;
}) {
  return (
    <a className={`button primary ${className}`} href={DOWNLOAD}>
      <ArrowDownToLine size={18} />
      {children}
      <span className="button-arrow">↗</span>
    </a>
  );
}

const samples = [
  {
    name: "A little more clarity.pdf",
    type: "PDF document",
    size: "284 KB",
    lastOpened: "Never",
    theme: "poster",
    source: "Design inspiration",
    tag: "Never opened",
  },
  {
    name: "Project notes.txt",
    type: "Text document",
    size: "4 KB",
    lastOpened: "Last week",
    theme: "notes",
    source: "Project planning",
    tag: "Worth another look",
  },
  {
    name: "Brand assets (2).zip",
    type: "ZIP archive",
    size: "12 MB",
    lastOpened: "Never",
    theme: "archive",
    source: "Design resources",
    tag: "2 copies",
  },
  {
    name: "Weekend ideas.pdf",
    type: "PDF document",
    size: "96 KB",
    lastOpened: "Yesterday",
    theme: "weekend",
    source: "Personal projects",
    tag: "Recently opened",
  },
];
type Decision = "stage" | "skip" | "file" | "keep";
const descriptions = {
  stage: "Staged for review. Still on disk.",
  skip: "Skipped for now. Back in the queue.",
  file: "Filed into Projects. Moves can be undone.",
  keep: "Kept. Right where it belongs.",
};

function FileDemo() {
  const reduced = useReducedMotion();
  const [queue, setQueue] = useState([0, 1, 2, 3]);
  const [history, setHistory] = useState<
    { queue: number[]; staged: number; sorted: number }[]
  >([]);
  const [sorted, setSorted] = useState(0);
  const [staged, setStaged] = useState(0);
  const [status, setStatus] = useState("A few sample files. Give it a try.");
  const [direction, setDirection] = useState(1);
  const [shelf, setShelf] = useState(false);
  const [review, setReview] = useState(false);
  const [transitioning, setTransitioning] = useState(false);
  const sample = samples[queue[0]];

  function decide(action: Decision, folder = "Projects") {
    if (!sample || transitioning) return;
    if (action === "skip" && queue.length === 1) {
      setStatus(
        "This is the last sample file. Keep, stage, or file it when you’re ready.",
      );
      return;
    }
    setTransitioning(true);
    setHistory((previous) => [
      ...previous,
      { queue: [...queue], staged, sorted },
    ]);
    setDirection(action === "stage" ? -1 : action === "file" ? 0 : 1);
    setQueue(
      action === "skip" ? [...queue.slice(1), queue[0]] : queue.slice(1),
    );
    if (action !== "skip") setSorted(sorted + 1);
    if (action === "stage") setStaged(staged + 1);
    setStatus(
      action === "file"
        ? `Filed into ${folder}. Moves can be undone.`
        : descriptions[action],
    );
    setShelf(false);
  }
  function undo() {
    const previous = history.at(-1);
    if (!previous || transitioning) return;
    setTransitioning(true);
    setQueue(previous.queue);
    setStaged(previous.staged);
    setSorted(previous.sorted);
    setHistory(history.slice(0, -1));
    setShelf(false);
    setReview(false);
    setStatus("Undone. Take another look.");
  }
  function reset() {
    setQueue([0, 1, 2, 3]);
    setStaged(0);
    setSorted(0);
    setHistory([]);
    setReview(false);
    setShelf(false);
    setStatus("A few sample files. Give it a try.");
  }

  return (
    <div
      className="demo-shell"
      aria-label="Interactive DClutter demo with sample files"
      role="region"
      tabIndex={0}
      onKeyDown={(event) => {
        if (
          event.target !== event.currentTarget ||
          event.repeat ||
          transitioning ||
          shelf ||
          review
        )
          return;
        if (event.key === "ArrowLeft") {
          event.preventDefault();
          decide("stage");
        }
        if (event.key === "ArrowRight") {
          event.preventDefault();
          decide("keep");
        }
        if (event.key === "ArrowUp" && sample) {
          event.preventDefault();
          setShelf(true);
        }
        if (event.key === " ") {
          event.preventDefault();
          decide("skip");
        }
      }}
    >
      <div className="demo-toolbar">
        <span className="window-dots" aria-hidden="true">
          <i />
          <i />
          <i />
        </span>
        <span>
          <Folder size={14} /> Downloads
        </span>
        <button
          className="icon-button"
          onClick={undo}
          disabled={!history.length || transitioning}
          aria-label="Undo demo decision"
        >
          <Undo2 size={16} />
        </button>
      </div>
      <div className="demo-stage">
        <div className="stack-back back-one" />
        <div className="stack-back back-two" />
        <AnimatePresence
          mode="wait"
          custom={direction}
          onExitComplete={() => setTransitioning(false)}
        >
          {sample ? (
            <motion.div
              key={sample.name}
              className="file-card"
              custom={direction}
              initial={reduced ? false : { opacity: 0, y: 16, scale: 0.97 }}
              animate={{ opacity: 1, y: 0, scale: 1 }}
              exit={
                reduced
                  ? { opacity: 0 }
                  : {
                      opacity: 0,
                      x: direction * 100,
                      y: direction === 0 ? -60 : 8,
                      rotate: direction * 7,
                    }
              }
              transition={{ duration: reduced ? 0 : 0.24 }}
              drag={reduced || shelf || review ? false : "x"}
              dragConstraints={{ left: 0, right: 0 }}
              dragElastic={0.3}
              onDragEnd={(_, info) => {
                if (info.offset.x < -65) decide("stage");
                else if (info.offset.x > 65) decide("keep");
              }}
            >
              <div className={`file-preview ${sample.theme}`}>
                {sample.theme === "poster" ? (
                  <>
                    <div className="poster-top">
                      FIELD NOTES <span>VOL. 01 / 2026</span>
                    </div>
                    <div className="poster-title">
                      A little
                      <br />
                      more
                      <br />
                      <em>clarity.</em>
                    </div>
                    <div className="poster-disc" />
                    <div className="poster-bottom">
                      MAKE ROOM FOR WHAT MATTERS <ArrowUpRight size={17} />
                    </div>
                  </>
                ) : sample.theme === "notes" ? (
                  <div className="note-paper">
                    <span>MONDAY, A FRESH START</span>
                    <h3>
                      Good things
                      <br />
                      take a little space.
                    </h3>
                    <p>
                      01 / Gather the ideas
                      <br />
                      02 / Keep the good ones
                      <br />
                      03 / Make something great
                    </p>
                    <span>One thing at a time.</span>
                  </div>
                ) : sample.theme === "archive" ? (
                  <div className="archive-preview">
                    <Layers size={82} strokeWidth={1} />
                    <span>BRAND ASSETS</span>
                    <b>
                      Everything.
                      <br />
                      Twice.
                    </b>
                  </div>
                ) : (
                  <div className="weekend-preview">
                    <span>THE OFFLINE LIST</span>
                    <div className="sun" />
                    <b>
                      Less scrolling.
                      <br />
                      More wandering.
                    </b>
                  </div>
                )}
              </div>
              <div className="file-details">
                <div className="file-title">{sample.name}</div>
                <div className="file-subtitle">
                  {sample.type} <span>·</span> {sample.size}
                </div>
                <div className="file-meta">
                  <span>
                    LAST OPENED<b>{sample.lastOpened}</b>
                  </span>
                  <span className="file-tag">{sample.tag}</span>
                </div>
              </div>
            </motion.div>
          ) : (
            <motion.div
              className="demo-complete"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
            >
              <Check size={42} strokeWidth={1} />
              <h3>A little more clarity.</h3>
              <p>Four small decisions. A lighter folder.</p>
              <button className="text-button" onClick={reset}>
                <RotateCcw size={15} /> Try it again
              </button>
            </motion.div>
          )}
        </AnimatePresence>
        {shelf && (
          <div className="demo-overlay">
            <Folder size={28} />
            <h3>Give it a home.</h3>
            <p>Pick a sample destination.</p>
            <div className="destination-list">
              {["Projects", "Personal", "Inspiration"].map((folder) => (
                <button key={folder} onClick={() => decide("file", folder)}>
                  <Folder size={17} />
                  {folder}
                  <ArrowUpRight size={15} />
                </button>
              ))}
            </div>
            <button className="text-button" onClick={() => setShelf(false)}>
              Cancel
            </button>
          </div>
        )}
        {review && (
          <div className="demo-overlay">
            <ShieldCheck size={30} />
            <h3>You get the final say.</h3>
            <p>
              {staged} sample {staged === 1 ? "file is" : "files are"} staged.
              In DClutter, you review the list before anything moves to Trash.
            </p>
            <button
              className="button secondary"
              onClick={() => setReview(false)}
            >
              Back to the demo
            </button>
          </div>
        )}
      </div>
      <div className="demo-controls">
        <button
          disabled={!sample || shelf || review || transitioning}
          onClick={() => decide("stage")}
          className="stage-button"
        >
          <Trash2 size={17} />
          <span>Stage</span>
          <kbd>←</kbd>
        </button>
        <button
          disabled={!sample || shelf || review || transitioning}
          onClick={() => decide("skip")}
        >
          <SkipForward size={17} />
          <span>Skip</span>
          <kbd>␣</kbd>
        </button>
        <button
          disabled={!sample || review || transitioning}
          onClick={() => setShelf(!shelf)}
          aria-expanded={shelf}
        >
          <Folder size={17} />
          <span>File</span>
          <kbd>↑</kbd>
        </button>
        <button
          disabled={!sample || shelf || review || transitioning}
          onClick={() => decide("keep")}
        >
          <Check size={18} />
          <span>Keep</span>
          <kbd>→</kbd>
        </button>
      </div>
      <div className="demo-footer">
        <span>
          {queue.length} left <i>·</i> {sorted} sorted
        </span>
        <button
          onClick={() => {
            setShelf(false);
            setReview(true);
          }}
          disabled={!staged}
        >
          Review trash <span>{staged}</span>
        </button>
      </div>
      <span className="sr-only" role="status">
        {status}
      </span>
    </div>
  );
}

function PaceDemo() {
  const [speed, setSpeed] = useState(3);
  const [playing, setPlaying] = useState(false);
  const [count, setCount] = useState(0);
  const reduced = useReducedMotion();
  const container = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!playing) return;
    const timer = window.setInterval(
      () => setCount((value) => value + 1),
      1000 / speed,
    );
    return () => window.clearInterval(timer);
  }, [playing, speed]);
  useEffect(() => {
    const observer = new IntersectionObserver(([entry]) => {
      if (!entry.isIntersecting) setPlaying(false);
    });
    if (container.current) observer.observe(container.current);
    const pauseWhenHidden = () => {
      if (document.hidden) setPlaying(false);
    };
    document.addEventListener("visibilitychange", pauseWhenHidden);
    return () => {
      observer.disconnect();
      document.removeEventListener("visibilitychange", pauseWhenHidden);
    };
  }, []);
  return (
    <div className="pace-demo" ref={container}>
      <div className="pace-demo-top">
        <span className="eyebrow">YOUR RHYTHM</span>
        <span className="pill">NEW IN 1.1.0</span>
      </div>
      <div className="pace-visual">
        <div className="pace-number">
          <output htmlFor="pace-speed">{speed.toFixed(1)}</output>
          <span>files / second</span>
        </div>
        <div className="mini-stack" aria-hidden="true">
          <div />
          <div />
          <AnimatePresence mode="popLayout">
            <motion.div
              className="mini-file"
              key={count}
              initial={reduced ? false : { y: 18, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={
                reduced ? { opacity: 0 } : { x: 70, rotate: 12, opacity: 0 }
              }
              transition={{ duration: Math.min(0.22, 0.6 / speed) }}
            >
              <span />
              <span />
              <span />
              <Check size={20} />
            </motion.div>
          </AnimatePresence>
        </div>
      </div>
      <label htmlFor="pace-speed" className="sr-only">
        Held-arrow speed in files per second
      </label>
      <input
        id="pace-speed"
        type="range"
        min="0.5"
        max="8"
        step="0.5"
        value={speed}
        onChange={(event) => setSpeed(Number(event.target.value))}
        style={
          {
            "--range-progress": `${((speed - 0.5) / 7.5) * 100}%`,
          } as CSSProperties
        }
        aria-valuetext={`${speed} files per second`}
      />
      <div className="range-labels">
        <span>0.5 · Take your time</span>
        <span>8 · Find your flow</span>
      </div>
      <div className="pace-bottom">
        <button
          className="text-button"
          onClick={() => setPlaying(!playing)}
          aria-pressed={playing}
        >
          {playing ? <Pause size={15} /> : <Play size={15} />}
          {playing ? "Pause preview" : "Try this pace"}
        </button>
        <span>
          {playing
            ? "Sample cards in motion"
            : "Drag the slider. Feel the difference."}
        </span>
      </div>
    </div>
  );
}

const faqs = [
  {
    q: "Is it really free?",
    a: (
      <>
        Yes. DClutter is free and open source under the Apache 2.0 license. No
        account, subscription, or in-app purchase. You can explore the code on{" "}
        <a href={REPO}>GitHub</a>.
      </>
    ),
  },
  {
    q: "Does it delete anything automatically?",
    a: (
      <>
        No. Stage marks a file for trash without changing it on disk. When
        you’re ready, open Review trash, check the list, and confirm. Files go
        to macOS Trash. Filing into a destination folder happens immediately and
        can be undone.
      </>
    ),
  },
  {
    q: "Can I use it outside my Downloads folder?",
    a: (
      <>
        Yes. Downloads is the starting point. Use the folder menu to choose
        another source folder. DClutter remembers a separate session for each
        folder and only accesses the folders you allow.
      </>
    ),
  },
  {
    q: "Which Macs does it work on?",
    a: (
      <>
        DClutter runs on macOS 14 Sonoma or later, on both Apple Silicon and
        Intel Macs. It’s a native app built with SwiftUI.
      </>
    ),
  },
  {
    q: "Why does macOS ask me to approve it?",
    a: (
      <>
        The current release isn’t Apple Developer signed or notarized. After
        trying to open it, go to System Settings → Privacy &amp; Security → Open
        Anyway, then confirm Open. This is a one-time step. The source is public
        if you prefer to build it yourself.
      </>
    ),
  },
];

export default function Landing() {
  return (
    <MotionConfig reducedMotion="user">
      <a className="skip-link" href="#main">
        Skip to content
      </a>
      <header className="site-header">
        <a className="wordmark" href="#" aria-label="DClutter home">
          <img src="/logo.png" alt="" width="32" height="32" />
          DClutter
        </a>
        <nav aria-label="Main navigation">
          <a href="#how-it-works">How it works</a>
          <a href="#details">The details</a>
          <a href={REPO} className="github-nav">
            GitHub <ArrowUpRight size={13} />
          </a>
        </nav>
        <a className="nav-download" href="#download">
          Get DClutter <ArrowDownToLine size={15} />
        </a>
      </header>
      <main id="main">
        <section className="hero section-wrap">
          <div className="hero-copy">
            <a className="release-link" href={release}>
              <span className="release-dot" />
              MEET DCLUTTER 1.1.0 <span className="release-divider" /> A little
              more you. <ArrowUpRight size={13} />
            </a>
            <h1>
              Less clutter.
              <br />
              <span>More clarity.</span>
            </h1>
            <p className="hero-description">
              That folder full of “I’ll sort it later”?
              <br />
              Let’s make later a little easier.
            </p>
            <p className="hero-explanation">
              Preview your files. Keep, trash, or give them a home.
              <br className="desktop-break" /> One decision at a time, right on
              your Mac.
            </p>
            <div className="hero-actions">
              <DownloadLink />
              <a className="text-link" href="#how-it-works">
                See how it feels <ArrowDown size={15} />
              </a>
            </div>
            <div className="download-meta">
              Free &amp; open source <span>·</span> macOS 14+ <span>·</span>{" "}
              Apple Silicon &amp; Intel
            </div>
            <a className="install-note" href="#installation">
              First time? A quick macOS setup note <ArrowUpRight size={12} />
            </a>
          </div>
          <div className="hero-product">
            <div className="product-label">
              <span className="small-rule" /> A LITTLE ORDER IN THE EVERYDAY{" "}
              <span>TRY IT BELOW</span>
            </div>
            <FileDemo />
            <div className="demo-caption">
              <span className="caption-dot" /> REAL FEEL. SAMPLE FILES.
              <span>Click a decision. Find your flow.</span>
            </div>
          </div>
          <div className="hero-bottom">
            <span>LESS FILE MANAGEMENT. MORE MOVING ON.</span>
            <a href="#how-it-works" aria-label="Explore how DClutter works">
              <ArrowDown size={19} />
            </a>
            <span>MADE FOR YOUR MAC.</span>
          </div>
        </section>
        <section className="workflow section-wrap" id="how-it-works">
          <Reveal className="section-heading">
            <span className="eyebrow">01 — THE SMALL DECISIONS</span>
            <h2>
              A place for every file.
              <br />
              <span>A little space for you.</span>
            </h2>
            <p>
              The screenshot. The old assignment. That third copy of a PDF.
              <br className="desktop-break" /> See what it is, decide where it
              belongs, and move on.
            </p>
          </Reveal>
          <div className="decision-grid">
            {[
              {
                icon: <Check />,
                key: "→",
                name: "Keep what matters.",
                text: "Leave the good stuff right where it is. You’re already on to the next file.",
                className: "keep",
              },
              {
                icon: <Trash2 />,
                key: "←",
                name: "Let the rest go.",
                text: "Stage files for trash, then review the list. Nothing leaves until you say so.",
                className: "trash",
              },
              {
                icon: <Folder />,
                key: "↑",
                name: "Give it a home.",
                text: "Choose a destination and file it away. Every move comes with an undo.",
                className: "file",
              },
            ].map((item, index) => (
              <Reveal
                className={`decision-item ${item.className}`}
                key={item.name}
                delay={index * 0.08}
              >
                <div className="decision-symbol">
                  {item.icon}
                  <kbd>{item.key}</kbd>
                </div>
                <span className="item-number">0{index + 1}</span>
                <h3>{item.name}</h3>
                <p>{item.text}</p>
              </Reveal>
            ))}
          </div>
          <div className="skip-aside">
            <SkipForward size={17} />
            <span>
              Not sure yet? <b>Skip it.</b> It’ll come back around.
            </span>
            <kbd>space</kbd>
          </div>
        </section>
        <section className="product-section" id="details">
          <div className="product-layout section-wrap">
            <div className="product-story">
              <span className="eyebrow">02 — THE BIGGER PICTURE</span>
              <h2>
                A proper look.
                <br />
                <span>
                  Then a simple
                  <br />
                  decision.
                </span>
              </h2>
              <p>
                No guessing from a filename. A real preview and the right
                context put the next move in perspective.
              </p>
              <div className="detail-list">
                <div>
                  <span>01</span>
                  <section>
                    <h3>See before you sort.</h3>
                    <p>
                      Preview the file, or open it in its usual app when you
                      want a closer look.
                    </p>
                  </section>
                </div>
                <div>
                  <span>02</span>
                  <section>
                    <h3>A little context goes a long way.</h3>
                    <p>
                      Size, last opened, download source, and useful hints about
                      copies and extracted archives.
                    </p>
                  </section>
                </div>
                <div>
                  <span>03</span>
                  <section>
                    <h3>Pick up where you left off.</h3>
                    <p>
                      Your decisions are saved as you go. Come back when you’re
                      ready.
                    </p>
                  </section>
                </div>
              </div>
            </div>
            <Reveal className="native-app">
              <div className="native-titlebar">
                <span className="window-dots" aria-hidden="true">
                  <i />
                  <i />
                  <i />
                </span>
                <span>DClutter</span>
                <span />
              </div>
              <img
                src="/triage-layout.png"
                alt="DClutter on macOS, showing a file preview, metadata, and Stage, Skip, File, and Keep controls"
                width="1432"
                height="1760"
                loading="lazy"
              />
              <div className="native-caption">
                THE ACTUAL APP. NO EXTRA NOISE.
              </div>
            </Reveal>
          </div>
        </section>
        <section className="pace-section section-wrap">
          <Reveal className="pace-copy">
            <span className="eyebrow">03 — MADE TO FEEL LIKE YOU</span>
            <h2>
              A tap. A swipe.
              <br />
              <span>Your kind of flow.</span>
            </h2>
            <p>
              Keyboard person? Trackpad person? Both feel at home. Hold an arrow
              to work through a pile, with the speed set just right for you.
            </p>
            <div className="key-combo">
              <kbd>←</kbd>
              <kbd>→</kbd>
              <span>
                Hold to keep going.
                <br />
                Release to take a closer look.
              </span>
            </div>
            <a href={release} className="text-link">
              What’s new in 1.1.0 <ArrowUpRight size={15} />
            </a>
          </Reveal>
          <PaceDemo />
        </section>
        <section className="reassurance section-wrap">
          <div>
            <LockKeyhole size={24} strokeWidth={1.4} />
            <h3>Your files stay yours.</h3>
            <p>On your Mac. No uploads, accounts, or telemetry.</p>
          </div>
          <div>
            <Undo2 size={24} strokeWidth={1.4} />
            <h3>Room to change your mind.</h3>
            <p>Undo a move. Review your trash. Stay in control.</p>
          </div>
          <div>
            <Code2 size={24} strokeWidth={1.4} />
            <h3>Open from the start.</h3>
            <p>Free to use. Open source. Built for the everyday.</p>
          </div>
        </section>
        <section className="download-section" id="download">
          <div className="section-wrap download-inner">
            <img src="/logo.png" alt="" width="72" height="72" loading="lazy" />
            <span className="eyebrow">YOUR DOWNLOADS FOLDER CALLED.</span>
            <h2>
              A fresh start.
              <br />
              <span>For your files.</span>
            </h2>
            <p>For the files you need. And the things you’d rather be doing.</p>
            <DownloadLink>Get DClutter for free</DownloadLink>
            <div className="download-meta">
              VERSION 1.1.0 <span>·</span> macOS 14+ <span>·</span> APPLE
              SILICON &amp; INTEL
            </div>
            <div className="installation" id="installation">
              <ShieldCheck size={20} />
              <div>
                <h3>A small note before your first launch.</h3>
                <p>
                  DClutter isn’t Apple-notarized yet. Unzip the download, move
                  it to Applications, and try opening it. Then go to{" "}
                  <strong>
                    System Settings → Privacy &amp; Security → Open Anyway.
                  </strong>{" "}
                  You only need to do this once.
                </p>
                <a href={`${REPO}#install`} className="text-link">
                  Read the installation guide <ArrowUpRight size={13} />
                </a>
              </div>
            </div>
          </div>
        </section>
        <section className="faq-section section-wrap">
          <div>
            <span className="eyebrow">A FEW GOOD QUESTIONS</span>
            <h2>
              Before you
              <br />
              <span>dive in.</span>
            </h2>
          </div>
          <div className="faq-list">
            {faqs.map((faq) => (
              <details key={faq.q}>
                <summary>
                  {faq.q}
                  <ChevronDown size={18} />
                </summary>
                <div>{faq.a}</div>
              </details>
            ))}
          </div>
        </section>
      </main>
      <footer className="site-footer section-wrap">
        <div className="footer-top">
          <a href="#" className="wordmark">
            <img src="/logo.png" alt="" width="27" height="27" />
            DClutter
          </a>
          <span>A little less clutter. A little more clarity.</span>
          <a href={REPO}>
            <Code2 size={17} /> Find us on GitHub <ArrowUpRight size={14} />
          </a>
        </div>
        <div className="footer-bottom">
          <span>Made by Dexter Jethro Enriquez.</span>
          <div>
            <a href={release}>Release notes</a>
            <a href={`${REPO}/issues`}>Feedback</a>
            <a href={`${REPO}/blob/main/LICENSE`}>Apache 2.0</a>
          </div>
          <span>ONE FILE AT A TIME.</span>
        </div>
      </footer>
    </MotionConfig>
  );
}
