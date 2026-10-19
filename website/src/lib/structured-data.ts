import { MAC_REPO, releases, WIN_REPO } from "./platforms";
import { AUTHOR, SHARE_IMAGE, SITE_DESCRIPTION, SITE_NAME, SITE_URL } from "./site";

export const structuredData = {
  "@context": "https://schema.org",
  "@graph": [
    {
      "@type": "WebSite",
      "@id": `${SITE_URL}/#website`,
      url: SITE_URL,
      name: SITE_NAME,
      description: SITE_DESCRIPTION,
      inLanguage: "en",
      publisher: { "@id": `${AUTHOR.url}#person` },
      about: { "@id": `${SITE_URL}/#app` },
    },
    {
      "@type": "SoftwareApplication",
      "@id": `${SITE_URL}/#app`,
      name: SITE_NAME,
      url: SITE_URL,
      description: SITE_DESCRIPTION,
      applicationCategory: "UtilitiesApplication",
      operatingSystem: releases.filter((release) => release.status === "available").map((release) => release.requirements),
      isAccessibleForFree: true,
      offers: { "@type": "Offer", price: 0, priceCurrency: "USD", url: `${SITE_URL}/#download` },
      license: `${SITE_URL}/license`,
      image: SHARE_IMAGE.url,
      author: { "@id": `${AUTHOR.url}#person` },
      sameAs: [MAC_REPO, WIN_REPO],
    },
    {
      "@type": "Person",
      "@id": `${AUTHOR.url}#person`,
      name: AUTHOR.name,
      url: AUTHOR.url,
    },
  ],
};
