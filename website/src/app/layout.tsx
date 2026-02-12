import type { Metadata } from "next";
import { Inter, JetBrains_Mono } from "next/font/google";
import "./globals.css";

const inter = Inter({
  variable: "--font-inter",
  subsets: ["latin"],
  display: "swap",
});

const jetbrainsMono = JetBrains_Mono({
  variable: "--font-jetbrains-mono",
  subsets: ["latin"],
  display: "swap",
});

export const metadata: Metadata = {
  title: "ONDES_CORE — The Protocol for Interconnected Super Apps",
  description:
    "Orchestrate a mesh of native-capable mini-apps. One Host, infinite Guests, seamless communication via the ONDES Bridge.",
  keywords: [
    "super app",
    "mini apps",
    "flutter",
    "webview",
    "bridge",
    "native",
    "ecosystem",
  ],
  openGraph: {
    title: "ONDES_CORE — The Protocol for Interconnected Super Apps",
    description:
      "Orchestrate a mesh of native-capable mini-apps. One Host, infinite Guests, seamless communication via the ONDES Bridge.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${inter.variable} ${jetbrainsMono.variable} antialiased noise`}
      >
        {children}
      </body>
    </html>
  );
}
