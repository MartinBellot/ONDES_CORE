"use client";

import Link from "next/link";
import { Github } from "lucide-react";

const footerLinks = [
  {
    title: "Resources",
    links: [
      { label: "Documentation", href: "https://martinbellot.github.io/ONDES_CORE/" },
      { label: "Mini-App Guide", href: "https://martinbellot.github.io/ONDES_CORE/mini_app_guide/" },
      { label: "SDK Reference", href: "https://martinbellot.github.io/ONDES_CORE/sdk/" },
      { label: "Examples", href: "https://martinbellot.github.io/ONDES_CORE/examples/" },
    ],
  },
  {
    title: "Ecosystem",
    links: [
      { label: "Architecture", href: "https://martinbellot.github.io/ONDES_CORE/architecture/" },
      { label: "Ondes Lab", href: "https://martinbellot.github.io/ONDES_CORE/lab/" },
      { label: "Backend API", href: "https://martinbellot.github.io/ONDES_CORE/backend/" },
    ],
  },
  {
    title: "Community",
    links: [
      { label: "GitHub", href: "https://github.com/MartinBellot/ONDES_CORE" },
    ],
  },
];

export function Footer() {
  return (
    <footer className="relative border-t border-white/[0.06]">
      <div className="mx-auto max-w-6xl px-6 py-16">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
          {/* Brand */}
          <div className="col-span-2 md:col-span-1">
            <Link href="/" className="flex items-center gap-2 mb-4">
              <div className="relative h-7 w-7 rounded-lg bg-gradient-to-br from-[#7c3aed] to-[#06b6d4] flex items-center justify-center">
                <span className="text-white text-[10px] font-bold">O</span>
              </div>
              <span className="text-white font-semibold tracking-tight">
                ONDES<span className="text-white/40">_</span>
                <span className="text-white/60">CORE</span>
              </span>
            </Link>
            <p className="text-xs text-white/30 leading-relaxed max-w-[200px]">
              Empowering the next generation of modular apps.
            </p>
            <Link
              href="https://github.com/MartinBellot/ONDES_CORE"
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-1.5 mt-4 text-xs text-white/30 hover:text-white/60 transition-colors"
            >
              <Github className="h-3.5 w-3.5" />
              MartinBellot/ONDES_CORE
            </Link>
          </div>

          {/* Link columns */}
          {footerLinks.map((group) => (
            <div key={group.title}>
              <h4 className="text-xs font-medium text-white/50 uppercase tracking-wider mb-4">
                {group.title}
              </h4>
              <ul className="space-y-2.5">
                {group.links.map((link) => (
                  <li key={link.label}>
                    <Link
                      href={link.href}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-xs text-white/30 hover:text-white/60 transition-colors"
                    >
                      {link.label}
                    </Link>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        {/* Bottom bar */}
        <div className="mt-12 pt-6 border-t border-white/[0.04] flex flex-col sm:flex-row items-center justify-between gap-4">
          <p className="text-[11px] text-white/20">
            &copy; {new Date().getFullYear()} ONDES_CORE. Open source under MIT.
          </p>
        </div>
      </div>
    </footer>
  );
}
