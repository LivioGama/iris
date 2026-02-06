"use client";

import { useRef, useMemo, useCallback, useState } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { OrbitControls } from "@react-three/drei";
import * as THREE from "three";

// --- Color palettes extracted from the images ---
const PALETTE = {
  // Image 1: warm swirl colors
  swirl: [
    new THREE.Color("#FFD700"), // gold/yellow
    new THREE.Color("#FF8C00"), // dark orange
    new THREE.Color("#FF4500"), // red-orange
    new THREE.Color("#DC143C"), // crimson
    new THREE.Color("#228B22"), // forest green
    new THREE.Color("#32CD32"), // lime green
    new THREE.Color("#00CED1"), // dark turquoise
    new THREE.Color("#4169E1"), // royal blue
    new THREE.Color("#FFFFFF"), // white
    new THREE.Color("#F5DEB3"), // wheat
  ],
  // Image 2: trail gradient (blue → teal → orange → yellow)
  trail: [
    new THREE.Color("#1E90FF"), // dodger blue
    new THREE.Color("#00BFFF"), // deep sky blue
    new THREE.Color("#00CED1"), // dark turquoise
    new THREE.Color("#20B2AA"), // light sea green
    new THREE.Color("#FFD700"), // gold
    new THREE.Color("#FF8C00"), // dark orange
    new THREE.Color("#FF4500"), // orange-red
    new THREE.Color("#FF1744"), // red accent
  ],
  // Background stars
  stars: [
    new THREE.Color("#AACCFF"),
    new THREE.Color("#88AAFF"),
    new THREE.Color("#FFFFFF"),
    new THREE.Color("#CCDDFF"),
  ],
};

// --- Seeded random for deterministic generation ---
function seededRandom(seed: number) {
  let s = seed;
  return () => {
    s = (s * 16807 + 0) % 2147483647;
    return (s - 1) / 2147483646;
  };
}

// --- Generate the swirling torus/sphere particles (Image 1) ---
function generateSwirlParticles(count: number) {
  const positions = new Float32Array(count * 3);
  const colors = new Float32Array(count * 3);
  const sizes = new Float32Array(count);
  const rand = seededRandom(42);

  for (let i = 0; i < count; i++) {
    // Torus-knot-like distribution with noise
    const t = rand() * Math.PI * 2;
    const p = rand() * Math.PI * 2;

    // Torus parameters
    const R = 2.2; // major radius
    const r = 0.9 + rand() * 0.7; // minor radius with variation

    // Add spiral twist
    const twist = t * 3;
    const noiseScale = 0.4;
    const nx = (rand() - 0.5) * noiseScale;
    const ny = (rand() - 0.5) * noiseScale;
    const nz = (rand() - 0.5) * noiseScale;

    const x = (R + r * Math.cos(p + twist)) * Math.cos(t) + nx;
    const y = (R + r * Math.cos(p + twist)) * Math.sin(t) + ny;
    const z = r * Math.sin(p + twist) + nz;

    positions[i * 3] = x;
    positions[i * 3 + 1] = y;
    positions[i * 3 + 2] = z;

    // Color based on angle + randomness
    const colorIndex = Math.floor(rand() * PALETTE.swirl.length);
    const color = PALETTE.swirl[colorIndex];
    colors[i * 3] = color.r;
    colors[i * 3 + 1] = color.g;
    colors[i * 3 + 2] = color.b;

    sizes[i] = 0.02 + rand() * 0.04;
  }

  return { positions, colors, sizes };
}

