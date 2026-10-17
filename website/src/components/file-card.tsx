import type { SampleFile } from "@/lib/samples";

function Preview({ kind }: { kind: SampleFile["preview"] }) {
  if (kind === "notes") {
    return (
      <div className="fcard-paper">
        Semester planning notes
        <br />
        <br />
        01&nbsp;&nbsp;Review the project brief
        <br />
        02&nbsp;&nbsp;Organise research and references
        <br />
        03&nbsp;&nbsp;Prepare the first design review
        <br />
        <br />
        A little less clutter. A little more clarity.
      </div>
    );
  }

  if (kind === "poster") {
    return (
      <div
        className="fcard-paper"
        style={{
          display: "grid",
          placeItems: "center",
          background:
            "linear-gradient(145deg, var(--sand) 0%, var(--blush) 55%, var(--sky) 100%)",
        }}
      >
        <span
          style={{
            fontFamily: "var(--serif)",
            fontSize: "clamp(18px, 3vw, 30px)",
            lineHeight: 1.1,
            textAlign: "center",
            color: "var(--ink)",
          }}
        >
          A little
          <br />
          more clarity
        </span>
      </div>
    );
  }

  if (kind === "sheet") {
    return (
      <div className="fcard-paper" style={{ paddingTop: 14 }}>
        title,author,status
        <br />
        Design of Everyday Things,Norman,read
        <br />
        Thinking in Systems,Meadows,reading
        <br />
        The Timeless Way,Alexander,queued
        <br />
        Shape Up,Singer,queued
      </div>
    );
  }

  return <span className="fcard-glyph">ZIP · 48 ITEMS</span>;
}

export default function FileCard({ file }: { file: SampleFile }) {
  return (
    <div className="fcard">
      <div className="fcard-preview">
        <Preview kind={file.preview} />
      </div>
      <div className="fcard-name">{file.name}</div>
      <div className="fcard-type">{file.type}</div>
      <div className="fcard-meta">
        <div>
          <span>SIZE</span>
          <b>{file.size}</b>
        </div>
        <div>
          <span>LAST OPENED</span>
          <b>{file.lastOpened}</b>
        </div>
        <div>
          <span>FROM</span>
          <b>{file.from}</b>
        </div>
        <div>
          <span>ADDED</span>
          <b>{file.added}</b>
        </div>
      </div>
    </div>
  );
}
