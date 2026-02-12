"use client";

import { Check, X, Zap } from "lucide-react";
import { FadeIn } from "./fade-in";

interface CompRow {
  feature: string;
  capacitor: string | boolean;
  flutter: string | boolean;
  pwa: string | boolean;
  ondes: string | boolean;
}

const rows: CompRow[] = [
  {
    feature: "Distribution",
    capacitor: "App Stores",
    flutter: "App Stores",
    pwa: "Web URL",
    ondes: "Internal Store",
  },
  {
    feature: "Update Speed",
    capacitor: "Slow (validation)",
    flutter: "Slow (validation)",
    pwa: "Instant",
    ondes: "Instant & Hot",
  },
  {
    feature: "App Isolation",
    capacitor: false,
    flutter: false,
    pwa: true,
    ondes: true,
  },
  {
    feature: "Social Graph",
    capacitor: false,
    flutter: false,
    pwa: false,
    ondes: true,
  },
  {
    feature: "Native Bridge",
    capacitor: true,
    flutter: true,
    pwa: false,
    ondes: true,
  },
  {
    feature: "E2EE Chat",
    capacitor: false,
    flutter: false,
    pwa: false,
    ondes: true,
  },
  {
    feature: "Multi-App Ecosystem",
    capacitor: false,
    flutter: false,
    pwa: false,
    ondes: true,
  },
];

function CellValue({ value }: { value: string | boolean }) {
  if (typeof value === "boolean") {
    return value ? (
      <Check className="h-4 w-4 text-[#34d399]" />
    ) : (
      <X className="h-4 w-4 text-white/15" />
    );
  }
  return <span className="text-xs">{value}</span>;
}

export function ComparisonSection() {
  return (
    <section className="relative py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-6">
        <FadeIn>
          <div className="text-center mb-12">
            <span className="inline-block text-xs font-mono text-[#7c3aed] tracking-widest uppercase mb-4">
              Comparison
            </span>
            <h2 className="text-3xl sm:text-4xl font-bold tracking-tight">
              Why <span className="gradient-text">ONDES_CORE</span>?
            </h2>
            <p className="mt-4 text-white/40 max-w-xl mx-auto">
              Not just an alternative — a paradigm shift. You don&apos;t build an App,
              you build an Ecosystem.
            </p>
          </div>
        </FadeIn>

        <FadeIn delay={0.15}>
          <div className="rounded-xl border border-white/[0.06] bg-white/[0.02] overflow-hidden">
            <div className="overflow-x-auto">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-white/[0.06]">
                    <th className="text-left px-5 py-4 text-xs font-medium text-white/30 uppercase tracking-wider">
                      Feature
                    </th>
                    <th className="text-center px-4 py-4 text-xs font-medium text-white/20">
                      Capacitor
                    </th>
                    <th className="text-center px-4 py-4 text-xs font-medium text-white/20">
                      Flutter
                    </th>
                    <th className="text-center px-4 py-4 text-xs font-medium text-white/20">
                      PWA
                    </th>
                    <th className="text-center px-4 py-4">
                      <span className="inline-flex items-center gap-1.5 text-xs font-semibold text-[#7c3aed]">
                        <Zap className="h-3.5 w-3.5" />
                        ONDES
                      </span>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((row, i) => (
                    <tr
                      key={row.feature}
                      className={`${
                        i < rows.length - 1 ? "border-b border-white/[0.04]" : ""
                      } hover:bg-white/[0.02] transition-colors`}
                    >
                      <td className="px-5 py-3.5 text-xs text-white/50 font-medium">
                        {row.feature}
                      </td>
                      <td className="text-center px-4 py-3.5 text-white/30">
                        <div className="flex justify-center">
                          <CellValue value={row.capacitor} />
                        </div>
                      </td>
                      <td className="text-center px-4 py-3.5 text-white/30">
                        <div className="flex justify-center">
                          <CellValue value={row.flutter} />
                        </div>
                      </td>
                      <td className="text-center px-4 py-3.5 text-white/30">
                        <div className="flex justify-center">
                          <CellValue value={row.pwa} />
                        </div>
                      </td>
                      <td className="text-center px-4 py-3.5 text-white/80 font-medium">
                        <div className="flex justify-center">
                          <CellValue value={row.ondes} />
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </FadeIn>

        {/* Bottom reasons */}
        <FadeIn delay={0.3}>
          <div className="mt-12 grid grid-cols-1 sm:grid-cols-3 gap-4">
            {[
              {
                emoji: "🤝",
                title: "Network Effect",
                desc: "Mini-apps are born connected to the Social Graph. Identity, friends, and feed come for free.",
              },
              {
                emoji: "🧩",
                title: "Decentralized Dev",
                desc: "Multiple teams build independent mini-apps. The Shell stays untouched — true modularity.",
              },
              {
                emoji: "⚡",
                title: "Zero Time-to-Market",
                desc: "No native compilation, no store validation. Upload a .zip and it's live on every device.",
              },
            ].map((reason) => (
              <div
                key={reason.title}
                className="rounded-xl border border-white/[0.06] bg-white/[0.02] p-5 text-center"
              >
                <span className="text-2xl">{reason.emoji}</span>
                <h4 className="text-sm font-semibold mt-3 mb-1">
                  {reason.title}
                </h4>
                <p className="text-xs text-white/35 leading-relaxed">
                  {reason.desc}
                </p>
              </div>
            ))}
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
