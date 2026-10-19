const assert = require("node:assert/strict");
const { readFileSync } = require("node:fs");
const { join } = require("node:path");

const out = join(__dirname, "../out");
const origin = "https://dclutter.djenriquez.dev";
const image = `${origin}/og/dclutter.png`;
const read = (file) => readFileSync(join(out, file), "utf8");
const attributes = (tag) => Object.fromEntries([...tag.matchAll(/([\w:-]+)="([^"]*)"/g)].map(([, key, value]) => [key, value]));
const meta = (html) => Object.fromEntries([...html.matchAll(/<meta\b[^>]*>/g)].map(([tag]) => {
  const values = attributes(tag);
  return [values.property || values.name, values.content];
}));

for (const [path, file] of [["/", "index.html"], ["/help", "help.html"], ["/privacy", "privacy.html"], ["/license", "license.html"]]) {
  const html = read(file);
  const tags = meta(html);
  const canonical = [...html.matchAll(/<link\b[^>]*>/g)].map(([tag]) => attributes(tag)).filter((tag) => tag.rel === "canonical");
  assert.equal(canonical.length, 1, `${path}: one canonical URL`);
  assert.equal(new URL(canonical[0].href).href, new URL(path, origin).href, `${path}: correct canonical`);
  assert.ok(tags.description?.length > 50, `${path}: descriptive summary`);
  assert.ok(!tags.robots.includes("noindex"), `${path}: indexable`);
  assert.equal(new URL(tags["og:url"]).href, new URL(canonical[0].href).href, `${path}: Open Graph URL`);
  assert.equal(tags["og:image"], image, `${path}: absolute sharing image`);
  assert.equal(tags["og:image:width"], "1200");
  assert.equal(tags["og:image:height"], "630");
  assert.equal(tags["og:image:type"], "image/png");
  assert.ok(tags["og:image:alt"]?.includes("DClutter"));
  assert.equal(tags["twitter:card"], "summary_large_image");
  assert.equal(tags["twitter:image"], image);
  assert.equal((html.match(/<h1\b/g) || []).length, 1, `${path}: one main heading`);
}
console.log("PASS: canonical URLs, descriptions, indexing, and social metadata on every page");

const png = readFileSync(join(out, "og/dclutter.png"));
assert.equal(png.subarray(1, 4).toString(), "PNG");
assert.equal(png.readUInt32BE(16), 1200);
assert.equal(png.readUInt32BE(20), 630);
assert.ok(png.length < 1_000_000);
console.log("PASS: exported sharing image is a lightweight 1200×630 PNG");

const home = read("index.html");
const scripts = [...home.matchAll(/<script\b[^>]*type="application\/ld\+json"[^>]*>([\s\S]*?)<\/script>/g)].map(([, json]) => JSON.parse(json));
assert.equal(scripts.length, 1);
const graph = scripts[0]["@graph"];
assert.ok(graph.find((item) => item["@type"] === "WebSite"));
const app = graph.find((item) => item["@type"] === "SoftwareApplication");
assert.equal(app.name, "DClutter");
assert.equal(app.offers.price, 0);
assert.ok(!app.aggregateRating && !app.review, "No invented ratings");
assert.equal(app.license, `${origin}/license`);
assert.ok(read("help.html").includes("Does DClutter work offline?"));
assert.ok(read("help.html").includes("Does it delete files automatically?"));
console.log("PASS: product entity data and readable help are present in initial HTML");

const robots = read("robots.txt");
assert.ok(robots.includes("User-Agent: *") && robots.includes("Allow: /"));
assert.ok(robots.includes(`Sitemap: ${origin}/sitemap.xml`));
const sitemap = read("sitemap.xml");
for (const path of ["/", "/help", "/privacy", "/license"]) assert.ok(sitemap.includes(`<loc>${new URL(path, origin).href}</loc>`));
assert.ok(!sitemap.includes("vercel.app") && !sitemap.includes("localhost"));
console.log("PASS: crawler access and sitemap use the production host");
