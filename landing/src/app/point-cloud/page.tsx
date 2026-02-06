"use client";

import dynamic from "next/dynamic";

const PointCloud3D = dynamic(() => import("@/components/PointCloud3D"), {
  ssr: false,
  loading: () => (
    <div className="w-full h-screen bg-[#030408] flex items-center justify-center">
      <div className="text-white/40 text-sm animate-pulse">
        Loading point cloud...
      </div>
    </div>
  ),
});

export default function PointCloudPage() {
  return <PointCloud3D />;
}