// --- Generate the curved trail particles (Image 2) ---
function generateTrailParticles(count: number) {
  const positions = new Float32Array(count * 3);
  const colors = new Float32Array(count * 3);
  const sizes = new Float32Array(count);
  const rand = seededRandom(123);

  for (let i = 0; i < count; i++) {
    // Parametric 3D spiral curve
    const t = (i / count) * Math.PI * 2.5 - Math.PI * 1.25;

    // S-curve with 3D depth
    const baseX = t * 1.5;
    const baseY = Math.sin(t * 0.8) * 2.5;
    const baseZ = Math.cos(t * 0.6) * 1.5;

    // Add spread around the curve
    const spread = 0.15 + rand() * 0.1;
    const angle = rand() * Math.PI * 2;

    positions[i * 3] = baseX + Math.cos(angle) * spread;
    positions[i * 3 + 1] = baseY + Math.sin(angle) * spread;
    positions[i * 3 + 2] = baseZ + (rand() - 0.5) * spread;

    // Color gradient along the trail
    const colorT = i / count;
    const colorIndex = Math.min(
      Math.floor(colorT * PALETTE.trail.length),
      PALETTE.trail.length - 1
    );
    const nextIndex = Math.min(colorIndex + 1, PALETTE.trail.length - 1);
    const lerpT = (colorT * PALETTE.trail.length) % 1;

    const color = new THREE.Color().lerpColors(
      PALETTE.trail[colorIndex],
      PALETTE.trail[nextIndex],
      lerpT
    );

    colors[i * 3] = color.r;
    colors[i * 3 + 1] = color.g;
    colors[i * 3 + 2] = color.b;

    sizes[i] = 0.03 + rand() * 0.03;
  }

  return { positions, colors, sizes };
}

// --- Generate background star particles ---
function generateStarParticles(count: number) {
  const positions = new Float32Array(count * 3);
  const colors = new Float32Array(count * 3);
  const sizes = new Float32Array(count);
  const rand = seededRandom(999);

  for (let i = 0; i < count; i++) {
    // Random points in a large sphere
    const theta = rand() * Math.PI * 2;
    const phi = Math.acos(2 * rand() - 1);
    const radius = 8 + rand() * 12;

    positions[i * 3] = radius * Math.sin(phi) * Math.cos(theta);
    positions[i * 3 + 1] = radius * Math.sin(phi) * Math.sin(theta);
    positions[i * 3 + 2] = radius * Math.cos(phi);

    const color = PALETTE.stars[Math.floor(rand() * PALETTE.stars.length)];
    colors[i * 3] = color.r;
    colors[i * 3 + 1] = color.g;
    colors[i * 3 + 2] = color.b;

    sizes[i] = 0.01 + rand() * 0.025;
  }

  return { positions, colors, sizes };
}

// --- Custom shader material for point rendering ---
const vertexShader = `
  attribute float size;
  varying vec3 vColor;
  uniform float uTime;
  uniform float uPixelRatio;

  void main() {
    vColor = color;
    vec3 pos = position;

    // Subtle floating animation
    pos.x += sin(uTime * 0.3 + position.y * 2.0) * 0.02;
    pos.y += cos(uTime * 0.2 + position.x * 2.0) * 0.02;
    pos.z += sin(uTime * 0.25 + position.z * 2.0) * 0.02;

    vec4 mvPosition = modelViewMatrix * vec4(pos, 1.0);
    gl_Position = projectionMatrix * mvPosition;

    // Size attenuation
    gl_PointSize = size * uPixelRatio * (200.0 / -mvPosition.z);
    gl_PointSize = max(gl_PointSize, 1.0);
  }
`;

const fragmentShader = `
  varying vec3 vColor;

  void main() {
    // Soft circular point with glow
    float dist = length(gl_PointCoord - vec2(0.5));
    if (dist > 0.5) discard;

    float alpha = 1.0 - smoothstep(0.0, 0.5, dist);
    float glow = exp(-dist * 4.0) * 0.6;

    gl_FragColor = vec4(vColor * (1.0 + glow), alpha);
  }
`;

