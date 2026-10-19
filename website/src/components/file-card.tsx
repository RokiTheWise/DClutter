import type { SampleFile } from "@/lib/samples";
import type { ReactNode } from "react";
import { OpenIcon } from "./icons";

function Preview({ kind }: { kind: SampleFile["preview"] }) {
  if (kind === "notes") {
    return (
      <div className="fcard-paper">
        Semester planning notes
        <br />
        <br />
        01&nbsp;&nbsp;Review the project brief
        <br />
        02&nbsp;&nbsp;Organize research and references
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

  return (
    <svg className="fcard-doc" viewBox="0 0 120 150" aria-hidden="true">
      <path
        d="M12 8h64l32 32v102a8 8 0 0 1-8 8H12a8 8 0 0 1-8-8V16a8 8 0 0 1 8-8Z"
        fill="#eceaea"
      />
      <path d="M76 8l32 32H84a8 8 0 0 1-8-8V8Z" fill="#cfcccc" />
      <rect x="54" y="26" width="12" height="20" rx="4" fill="#b6b3b3" />
      <g fill="#b6b3b3">
        <rect x="55" y="52" width="10" height="7" rx="2" />
        <rect x="55" y="63" width="10" height="7" rx="2" />
        <rect x="55" y="74" width="10" height="7" rx="2" />
        <rect x="55" y="85" width="10" height="7" rx="2" />
      </g>
      <text
        x="60"
        y="128"
        textAnchor="middle"
        fontSize="17"
        fontWeight="500"
        fill="#9b9898"
        fontFamily="var(--sans)"
      >
        ZIP
      </text>
    </svg>
  );
}

export default function FileCard({ file, preview }: { file: SampleFile; preview?: ReactNode }) {
  return (
    <div className="fcard">
      <div className="fcard-preview">
        {preview ?? <Preview kind={file.preview} />}
      </div>
      <div className="fcard-head">
        <div>
          <div className="fcard-name">{file.name}</div>
          <div className="fcard-tags">
            <span className="fcard-type">{file.type}</span>
            {file.chips.map((chip) => (
              <span className="fcard-chip" key={chip}>
                {chip}
              </span>
            ))}
          </div>
        </div>
        <span className="fcard-open" aria-hidden="true">
          <OpenIcon />
          Open
        </span>
      </div>
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
