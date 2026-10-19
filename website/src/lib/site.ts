import type { Metadata } from "next";

export const SITE_URL = "https://dclutter.djenriquez.dev";
export const SITE_NAME = "DClutter";
export const SITE_TITLE = "DClutter — Offline File Organizer for Mac & Windows";
export const SITE_DESCRIPTION = "DClutter is a free, open-source file organizer for Mac and Windows. Review Downloads one file at a time, keep what matters, and clear clutter offline.";
export const AUTHOR = { name: "Dexter Jethro Enriquez", url: "https://www.djenriquez.dev/" };
export const SHARE_IMAGE = {
  url: `${SITE_URL}/og/dclutter.png`,
  width: 1200,
  height: 630,
  type: "image/png",
  alt: "DClutter — Meet your files. Again. Rediscover what’s worth keeping. Clear out what isn’t. For Mac and Windows.",
};

export function pageMetadata(title: string, description: string, path: string, socialTitle = title): Metadata {
  const url = new URL(path, SITE_URL).toString();
  return {
    title,
    description,
    alternates: { canonical: url },
    openGraph: {
      type: "website",
      locale: "en_US",
      siteName: SITE_NAME,
      title: socialTitle,
      description,
      url,
      images: [SHARE_IMAGE],
    },
    twitter: {
      card: "summary_large_image",
      title: socialTitle,
      description,
      images: [{ url: SHARE_IMAGE.url, alt: SHARE_IMAGE.alt }],
    },
  };
}
