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
  title: "ONDES_CORE — Une app, des milliers de services",
  description:
    "Créez un écosystème d'applications légères qui partagent le même réseau social, la même identité, et les mêmes fonctionnalités du téléphone.",
  keywords: [
    "super app",
    "mini apps",
    "flutter",
    "plateforme",
    "écosystème",
    "applications modulaires",
    "réseau social",
  ],
  openGraph: {
    title: "ONDES_CORE — Une app, des milliers de services",
    description:
      "Créez un écosystème d'applications légères qui partagent le même réseau social, la même identité, et les mêmes fonctionnalités du téléphone.",
    type: "website",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="fr" className="dark">
      <body
        className={`${inter.variable} ${jetbrainsMono.variable} antialiased noise`}
      >
        {children}
      </body>
    </html>
  );
}
