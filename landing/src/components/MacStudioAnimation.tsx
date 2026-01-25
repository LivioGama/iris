"use client";

import { motion, useScroll, useTransform } from "framer-motion";
import { useRef } from "react";
import EyeGazeDemo from "./EyeGazeDemo";

export default function MacStudioAnimation() {
  const containerRef = useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: containerRef,
    offset: ["start start", "end end"],
  });

  // Animation values
  // 0 -> 0.5: Mac Studio floats up and "opens" (scales up to fill screen)
  // 0.5 -> 1.0: Full screen demo active

  // Scroll Physics for "Unfold"
  // We want: Start tilted back (90deg, flat) and low (y: 200), then rotate up to 0deg (facing user) and rise to center (y: 0).
  
  const rotateX = useTransform(scrollYProgress, [0, 0.4], [90, 0]);
  const scale = useTransform(scrollYProgress, [0, 0.4], [0.8, 1]);
  const y = useTransform(scrollYProgress, [0, 0.4], [200, 0]); 
  const opacity = useTransform(scrollYProgress, [0, 0.1], [0, 1]);
  const contentOpacity = useTransform(scrollYProgress, [0.3, 0.4], [0, 1]); // Content fades in as screen faces user

  return (
    <section ref={containerRef} className="relative h-[250vh] bg-[#03040B] perspective-[2000px] z-10">
      <div className="sticky top-0 h-screen w-full flex items-center justify-center overflow-hidden perspective-[2000px] pointer-events-none">
        
        {/* Apple Studio Display Structure */}
        <motion.div
           style={{ 
             rotateX,
             scale,
             y,
             opacity,
             transformStyle: "preserve-3d", 
             width: "90%",
             maxWidth: "1400px",
             aspectRatio: "16/9", 
           }}
           className="relative z-20 flex flex-col items-center origin-bottom pointer-events-auto"
        >
            {/* The Screen (Bezel + Panel) */}
            <div className="relative w-full h-full bg-black rounded-[24px] shadow-2xl border-[12px] border-black overflow-hidden ring-1 ring-white/10">
                {/* Glossy Reflection */}
                <div className="absolute inset-0 bg-gradient-to-tr from-white/5 to-transparent pointer-events-none z-30 mix-blend-overlay" />
                
                {/* Inner Screen Content */}
                <motion.div 
                    style={{ opacity: contentOpacity }}
                    className="w-full h-full bg-black relative z-10"
                >
                    <EyeGazeDemo />
                </motion.div>
            </div>

            {/* The Stand (Neck + Base) - Simulated 3D appearing behind */}
            <motion.div 
                className="absolute top-full mt-[-20px] flex flex-col items-center -z-10"
                style={{ 
                    transformOrigin: "top",
                    rotateX: useTransform(scrollYProgress, [0, 0.4], [-90, 0]) // Counter-rotate to keep stand upright-ish or just hinge with it? 
                    // Actually, if the screen rotates up, the stand should simple appear attached. 
                    // Let's keep it simple: just attached to the bottom.
                 }}
            >
                {/* Stand Neck */}
                <div className="w-32 h-24 bg-gradient-to-b from-[#b0b0b0] to-[#e0e0e0] shadow-inner" />
                {/* Stand Base */}
                <div className="w-48 h-2 bg-[#d0d0d0] rounded-b-md shadow-lg" />
            </motion.div>

        </motion.div>

      </div>
    </section>
  );
}
