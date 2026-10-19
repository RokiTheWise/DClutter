import type { Metadata } from "next";
import { Merriweather, Poppins } from "next/font/google";
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
  title: "DClutter: Meet your files. Again.",
  description:
    "Rediscover what’s worth keeping. Clear out what isn’t",
  icons: { icon: "/logo.png", apple: "/logo.png" },
  openGraph: {
    title: "DClutter: Meet your files. Again.",
    description:
      "Rediscover what’s worth keeping. Clear out what isn’t",
    type: "website",
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
