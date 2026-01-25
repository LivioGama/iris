"use client";

import Image from "next/image";
import { motion } from "framer-motion";

export default function Hero() {
  return (
    <section className="relative flex flex-col items-center pt-24 pb-4 px-8 overflow-hidden">
      {/* Background Glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-[var(--color-brand-purple)] opacity-20 blur-[120px] rounded-full pointer-events-none" />

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8 }}
        className="relative z-10 flex flex-col items-center text-center max-w-4xl"
      >
        <div className="mb-8 relative w-full max-w-2xl aspect-[16/9] overflow-visible">
           <Image 
             src="/IRIS_banner.webp" 
             alt="I.R.I.S. Banner" 
             fill
             className="object-contain drop-shadow-[0_0_80px_rgba(168,85,247,0.4)]"
             priority
           />
        </div>
        
        <div className="max-w-2xl text-lg md:text-xl text-gray-400 leading-relaxed space-y-6 text-left md:text-center glass p-6 rounded-2xl border border-white/10">
            <h2 className="text-xl font-bold text-white mb-3">Inspiration</h2>
            <p>
            The paradox of modern computing: we communicate naturally with humans through voice and video, but interact with AI through typing, window switching, and prompt engineering.
            </p>
            <p>
            In 2018, Google demoed an AI assistant making phone calls—the world watched in awe, then progress stalled. Meanwhile, we&apos;ve normalized sending voice notes. <strong>I.R.I.S.</strong> is here to change that.
            </p>
        </div>
      </motion.div>
    </section>
  );
}