// --- Points component for each particle group ---
function ParticleGroup({
  data,
  rotationSpeed = { x: 0, y: 0.001, z: 0 },
}: {
  data: { positions: Float32Array; colors: Float32Array; sizes: Float32Array };
  rotationSpeed?: { x: number; y: number; z: number };
}) {
  const pointsRef = useRef<THREE.Points>(null);
  const materialRef = useRef<THREE.ShaderMaterial>(null);

  const geometry = useMemo(() => {
    const geo = new THREE.BufferGeometry();
    geo.setAttribute("position", new THREE.BufferAttribute(data.positions, 3));
    geo.setAttribute("color", new THREE.BufferAttribute(data.colors, 3));
    geo.setAttribute("size", new THREE.BufferAttribute(data.sizes, 1));
    return geo;
  }, [data]);

  const uniforms = useMemo(
    () => ({
      uTime: { value: 0 },
      uPixelRatio: { value: typeof window !== "undefined" ? Math.min(window.devicePixelRatio, 2) : 1 },
    }),
    []
  );

  useFrame((_, delta) => {
    if (pointsRef.current) {
      pointsRef.current.rotation.x += rotationSpeed.x;
      pointsRef.current.rotation.y += rotationSpeed.y;
      pointsRef.current.rotation.z += rotationSpeed.z;
    }
    if (materialRef.current) {
      materialRef.current.uniforms.uTime.value += delta;
    }
  });

  return (
    <points ref={pointsRef} geometry={geometry}>
      <shaderMaterial
        ref={materialRef}
        vertexShader={vertexShader}
        fragmentShader={fragmentShader}
        uniforms={uniforms}
        vertexColors
        transparent
        depthWrite={false}
        blending={THREE.AdditiveBlending}
      />
    </points>
  );
}

// --- Main scene ---
function Scene() {
  const swirlData = useMemo(() => generateSwirlParticles(4000), []);
  const trailData = useMemo(() => generateTrailParticles(1200), []);
  const starData = useMemo(() => generateStarParticles(2000), []);

  return (
    <>
      <color attach="background" args={["#030408"]} />
      <fog attach="fog" args={["#030408", 12, 25]} />

      {/* Swirling torus cloud (Image 1) */}
      <ParticleGroup
        data={swirlData}
        rotationSpeed={{ x: 0.0003, y: 0.0008, z: 0.0002 }}
      />

      {/* Curved color trail (Image 2) */}
      <ParticleGroup
        data={trailData}
        rotationSpeed={{ x: -0.0002, y: 0.0006, z: 0.0001 }}
      />

      {/* Background stars */}
      <ParticleGroup
        data={starData}
        rotationSpeed={{ x: 0.00005, y: 0.0001, z: 0 }}
      />

      <OrbitControls
        enableDamping
        dampingFactor={0.05}
        rotateSpeed={0.5}
        minDistance={2}
        maxDistance={15}
        autoRotate
        autoRotateSpeed={0.3}
      />
    </>
  );
}

export default function PointCloud3D() {
  const containerRef = useRef<HTMLDivElement>(null);
  const [isFullscreen, setIsFullscreen] = useState(false);

  const toggleFullscreen = useCallback(() => {
    if (!containerRef.current) return;
    if (!document.fullscreenElement) {
      containerRef.current.requestFullscreen();
      setIsFullscreen(true);
    } else {
      document.exitFullscreen();
      setIsFullscreen(false);
    }
  }, []);

  return (
    <div ref={containerRef} className="relative w-full h-screen bg-[#030408]">
      <Canvas
        camera={{ position: [0, 0, 6], fov: 60, near: 0.1, far: 100 }}
        dpr={[1, 2]}
      >
        <Scene />
      </Canvas>

      {/* Controls overlay */}
      <div className="absolute bottom-6 left-1/2 -translate-x-1/2 flex items-center gap-4 text-white/50 text-sm select-none">
        <span>Drag to rotate</span>
        <span className="w-px h-4 bg-white/20" />
        <span>Scroll to zoom</span>
        <span className="w-px h-4 bg-white/20" />
        <button
          onClick={toggleFullscreen}
          className="hover:text-white/80 transition-colors cursor-pointer"
        >
          {isFullscreen ? "Exit Fullscreen" : "Fullscreen"}
        </button>
      </div>
    </div>
  );
}
