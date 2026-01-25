"use client";

import { useEffect, useRef, useState } from "react";
import { motion, useSpring, useMotionValue, animate } from "framer-motion";
import Script from "next/script";

declare global {
  interface Window {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    webgazer: any;
  }
}

export default function EyeGazeDemo() {
  const ref = useRef<HTMLDivElement>(null);
  const [activeTarget, setActiveTarget] = useState<number | null>(null);
  const [mode, setMode] = useState<'animation' | 'mouse' | 'gaze'>('animation');
  
  // Position tracking
  const x = useMotionValue(0);
  const y = useMotionValue(0);

  // Smooth "Gaze" spring physics
  const springConfig = { damping: 20, stiffness: 150, mass: 0.6 };
  const gazeX = useSpring(x, springConfig);
  const gazeY = useSpring(y, springConfig);

  // S-Shape Animation on Mount
  useEffect(() => {
    if (mode !== 'animation' || !ref.current) return;

    const rect = ref.current.getBoundingClientRect();
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;
    const width = rect.width * 0.8;
    const height = rect.height * 0.8;

    // Start position
    x.set(centerX);
    y.set(centerY - height / 2);

    // Animate in 'S' shape
    const controls = animate(0, 1, {
      duration: 3.5,
      ease: "easeInOut",
      onUpdate: (t) => {
        const currentY = (centerY - height / 2) + (height * t);
        const currentX = centerX + Math.sin(t * Math.PI * 2.5) * (width / 2);
        
        x.set(currentX);
        y.set(currentY);
      },
      onComplete: () => {
        setMode('mouse');
      }
    });

    return () => controls.stop();
  }, [mode, x, y]);

  // Mouse Listener
  useEffect(() => {
    if (mode !== 'mouse') return;

    const handleMouseMove = (e: MouseEvent) => {
      if (!ref.current) return;
      const rect = ref.current.getBoundingClientRect();
      const localX = Math.max(0, Math.min(e.clientX - rect.left, rect.width));
      const localY = Math.max(0, Math.min(e.clientY - rect.top, rect.height));
      
      x.set(localX);
      y.set(localY);
    };

    const element = ref.current;
    if (element) {
        element.addEventListener("mousemove", handleMouseMove);
    }
    return () => {
        if (element) element.removeEventListener("mousemove", handleMouseMove);
    };
  }, [mode, x, y]);

  const startGaze = async () => {
    if (typeof window === 'undefined' || !window.webgazer) {
        alert("WebGazer not loaded yet. Please wait.");
        return;
    }
    
    try {
        await window.webgazer.setRegression('ridge')
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            .setGazeListener((data: any) => {
                if (data && ref.current) {
                   const rect = ref.current.getBoundingClientRect();
                   const localX = data.x - rect.left;
                   const localY = data.y - rect.top;
                   x.set(localX);
                   y.set(localY);
                }
            })
            .begin();
        
        window.webgazer.showVideoPreview(true)
             .showPredictionPoints(false)
             .applyKalmanFilter(true);
        
        setMode('gaze');
    } catch (err) {
        console.error("Gaze init failed", err);
        alert("Could not start eye tracking. Camera permission denied?");
    }
  };

  return (
    <div ref={ref} className="relative w-full h-full bg-black/90 overflow-hidden flex items-center justify-center cursor-none group">
       <Script 
            src="https://webgazer.cs.brown.edu/webgazer.js" 
            strategy="lazyOnload" 
       />

       {/* Grid Targets */}
       <div className="absolute inset-0 grid grid-cols-2 grid-rows-2 gap-4 p-12">
            {[1, 2, 3, 4].map((i) => (
                <div 
                    key={i}
                    onMouseEnter={() => mode !== 'animation' && setActiveTarget(i)}
                    onMouseLeave={() => setActiveTarget(null)}
                    className={`
                        relative border rounded-3xl flex items-center justify-center transition-all duration-300
                        ${activeTarget === i ? 'border-[var(--color-brand-cyan)] bg-[var(--color-brand-cyan)]/10 scale-[1.02]' : 'border-white/10 hover:border-white/20'}
                    `}
                >
                    <span className={`text-2xl font-bold transition-colors ${activeTarget === i ? 'text-white' : 'text-gray-600'}`}>
                        Target {i}
                    </span>
                    
                    {/* Visual hint for hover during 'gaze' mode check could go here, but hover usually works via mouse event simulation or geometric check.
                        Since we are just moving a visual cursor, 'onMouseEnter' won't trigger from the 'div' cursor unless we do elementFromPoint.
                        For this lightweight demo, we'll just check geometric intersection in render or effect if we wanted true interaction.
                        But simple mouse cursor following (state update) doesn't trigger onMouseEnter for DOM elements underneath unless pointer-events pass through.
                        The 'cursor' motion div has pointer-events-none, so underlying divs *should* receive mouse events in 'mouse' mode.
                        In 'gaze' mode, we aren't moving the actual system mouse, so hover CSS won't trigger. 
                        We would need manual collision detection. For "Quick Hackathon Landing", visual cursor is enough.
                    */}
                </div>
            ))}
       </div>

       {/* Gaze Cursor (The "Bubble") */}
       <motion.div
         style={{ x: gazeX, y: gazeY }}
         className="pointer-events-none absolute top-0 left-0 -ml-8 -mt-8 w-16 h-16 rounded-full border-2 border-[var(--color-brand-purple)] bg-[var(--color-brand-purple)]/20 backdrop-blur-sm z-50 flex items-center justify-center"
       >
         <div className="w-2 h-2 bg-[var(--color-brand-cyan)] rounded-full shadow-[0_0_10px_var(--color-brand-cyan)]" />
       </motion.div>
       
       {/* UI Overlay */}
       <div className="absolute bottom-8 flex flex-col items-center gap-4 z-50">
         {mode === 'animation' && (
            <div className="text-gray-500 text-sm animate-pulse">Initializing System...</div>
         )}
         
         {mode === 'mouse' && (
             <button 
                onClick={startGaze}
                className="bg-[var(--color-brand-purple)] text-white px-6 py-2 rounded-full font-semibold hover:bg-purple-500 transition-colors shadow-[0_0_20px_rgba(168,85,247,0.4)] cursor-pointer"
             >
                Try with eyes
             </button>
         )}

         {mode === 'gaze' && (
             <div className="text-[var(--color-brand-cyan)] text-sm font-mono">
                System Active • Gaze Tracking On
             </div>
         )}

         <div className="text-xs text-gray-600">
             {mode === 'mouse' ? "Move cursor to simulate" : mode === 'gaze' ? "Look at targets" : ""}
         </div>
       </div>
    </div>
  );
}
