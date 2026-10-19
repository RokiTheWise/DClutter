import type { Metadata } from "next";
import { readFile } from "node:fs/promises";
import { join } from "node:path";
import SiteNav from "@/components/site-nav";

export const metadata: Metadata = {
  title: "License · DClutter",
  description: "The full Apache License 2.0 for DClutter.",
};

export default async function License() {
  const license = await readFile(join(process.cwd(), "public/license.txt"), "utf8");
  const paragraphs = license.trim().split(/\n\s*\n/).map((text) => text.trim().replace(/\s*\n\s*/g, " "));

  return (
    <>
      <SiteNav />
      <main id="main" className="doc">
        <div className="wrap">
          <h1 className="display">License</h1>
          <p className="lede doc-lede">DClutter is licensed under the Apache License, Version 2.0.</p>
          <p><a href="/license.txt">Read as plain text</a></p>
          <div className="license-text">
            {paragraphs.map((text, index) => <p key={index}>{text}</p>)}
          </div>
          <p className="doc-back"><a href="/#download">Back to DClutter</a></p>
        </div>
      </main>
    </>
  );
}
