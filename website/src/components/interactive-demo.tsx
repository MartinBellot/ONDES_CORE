"use client";

import { FadeIn } from "./fade-in";
import { CodeWindow } from "./code-window";
import { Play } from "lucide-react";

export function InteractiveDemo() {
  return (
    <section className="relative py-24 sm:py-32">
      {/* Background glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-[radial-gradient(circle,_rgba(124,58,237,0.05)_0%,_transparent_60%)]" />

      <div className="mx-auto max-w-6xl px-6">
        <FadeIn>
          <div className="text-center mb-12">
            <span className="inline-block text-xs font-mono text-[#06b6d4] tracking-widest uppercase mb-4">
              Interactive Demo
            </span>
            <h2 className="text-3xl sm:text-4xl font-bold tracking-tight">
              The <span className="gradient-text">&quot;Aha!&quot;</span> Moment
            </h2>
            <p className="mt-4 text-white/40 max-w-xl mx-auto">
              See how a Mini-App interacts with the Host Shell and Hardware in
              just a few lines of code.
            </p>
          </div>
        </FadeIn>

        <FadeIn delay={0.15}>
          <div className="grid grid-cols-1 lg:grid-cols-5 gap-6">
            {/* Code Block */}
            <div className="lg:col-span-3">
              <CodeWindow title="guest_app.js">
                <code className="text-[13px]">
                  <span className="code-comment">{"// guest_app.js"}</span>
                  {"\n"}
                  <span className="code-variable">document</span>
                  <span className="code-punctuation">.</span>
                  <span className="code-method">addEventListener</span>
                  <span className="code-punctuation">(</span>
                  <span className="code-string">&apos;OndesReady&apos;</span>
                  <span className="code-punctuation">,</span>
                  {" "}
                  <span className="code-keyword">async</span>
                  {" "}
                  <span className="code-punctuation">() =&gt; {"{"}</span>
                  {"\n\n"}
                  {"  "}
                  <span className="code-comment">{"// 1. Connect to the Social Mesh"}</span>
                  {"\n"}
                  {"  "}
                  <span className="code-keyword">const</span>
                  {" "}
                  <span className="code-variable">profile</span>
                  {" "}
                  <span className="code-punctuation">=</span>
                  {" "}
                  <span className="code-keyword">await</span>
                  {" "}
                  <span className="code-function">Ondes</span>
                  <span className="code-punctuation">.</span>
                  <span className="code-property">Social</span>
                  <span className="code-punctuation">.</span>
                  <span className="code-method">getProfile</span>
                  <span className="code-punctuation">();</span>
                  {"\n\n"}
                  {"  "}
                  <span className="code-comment">{"// 2. Trigger Native Hardware"}</span>
                  {"\n"}
                  {"  "}
                  <span className="code-function">Ondes</span>
                  <span className="code-punctuation">.</span>
                  <span className="code-property">Device</span>
                  <span className="code-punctuation">.</span>
                  <span className="code-method">haptic</span>
                  <span className="code-punctuation">(</span>
                  <span className="code-string">&apos;medium&apos;</span>
                  <span className="code-punctuation">);</span>
                  {"\n\n"}
                  {"  "}
                  <span className="code-comment">{"// 3. Delegate UI to Host"}</span>
                  {"\n"}
                  {"  "}
                  <span className="code-function">Ondes</span>
                  <span className="code-punctuation">.</span>
                  <span className="code-property">Interface</span>
                  <span className="code-punctuation">.</span>
                  <span className="code-method">showToast</span>
                  <span className="code-punctuation">(</span>
                  {"\n"}
                  {"    "}
                  <span className="code-string">{"`Connected as ${"}</span>
                  <span className="code-variable">profile</span>
                  <span className="code-punctuation">.</span>
                  <span className="code-property">name</span>
                  <span className="code-string">{"}`"}</span>
                  {"\n"}
                  {"  "}
                  <span className="code-punctuation">);</span>
                  {"\n"}
                  <span className="code-punctuation">{"}"});</span>
                </code>
              </CodeWindow>
            </div>

            {/* Explanation Panel */}
            <div className="lg:col-span-2 flex flex-col gap-4">
              {[
                {
                  step: "01",
                  title: "Social Mesh",
                  desc: "Instantly access the user's identity, friends, and social graph — no auth setup required.",
                  color: "#7c3aed",
                },
                {
                  step: "02",
                  title: "Native Hardware",
                  desc: "Trigger haptics, access camera, GPS, QR scanner — all with a single API call from JS.",
                  color: "#06b6d4",
                },
                {
                  step: "03",
                  title: "Host UI Delegation",
                  desc: "Let the Shell handle native Toasts, Modals, and Navigation. Your app stays lightweight.",
                  color: "#34d399",
                },
              ].map((item) => (
                <div
                  key={item.step}
                  className="group rounded-xl border border-white/[0.06] bg-white/[0.02] p-5 hover:border-white/10 transition-all duration-200"
                >
                  <div className="flex items-start gap-4">
                    <span
                      className="flex-shrink-0 flex items-center justify-center h-8 w-8 rounded-lg text-xs font-mono font-bold"
                      style={{
                        backgroundColor: item.color + "10",
                        color: item.color,
                        borderColor: item.color + "20",
                        borderWidth: 1,
                      }}
                    >
                      {item.step}
                    </span>
                    <div>
                      <h4 className="text-sm font-semibold mb-1">{item.title}</h4>
                      <p className="text-xs text-white/35 leading-relaxed">
                        {item.desc}
                      </p>
                    </div>
                  </div>
                </div>
              ))}

              {/* Ondes Lab callout */}
              <div className="rounded-xl border border-[#7c3aed]/20 bg-[#7c3aed]/[0.04] p-5">
                <div className="flex items-center gap-2 mb-2">
                  <Play className="h-4 w-4 text-[#7c3aed]" />
                  <h4 className="text-sm font-semibold text-[#7c3aed]">
                    Ondes Lab
                  </h4>
                </div>
                <p className="text-xs text-white/35 leading-relaxed">
                  Dev environment with Hot Reload over WiFi.
                  Code on your machine, test live on device — no recompilation needed.
                </p>
              </div>
            </div>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
