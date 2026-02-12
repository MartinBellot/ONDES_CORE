"use client";

import { useEffect, useRef } from "react";

interface Node {
  x: number;
  y: number;
  vx: number;
  vy: number;
  radius: number;
  label: string;
  color: string;
  type: "host" | "guest" | "native";
}

interface Particle {
  fromIdx: number;
  toIdx: number;
  progress: number;
  speed: number;
  color: string;
}

export function NetworkAnimation() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const animRef = useRef<number>(0);
  const nodesRef = useRef<Node[]>([]);
  const particlesRef = useRef<Particle[]>([]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    const dpr = window.devicePixelRatio || 1;

    const resize = () => {
      const rect = canvas.getBoundingClientRect();
      canvas.width = rect.width * dpr;
      canvas.height = rect.height * dpr;
      ctx.scale(dpr, dpr);
    };
    resize();
    window.addEventListener("resize", resize);

    const w = () => canvas.getBoundingClientRect().width;
    const h = () => canvas.getBoundingClientRect().height;

    // Initialize nodes
    nodesRef.current = [
      { x: w() * 0.5, y: h() * 0.45, vx: 0.1, vy: -0.08, radius: 22, label: "HOST", color: "#7c3aed", type: "host" },
      { x: w() * 0.2, y: h() * 0.25, vx: 0.15, vy: 0.1, radius: 14, label: "Web", color: "#06b6d4", type: "guest" },
      { x: w() * 0.8, y: h() * 0.3, vx: -0.12, vy: 0.08, radius: 14, label: "Social", color: "#06b6d4", type: "guest" },
      { x: w() * 0.15, y: h() * 0.7, vx: 0.08, vy: -0.12, radius: 14, label: "Store", color: "#06b6d4", type: "guest" },
      { x: w() * 0.75, y: h() * 0.75, vx: -0.1, vy: -0.06, radius: 14, label: "Chat", color: "#06b6d4", type: "guest" },
      { x: w() * 0.42, y: h() * 0.15, vx: -0.06, vy: 0.14, radius: 12, label: "GPS", color: "#34d399", type: "native" },
      { x: w() * 0.6, y: h() * 0.8, vx: 0.12, vy: -0.1, radius: 12, label: "Camera", color: "#34d399", type: "native" },
    ];

    // Initialize particles
    const initParticles = () => {
      const ps: Particle[] = [];
      for (let i = 0; i < 8; i++) {
        const from = i % nodesRef.current.length;
        let to = Math.floor(Math.random() * nodesRef.current.length);
        while (to === from) to = Math.floor(Math.random() * nodesRef.current.length);
        ps.push({
          fromIdx: from,
          toIdx: to,
          progress: Math.random(),
          speed: 0.002 + Math.random() * 0.004,
          color: Math.random() > 0.5 ? "#7c3aed" : "#06b6d4",
        });
      }
      particlesRef.current = ps;
    };
    initParticles();

    const draw = () => {
      const width = w();
      const height = h();
      ctx.clearRect(0, 0, width, height);

      const nodes = nodesRef.current;

      // Update node positions (gentle floating)
      nodes.forEach((n) => {
        n.x += n.vx;
        n.y += n.vy;
        if (n.x < 40 || n.x > width - 40) n.vx *= -1;
        if (n.y < 30 || n.y > height - 30) n.vy *= -1;
      });

      // Draw connections
      for (let i = 0; i < nodes.length; i++) {
        for (let j = i + 1; j < nodes.length; j++) {
          const dx = nodes[j].x - nodes[i].x;
          const dy = nodes[j].y - nodes[i].y;
          const dist = Math.sqrt(dx * dx + dy * dy);
          if (dist < 300) {
            const alpha = (1 - dist / 300) * 0.12;
            ctx.beginPath();
            ctx.moveTo(nodes[i].x, nodes[i].y);
            ctx.lineTo(nodes[j].x, nodes[j].y);
            ctx.strokeStyle = `rgba(124, 58, 237, ${alpha})`;
            ctx.lineWidth = 1;
            ctx.stroke();
          }
        }
      }

      // Draw & update particles
      particlesRef.current.forEach((p) => {
        p.progress += p.speed;
        if (p.progress >= 1) {
          p.progress = 0;
          p.fromIdx = p.toIdx;
          let newTo = Math.floor(Math.random() * nodes.length);
          while (newTo === p.fromIdx) newTo = Math.floor(Math.random() * nodes.length);
          p.toIdx = newTo;
        }

        const from = nodes[p.fromIdx];
        const to = nodes[p.toIdx];
        const px = from.x + (to.x - from.x) * p.progress;
        const py = from.y + (to.y - from.y) * p.progress;

        ctx.beginPath();
        ctx.arc(px, py, 2.5, 0, Math.PI * 2);
        ctx.fillStyle = p.color;
        ctx.fill();

        // Glow
        ctx.beginPath();
        ctx.arc(px, py, 6, 0, Math.PI * 2);
        const glow = ctx.createRadialGradient(px, py, 0, px, py, 6);
        glow.addColorStop(0, p.color + "40");
        glow.addColorStop(1, "transparent");
        ctx.fillStyle = glow;
        ctx.fill();
      });

      // Draw nodes
      nodes.forEach((n) => {
        // Outer glow
        ctx.beginPath();
        ctx.arc(n.x, n.y, n.radius + 8, 0, Math.PI * 2);
        const outerGlow = ctx.createRadialGradient(n.x, n.y, n.radius, n.x, n.y, n.radius + 8);
        outerGlow.addColorStop(0, n.color + "15");
        outerGlow.addColorStop(1, "transparent");
        ctx.fillStyle = outerGlow;
        ctx.fill();

        // Node circle
        ctx.beginPath();
        ctx.arc(n.x, n.y, n.radius, 0, Math.PI * 2);
        ctx.fillStyle = "#0a0a0a";
        ctx.fill();
        ctx.strokeStyle = n.color + "80";
        ctx.lineWidth = 1.5;
        ctx.stroke();

        // Label
        ctx.font = `${n.type === "host" ? "bold 10px" : "9px"} var(--font-mono, monospace)`;
        ctx.fillStyle = n.color;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(n.label, n.x, n.y);
      });

      animRef.current = requestAnimationFrame(draw);
    };

    draw();

    return () => {
      cancelAnimationFrame(animRef.current);
      window.removeEventListener("resize", resize);
    };
  }, []);

  return (
    <div className="relative rounded-2xl border border-white/[0.06] bg-[#0a0a0a]/50 overflow-hidden">
      <canvas
        ref={canvasRef}
        className="w-full h-[280px] sm:h-[340px]"
      />
      {/* Bottom labels */}
      <div className="flex items-center justify-center gap-6 py-3 border-t border-white/[0.04]">
        <div className="flex items-center gap-2 text-xs text-white/30">
          <span className="h-2 w-2 rounded-full bg-[#7c3aed]" />
          App principale
        </div>
        <div className="flex items-center gap-2 text-xs text-white/30">
          <span className="h-2 w-2 rounded-full bg-[#06b6d4]" />
          Mini-apps
        </div>
        <div className="flex items-center gap-2 text-xs text-white/30">
          <span className="h-2 w-2 rounded-full bg-[#34d399]" />
          Fonctions du téléphone
        </div>
      </div>
    </div>
  );
}
