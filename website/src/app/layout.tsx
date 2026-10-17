import type { Metadata } from "next";
import localFont from "next/font/local";
import "./globals.css";

const inter = localFont({
  src: "../../public/fonts/InterVariable.woff2",
  display: "swap",
  variable: "--font-inter",
});

export const metadata: Metadata = {
  title: "DClutter — Less clutter. More clarity.",
  description:
    "A little less clutter. A little more clarity. Meet the free, open-source Mac app that helps you sort your files, one decision at a time.",
  icons: { icon: "/logo.png", apple: "/logo.png" },
  openGraph: {
    title: "DClutter — Less clutter. More clarity.",
    description: "Sort your files, one decision at a time. Free for macOS 14+.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body className={inter.variable}>{children}</body>
    </html>
  );
}
