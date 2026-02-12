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
              En pratique
            </span>
            <h2 className="text-3xl sm:text-4xl font-bold tracking-tight">
              Simple comme <span className="gradient-text">bonjour</span>
            </h2>
            <p className="mt-4 text-white/40 max-w-xl mx-auto">
              En quelques lignes, votre mini-app reconnaît l&apos;utilisateur,
              fait vibrer le téléphone et affiche un message. Tout ça sans rien installer.
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
                  <span className="code-comment">{"// 1. Récupérer le profil de l'utilisateur"}</span>
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
                  <span className="code-comment">{"// 2. Faire vibrer le téléphone"}</span>
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
                  <span className="code-comment">{"// 3. Afficher un message de bienvenue"}</span>
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
                  title: "L'utilisateur est déjà connu",
                  desc: "Pas besoin de formulaire d'inscription. Le profil, les amis, le fil d'actu — tout est déjà là.",
                  color: "#7c3aed",
                },
                {
                  step: "02",
                  title: "Accès au téléphone",
                  desc: "Vibrations, caméra, GPS, scanner QR — votre mini-app peut tout utiliser en une seule ligne.",
                  color: "#06b6d4",
                },
                {
                  step: "03",
                  title: "Messages et fenêtres",
                  desc: "Affichez des notifications, des popups ou naviguez entre écrans sans gérer la complexité.",
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
                  Testez vos apps en temps réel sur votre téléphone.
                  Modifiez le code sur votre ordi, le résultat s&apos;affiche instantanément sur l&apos;écran.
                </p>
              </div>
            </div>
          </div>
        </FadeIn>
      </div>
    </section>
  );
}
