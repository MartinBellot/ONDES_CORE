"use client";

import { motion } from "framer-motion";
import { ArrowRight, BookOpen } from "lucide-react";
import Link from "next/link";
import { NetworkAnimation } from "./network-animation";

export function Hero() {
  return (
    <section className="relative min-h-screen flex items-center justify-center overflow-hidden grid-bg">
      {/* Radial gradient overlay */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,_rgba(124,58,237,0.08)_0%,_transparent_70%)]" />
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-[radial-gradient(circle,_rgba(6,182,212,0.04)_0%,_transparent_60%)]" />

      <div className="relative z-10 mx-auto max-w-6xl px-6 pt-32 pb-20">
        <div className="flex flex-col items-center text-center">
          {/* Badge */}
          <motion.div
            initial={{ opacity: 0, y: 10 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.1 }}
          >
            <span className="inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.03] px-4 py-1.5 text-xs text-white/50 font-mono">
              <span className="h-1.5 w-1.5 rounded-full bg-[#7c3aed] animate-pulse" />
              Flutter Super App Engine
            </span>
          </motion.div>

          {/* Headline */}
          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.2 }}
            className="mt-8 text-4xl sm:text-5xl md:text-7xl font-bold tracking-tight leading-[1.1] max-w-4xl"
          >
            The Protocol for{" "}
            <span className="gradient-text">Interconnected</span>{" "}
            Super Apps.
          </motion.h1>

          {/* Subheadline */}
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.35 }}
            className="mt-6 text-base sm:text-lg text-white/40 max-w-2xl leading-relaxed"
          >
            Orchestrate a mesh of native-capable mini-apps. One Host, infinite
            Guests, seamless communication via the{" "}
            <span className="text-[#7c3aed]">ONDES Bridge</span>.
          </motion.p>

          {/* CTAs */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.6, delay: 0.5 }}
            className="mt-10 flex flex-col sm:flex-row items-center gap-4"
          >
            <Link
              href="https://martinbellot.github.io/ONDES_CORE/"
              target="_blank"
              rel="noopener noreferrer"
              className="group flex items-center gap-2 rounded-xl bg-gradient-to-r from-[#7c3aed] to-[#6d28d9] px-6 py-3 text-sm font-medium text-white transition-all duration-200 hover:shadow-lg hover:shadow-[#7c3aed]/20"
            >
              Explore the Ecosystem
              <ArrowRight className="h-4 w-4 transition-transform group-hover:translate-x-0.5" />
            </Link>
            <Link
              href="https://martinbellot.github.io/ONDES_CORE/mini_app_guide/"
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-2 rounded-xl border border-white/10 bg-white/[0.03] px-6 py-3 text-sm font-medium text-white/70 hover:text-white hover:border-white/20 transition-all duration-200"
            >
              <BookOpen className="h-4 w-4" />
              Build a Mini-App
            </Link>
          </motion.div>

          {/* Network Animation */}
          <motion.div
            initial={{ opacity: 0, scale: 0.95 }}
            animate={{ opacity: 1, scale: 1 }}
            transition={{ duration: 0.8, delay: 0.6 }}
            className="mt-16 w-full max-w-3xl"
          >
            <NetworkAnimation />
          </motion.div>
        </div>
      </div>

      {/* Bottom fade */}
      <div className="absolute bottom-0 left-0 right-0 h-32 bg-gradient-to-t from-[#050505] to-transparent" />
    </section>
  );
}
