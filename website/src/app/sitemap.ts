import type { MetadataRoute } from "next";
import { SITE_URL } from "@/lib/site";

export const dynamic = "force-static";

export default function sitemap(): MetadataRoute.Sitemap {
  return ["/", "/help", "/privacy", "/license"].map((path) => ({
    url: new URL(path, SITE_URL).toString(),
  }));
}
