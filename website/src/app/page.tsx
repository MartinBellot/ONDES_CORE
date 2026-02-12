import { Navbar } from "@/components/navbar";
import { Hero } from "@/components/hero";
import { FeatureGrid } from "@/components/feature-grid";
import { InteractiveDemo } from "@/components/interactive-demo";
import { SecuritySection } from "@/components/security-section";
import { ComparisonSection } from "@/components/comparison-section";
import { Footer } from "@/components/footer";

export default function Home() {
  return (
    <main className="relative min-h-screen">
      <Navbar />
      <Hero />
      <FeatureGrid />
      <InteractiveDemo />
      <SecuritySection />
      <ComparisonSection />
      <Footer />
    </main>
  );
}
