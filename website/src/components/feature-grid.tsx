"use client";

import {
  ArrowLeftRight,
  Users,
  Layers,
  Rocket,
  MessageCircle,
  Wifi,
  Shield,
  Zap,
} from "lucide-react";
import { FadeIn } from "./fade-in";
import { CodeWindow } from "./code-window";

const sdkModules = [
  { icon: Layers, label: "Interface (UI)", desc: "Toasts, Modals, Navigation" },
  { icon: Users, label: "Social Graph", desc: "Feed, Posts, Stories" },
  { icon: MessageCircle, label: "E2EE Chat", desc: "X25519 + AES-256-GCM" },
  { icon: Wifi, label: "WebSocket", desc: "Real-time connections" },
  { icon: Shield, label: "Permissions", desc: "Manifest-based sandbox" },
  { icon: Zap, label: "Device APIs", desc: "Camera, GPS, Haptics" },
];

export function FeatureGrid() {
  return (
    <section id="architecture" className="relative py-24 sm:py-32">
      <div className="mx-auto max-w-6xl px-6">
        {/* Section header */}
        <FadeIn>
          <div className="text-center mb-16">
            <span className="inline-block text-xs font-mono text-[#7c3aed] tracking-widest uppercase mb-4">
              Architecture
            </span>
            <h2 className="text-3xl sm:text-4xl font-bold tracking-tight">
              Built for <span className="gradient-text">Interconnection</span>
            </h2>
            <p className="mt-4 text-white/40 max-w-xl mx-auto">
              A modular architecture where every layer communicates seamlessly
              through the ONDES Bridge.
            </p>
          </div>
        </FadeIn>

        {/* Bento Grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Card 1 — Span 2: The Symbiotic Bridge */}
          <FadeIn delay={0.1} className="md:col-span-2">
            <div className="group relative h-full rounded-xl border border-white/[0.06] bg-white/[0.02] p-6 sm:p-8 hover:border-[#7c3aed]/30 transition-all duration-300 overflow-hidden">
              <div className="absolute top-0 right-0 w-64 h-64 bg-[radial-gradient(circle,_rgba(124,58,237,0.06)_0%,_transparent_70%)] opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
              <div className="relative">
                <div className="flex items-center gap-3 mb-4">
                  <div className="flex items-center justify-center h-10 w-10 rounded-lg bg-[#7c3aed]/10 border border-[#7c3aed]/20">
                    <ArrowLeftRight className="h-5 w-5 text-[#7c3aed]" />
                  </div>
                  <h3 className="text-lg font-semibold">The Symbiotic Bridge</h3>
                </div>
                <p className="text-white/40 text-sm leading-relaxed mb-6">
                  Bidirectional communication. The Guest asks, the Host delivers.
                  Zero latency. The <code className="text-[#7c3aed] font-mono text-xs">window.Ondes</code> object
                  is injected into every WebView, exposing 10+ native modules.
                </p>
                <CodeWindow title="guest_app.js" className="max-w-lg">
                  <code>
                    <span className="code-comment">{"// Access native from web"}</span>
                    {"\n"}
                    <span className="code-keyword">const</span>{" "}
                    <span className="code-variable">user</span>{" "}
                    <span className="code-punctuation">= </span>
                    <span className="code-keyword">await</span>{" "}
                    <span className="code-function">Ondes</span>
                    <span className="code-punctuation">.</span>
                    <span className="code-property">User</span>
                    <span className="code-punctuation">.</span>
                    <span className="code-method">getProfile</span>
                    <span className="code-punctuation">();</span>
                    {"\n"}
                    <span className="code-function">Ondes</span>
                    <span className="code-punctuation">.</span>
                    <span className="code-property">Device</span>
                    <span className="code-punctuation">.</span>
                    <span className="code-method">haptic</span>
                    <span className="code-punctuation">(</span>
                    <span className="code-string">&apos;medium&apos;</span>
                    <span className="code-punctuation">);</span>
                  </code>
                </CodeWindow>
              </div>
            </div>
          </FadeIn>

          {/* Card 2 — Span 1: Social Mesh */}
          <FadeIn delay={0.2}>
            <div className="group relative h-full rounded-xl border border-white/[0.06] bg-white/[0.02] p-6 sm:p-8 hover:border-[#06b6d4]/30 transition-all duration-300 overflow-hidden">
              <div className="absolute top-0 right-0 w-48 h-48 bg-[radial-gradient(circle,_rgba(6,182,212,0.06)_0%,_transparent_70%)] opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
              <div className="relative">
                <div className="flex items-center justify-center h-10 w-10 rounded-lg bg-[#06b6d4]/10 border border-[#06b6d4]/20 mb-4">
                  <Users className="h-5 w-5 text-[#06b6d4]" />
                </div>
                <h3 className="text-lg font-semibold mb-2">Social Mesh</h3>
                <p className="text-white/40 text-sm leading-relaxed">
                  Identity & Graph built-in. Users carry their profile, friends list,
                  and social feed across every mini-app. No auth setup needed.
                </p>
                <div className="mt-6 flex flex-wrap gap-2">
                  {["Feed", "Friends", "Stories", "Posts"].map((tag) => (
                    <span
                      key={tag}
                      className="px-2.5 py-1 text-xs font-mono rounded-md bg-[#06b6d4]/5 text-[#06b6d4]/70 border border-[#06b6d4]/10"
                    >
                      {tag}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </FadeIn>

          {/* Card 3 — Span 1: Native Delegation */}
          <FadeIn delay={0.3}>
            <div className="group relative h-full rounded-xl border border-white/[0.06] bg-white/[0.02] p-6 sm:p-8 hover:border-[#06b6d4]/30 transition-all duration-300 overflow-hidden">
              <div className="absolute top-0 right-0 w-48 h-48 bg-[radial-gradient(circle,_rgba(6,182,212,0.06)_0%,_transparent_70%)] opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
              <div className="relative">
                <div className="flex items-center justify-center h-10 w-10 rounded-lg bg-[#06b6d4]/10 border border-[#06b6d4]/20 mb-4">
                  <Layers className="h-5 w-5 text-[#06b6d4]" />
                </div>
                <h3 className="text-lg font-semibold mb-2">Native Delegation</h3>
                <p className="text-white/40 text-sm leading-relaxed">
                  Delegate UI complexity — Modals, Toasts, Navigation — to the Host
                  engine. Your mini-app stays lightweight, the Shell handles the rest.
                </p>
                <div className="mt-6 space-y-2">
                  {["showToast()", "showModal()", "navigate()"].map((fn) => (
                    <div
                      key={fn}
                      className="flex items-center gap-2 text-xs font-mono text-white/30"
                    >
                      <span className="h-1 w-1 rounded-full bg-[#06b6d4]" />
                      <span>Ondes.UI.{fn}</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </FadeIn>

          {/* Card 4 — Span 2: Instant Deployment */}
          <FadeIn delay={0.4} className="md:col-span-2">
            <div className="group relative h-full rounded-xl border border-white/[0.06] bg-white/[0.02] p-6 sm:p-8 hover:border-[#7c3aed]/30 transition-all duration-300 overflow-hidden">
              <div className="absolute top-0 left-0 w-64 h-64 bg-[radial-gradient(circle,_rgba(124,58,237,0.06)_0%,_transparent_70%)] opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
              <div className="relative flex flex-col sm:flex-row sm:items-center gap-6">
                <div className="flex-1">
                  <div className="flex items-center gap-3 mb-4">
                    <div className="flex items-center justify-center h-10 w-10 rounded-lg bg-[#7c3aed]/10 border border-[#7c3aed]/20">
                      <Rocket className="h-5 w-5 text-[#7c3aed]" />
                    </div>
                    <h3 className="text-lg font-semibold">Instant Deployment</h3>
                  </div>
                  <p className="text-white/40 text-sm leading-relaxed">
                    Push updates to thousands of devices instantly. No app store
                    delays, no recompilation. Upload a .zip, it&apos;s live. The Dev Studio
                    handles versioning and distribution through the internal Store.
                  </p>
                </div>
                <div className="flex-shrink-0 grid grid-cols-2 gap-3">
                  {[
                    { value: "0s", label: "Store delay" },
                    { value: "∞", label: "Hot updates" },
                    { value: ".zip", label: "Deploy format" },
                    { value: "10+", label: "SDK modules" },
                  ].map((stat) => (
                    <div
                      key={stat.label}
                      className="text-center px-4 py-3 rounded-lg bg-white/[0.03] border border-white/[0.04]"
                    >
                      <div className="text-xl font-bold gradient-text">
                        {stat.value}
                      </div>
                      <div className="text-[10px] text-white/30 mt-0.5 font-mono">
                        {stat.label}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </FadeIn>
        </div>

        {/* SDK Modules strip */}
        <FadeIn delay={0.5}>
          <div id="ecosystem" className="mt-16">
            <h3 className="text-center text-sm font-mono text-white/30 mb-6 tracking-widest uppercase">
              SDK Modules
            </h3>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-3">
              {sdkModules.map((mod, i) => (
                <div
                  key={mod.label}
                  className="group flex flex-col items-center text-center gap-2 rounded-xl border border-white/[0.04] bg-white/[0.01] p-4 hover:border-white/10 hover:bg-white/[0.03] transition-all duration-200"
                >
                  <mod.icon className="h-5 w-5 text-white/30 group-hover:text-[#7c3aed] transition-colors" />
                  <span className="text-xs font-medium text-white/60 group-hover:text-white/80 transition-colors">
                    {mod.label}
                  </span>
                  <span className="text-[10px] text-white/20 font-mono">
                    {mod.desc}
                  </span>
                </div>
              ))}
            </div>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
