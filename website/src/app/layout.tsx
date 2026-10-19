import type { Metadata } from "next";
import { Merriweather, Poppins } from "next/font/google";
import { AUTHOR, pageMetadata, SITE_DESCRIPTION, SITE_TITLE, SITE_URL } from "@/lib/site";
import "./globals.css";

const poppins = Poppins({
  subsets: ["latin"],
  weight: ["400", "500", "600", "700"],
  display: "swap",
  variable: "--font-poppins",
});

const merriweather = Merriweather({
  subsets: ["latin"],
  weight: "400",
  style: ["normal", "italic"],
  display: "swap",
  variable: "--font-serif",
});

export const metadata: Metadata = {
  ...pageMetadata(SITE_TITLE, SITE_DESCRIPTION, "/", "DClutter: Meet your files. Again."),
  metadataBase: new URL(SITE_URL),
  applicationName: "DClutter",
  authors: [AUTHOR],
  creator: AUTHOR.name,
  category: "utilities",
  icons: { icon: "/logo.png", apple: "/logo.png" },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
  },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en" className={`${poppins.variable} ${merriweather.variable}`}>
      <body>{children}</body>
    </html>
  );
}
