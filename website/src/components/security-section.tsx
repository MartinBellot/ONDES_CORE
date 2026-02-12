"use client";

import { Shield, Lock, KeyRound, Fingerprint } from "lucide-react";
import { FadeIn } from "./fade-in";

const permissions = [
  { key: "camera", label: "Caméra & Scanner" },
  { key: "location", label: "Localisation" },
  { key: "storage", label: "Fichiers" },
  { key: "friends", label: "Amis" },
  { key: "social", label: "Publications" },
  { key: "bluetooth", label: "Bluetooth" },
];

export function SecuritySection() {
  return (
    <section className="relative py-24 sm:py-32">
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_top,_rgba(6,182,212,0.04)_0%,_transparent_50%)]" />

      <div className="mx-auto max-w-6xl px-6 relative">
        <FadeIn>
          <div className="text-center mb-16">
            <span className="inline-block text-xs font-mono text-[#06b6d4] tracking-widest uppercase mb-4">
              Sécurité
            </span>
            <h2 className="text-3xl sm:text-4xl font-bold tracking-tight">
              Vos données sont <span className="gradient-text">protégées</span>
            </h2>
            <p className="mt-4 text-white/40 max-w-xl mx-auto">
              Chaque mini-app est isolée dans sa propre bulle. Elle ne peut accéder
              qu&apos;aux fonctions que vous avez autorisées — comme les permissions sur votre smartphone.
            </p>
          </div>
        </FadeIn>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          {/* Security Flow */}
          <FadeIn delay={0.1}>
            <div className="rounded-xl border border-white/[0.06] bg-white/[0.02] p-6 sm:p-8 h-full">
              <h3 className="text-lg font-semibold mb-6 flex items-center gap-2">
                <Shield className="h-5 w-5 text-[#06b6d4]" />
                Comment ça fonctionne
              </h3>
              <div className="space-y-4">
                {[
                  {
                    icon: KeyRound,
                    title: "L'app annonce ses besoins",
                    desc: "Avant l'installation, chaque mini-app indique ce à quoi elle a besoin d'accéder (caméra, position, etc.).",
                  },
                  {
                    icon: Fingerprint,
                    title: "Vous décidez",
                    desc: "Une fenêtre vous montre clairement les accès demandés. Vous acceptez ou vous refusez — c'est vous le patron.",
                  },
                  {
                    icon: Shield,
                    title: "Vérification permanente",
                    desc: "Chaque action est vérifiée en temps réel. Si une app essaie d'accéder à quelque chose de non autorisé, c'est bloqué.",
                  },
                  {
                    icon: Lock,
                    title: "Messagerie chiffrée",
                    desc: "Les messages sont chiffrés sur votre appareil avant d'être envoyés. Personne — même pas le serveur — ne peut les lire.",
                  },
                ].map((item, i) => (
                  <div key={item.title} className="flex gap-4">
                    <div className="flex-shrink-0">
                      <div className="flex items-center justify-center h-8 w-8 rounded-lg bg-[#06b6d4]/10 border border-[#06b6d4]/20">
                        <item.icon className="h-4 w-4 text-[#06b6d4]" />
                      </div>
                      {i < 3 && (
                        <div className="w-px h-4 bg-white/[0.06] mx-auto mt-1" />
                      )}
                    </div>
                    <div>
                      <h4 className="text-sm font-medium mb-0.5">{item.title}</h4>
                      <p className="text-xs text-white/35 leading-relaxed">
                        {item.desc}
                      </p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </FadeIn>

          {/* Permission Grid */}
          <FadeIn delay={0.2}>
            <div className="rounded-xl border border-white/[0.06] bg-white/[0.02] p-6 sm:p-8 h-full">
              <h3 className="text-lg font-semibold mb-6">
                Accès contrôlés
              </h3>

              {/* Mock manifest */}
              <div className="rounded-lg bg-[#0a0a0a] border border-white/[0.04] p-4 mb-6 font-mono text-xs">
                <span className="code-punctuation">{"{"}</span>
                {"\n"}
                {"  "}
                <span className="code-property">&quot;id&quot;</span>
                <span className="code-punctuation">: </span>
                <span className="code-string">&quot;com.app.explore&quot;</span>
                <span className="code-punctuation">,</span>
                {"\n"}
                {"  "}
                <span className="code-property">&quot;permissions&quot;</span>
                <span className="code-punctuation">: [</span>
                {"\n"}
                {"    "}
                <span className="code-string">&quot;camera&quot;</span>
                <span className="code-punctuation">,</span>
                {"\n"}
                {"    "}
                <span className="code-string">&quot;location&quot;</span>
                <span className="code-punctuation">,</span>
                {"\n"}
                {"    "}
                <span className="code-string">&quot;friends&quot;</span>
                {"\n"}
                {"  "}
                <span className="code-punctuation">]</span>
                {"\n"}
                <span className="code-punctuation">{"}"}</span>
              </div>

              {/* Permission chips */}
              <div className="grid grid-cols-2 gap-2">
                {permissions.map((perm) => (
                  <div
                    key={perm.key}
                    className="flex items-center gap-2.5 rounded-lg border border-white/[0.04] bg-white/[0.01] px-3 py-2.5 hover:border-[#06b6d4]/20 transition-colors duration-200"
                  >
                    <span className="h-1.5 w-1.5 rounded-full bg-[#06b6d4]" />
                    <div>
                      <span className="block text-xs text-white/60">
                        {perm.label}
                      </span>
                      <span className="block text-[10px] text-white/20 font-mono">
                        {perm.key}
                      </span>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </FadeIn>
        </div>
      </div>
    </section>
  );
}
