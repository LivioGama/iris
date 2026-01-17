#!/usr/bin/env python3
"""
IRIS Gaze Calibration Tool

Shows target points on screen, collects raw nose landmark data from IRIS,
and computes optimal calibration parameters.

Usage:
    python3 calibrate.py              # Full 9-point calibration
    python3 calibrate.py --quick      # Quick 5-point calibration
    python3 calibrate.py --test       # Test current calibration (live view)

Requires IRIS to be running (reads /tmp/iris_raw_nose.txt).
"""

import sys
import time
import math
import json
import os
import statistics
from dataclasses import dataclass, field
from pathlib import Path

try:
    import tkinter as tk
except ImportError:
    print("ERROR: tkinter not available. Install with: brew install python-tk")
    sys.exit(1)

# ─── Config ──────────────────────────────────────────────────────────────────

RAW_NOSE_FILE = "/tmp/iris_raw_nose.txt"
CALIBRATION_FILE = "/tmp/iris_calibration.txt"
GAIN_FILE = "/tmp/iris_gain.txt"
OFFSETS_FILE = "/tmp/iris_offsets.txt"

# Timing
SETTLE_TIME = 1.5       # seconds to wait before collecting (let user fixate)
COLLECT_TIME = 3.0       # seconds to collect data per point
POLL_INTERVAL = 33       # ms between reads (~30 Hz)

# Visual
TARGET_RADIUS = 18
TARGET_INNER = 4
BG_COLOR = "#0a0a0a"
TARGET_COLOR = "#00ff88"
TARGET_ACTIVE = "#ff4444"
TEXT_COLOR = "#cccccc"
ACCENT_COLOR = "#4488ff"

# Screen margin (% from edge for corner targets)
MARGIN = 0.08


@dataclass
class Sample:
    raw_x: float
    raw_y: float
    ema_x: float
    ema_y: float
    timestamp: float


@dataclass
class TargetData:
    name: str
    screen_x: float  # normalized 0-1
    screen_y: float  # normalized 0-1
    samples: list = field(default_factory=list)

    @property
    def median_raw_x(self):
        if not self.samples:
            return None
        return statistics.median(s.raw_x for s in self.samples)

    @property
    def median_raw_y(self):
        if not self.samples:
            return None
        return statistics.median(s.raw_y for s in self.samples)

    @property
    def std_raw_x(self):
        if len(self.samples) < 2:
            return 0
        return statistics.stdev(s.raw_x for s in self.samples)

    @property
    def std_raw_y(self):
        if len(self.samples) < 2:
            return 0
        return statistics.stdev(s.raw_y for s in self.samples)


def read_raw_nose() -> tuple[float, float, float, float] | None:
    """Read current raw nose position from IRIS tracker."""
    try:
        data = Path(RAW_NOSE_FILE).read_text().strip()
        parts = data.split()
        if len(parts) >= 4:
            return float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])
        elif len(parts) >= 2:
            return float(parts[0]), float(parts[1]), float(parts[0]), float(parts[1])
    except (FileNotFoundError, ValueError, IndexError):
        pass
    return None


class CalibrationApp:
    def __init__(self, mode="full"):
        self.mode = mode
        self.root = tk.Tk()
        self.root.title("IRIS Calibration")
        self.root.configure(bg=BG_COLOR)

        # Go fullscreen
        self.root.attributes("-fullscreen", True)
        self.root.attributes("-topmost", True)
        self.root.update()

        self.screen_w = self.root.winfo_screenwidth()
        self.screen_h = self.root.winfo_screenheight()

        self.canvas = tk.Canvas(
            self.root,
            width=self.screen_w,
            height=self.screen_h,
            bg=BG_COLOR,
            highlightthickness=0,
        )
        self.canvas.pack()

        # Bind escape to quit
        self.root.bind("<Escape>", lambda e: self.quit())
        self.root.bind("<q>", lambda e: self.quit())

        # Build target list
        self.targets = self._build_targets()
        self.current_target_idx = -1
        self.phase = "intro"  # intro -> settling -> collecting -> result
        self.phase_start = 0.0
        self.collecting = False
        self.done = False

        # Results
        self.calibration_result = None

    def _build_targets(self) -> list[TargetData]:
        m = MARGIN
        if self.mode == "quick":
            return [
                TargetData("Center", 0.5, 0.5),
                TargetData("Top-Left", m, m),
                TargetData("Top-Right", 1 - m, m),
                TargetData("Bottom-Left", m, 1 - m),
                TargetData("Bottom-Right", 1 - m, 1 - m),
            ]
        else:
            return [
                TargetData("Center", 0.5, 0.5),
                TargetData("Top-Left", m, m),
                TargetData("Top-Center", 0.5, m),
                TargetData("Top-Right", 1 - m, m),
                TargetData("Center-Left", m, 0.5),
                TargetData("Center-Right", 1 - m, 0.5),
                TargetData("Bottom-Left", m, 1 - m),
                TargetData("Bottom-Center", 0.5, 1 - m),
                TargetData("Bottom-Right", 1 - m, 1 - m),
            ]

    def run(self):
        self._draw_intro()
        self.root.mainloop()

    def quit(self):
        self.root.destroy()

    def _draw_intro(self):
        self.canvas.delete("all")
        cx, cy = self.screen_w / 2, self.screen_h / 2

        self.canvas.create_text(
            cx, cy - 120,
            text="IRIS Gaze Calibration",
            font=("SF Pro Display", 36, "bold"),
            fill=TARGET_COLOR,
        )

        # Check if IRIS is running
        nose = read_raw_nose()
        if nose is None:
            status = "IRIS not detected — make sure it's running"
            status_color = TARGET_ACTIVE
        else:
            status = f"IRIS connected — raw nose: ({nose[0]:.4f}, {nose[1]:.4f})"
            status_color = TARGET_COLOR

        self.canvas.create_text(
            cx, cy - 50,
            text=status,
            font=("SF Pro Display", 16),
            fill=status_color,
        )

        instructions = [
            f"{'Quick' if self.mode == 'quick' else 'Full'} calibration: {len(self.targets)} points",
            f"Look at each target for {COLLECT_TIME:.0f}s — keep your head still",
            "",
            "Press SPACE to begin, ESC to cancel",
        ]
        for i, line in enumerate(instructions):
            self.canvas.create_text(
                cx, cy + 20 + i * 30,
                text=line,
                font=("SF Pro Display", 14),
                fill=TEXT_COLOR,
            )

        # Show current calibration if exists
        if os.path.exists(CALIBRATION_FILE):
            try:
                content = Path(CALIBRATION_FILE).read_text()
                self.canvas.create_text(
                    cx, cy + 160,
                    text=f"Current calibration: {content.strip()}",
                    font=("SF Mono", 11),
                    fill="#666666",
                )
            except Exception:
                pass

        self.root.bind("<space>", lambda e: self._start_calibration())

        # Keep refreshing IRIS status
        if not self.collecting and self.phase == "intro":
            self.root.after(500, self._refresh_intro_status)

    def _refresh_intro_status(self):
        if self.phase == "intro":
            self._draw_intro()

    def _start_calibration(self):
        self.root.unbind("<space>")

        # Pre-check: verify IRIS data is live and consistent
        readings = []
        for _ in range(5):
            nose = read_raw_nose()
            if nose:
                readings.append(nose)
            time.sleep(0.1)

        if len(readings) < 3:
            self._show_error("Cannot read IRIS data. Make sure IRIS is running.")
            return

        # Verify values are changing (not stale file)
        raw_xs = [r[0] for r in readings]
        if max(raw_xs) - min(raw_xs) < 0.0001 and len(set(raw_xs)) == 1:
            self._show_error("IRIS data appears stale (not updating). Restart IRIS.")
            return

        # Log baseline
        avg_x = sum(r[0] for r in readings) / len(readings)
        avg_y = sum(r[1] for r in readings) / len(readings)
        print(f"Calibration baseline: raw_x={avg_x:.4f}, raw_y={avg_y:.4f}")

        self.current_target_idx = 0
        self._show_target()

    def _show_target(self):
        if self.current_target_idx >= len(self.targets):
            self._compute_and_show_results()
            return

        target = self.targets[self.current_target_idx]
        self.phase = "settling"
        self.phase_start = time.time()
        self.collecting = False

        self._draw_target_screen(target)
        self._poll_loop()

    def _draw_target_screen(self, target: TargetData):
        self.canvas.delete("all")

        tx = target.screen_x * self.screen_w
        ty = target.screen_y * self.screen_h

        # Draw all target positions as dim dots
        for t in self.targets:
            px = t.screen_x * self.screen_w
            py = t.screen_y * self.screen_h
            color = "#222222" if t != target else None
            if color:
                self.canvas.create_oval(
                    px - 5, py - 5, px + 5, py + 5,
                    fill=color, outline=color,
                )

        # Draw active target
        if self.phase == "settling":
            color = "#ffaa00"
            label = "Focus here..."
        else:
            color = TARGET_ACTIVE
            label = "Collecting..."

        # Outer ring
        self.canvas.create_oval(
            tx - TARGET_RADIUS, ty - TARGET_RADIUS,
            tx + TARGET_RADIUS, ty + TARGET_RADIUS,
            outline=color, width=2,
        )
        # Inner dot
        self.canvas.create_oval(
            tx - TARGET_INNER, ty - TARGET_INNER,
            tx + TARGET_INNER, ty + TARGET_INNER,
            fill=color, outline=color,
        )
        # Crosshair lines
        self.canvas.create_line(tx - TARGET_RADIUS - 8, ty, tx - TARGET_RADIUS + 4, ty, fill=color, width=1)
        self.canvas.create_line(tx + TARGET_RADIUS - 4, ty, tx + TARGET_RADIUS + 8, ty, fill=color, width=1)
        self.canvas.create_line(tx, ty - TARGET_RADIUS - 8, tx, ty - TARGET_RADIUS + 4, fill=color, width=1)
        self.canvas.create_line(tx, ty + TARGET_RADIUS - 4, tx, ty + TARGET_RADIUS + 8, fill=color, width=1)

        # Progress and info
        progress_idx = self.current_target_idx + 1
        total = len(self.targets)
        self.canvas.create_text(
            self.screen_w / 2, 30,
            text=f"Point {progress_idx}/{total}: {target.name}",
            font=("SF Pro Display", 16, "bold"),
            fill=TEXT_COLOR,
        )
        self.canvas.create_text(
            self.screen_w / 2, 55,
            text=label,
            font=("SF Pro Display", 13),
            fill=color,
        )

        # Progress bar
        elapsed = time.time() - self.phase_start
        if self.phase == "settling":
            progress = min(elapsed / SETTLE_TIME, 1.0)
            bar_color = "#ffaa00"
        else:
            progress = min(elapsed / COLLECT_TIME, 1.0)
            bar_color = TARGET_ACTIVE

        bar_w = 200
        bar_h = 4
        bar_x = self.screen_w / 2 - bar_w / 2
        bar_y = 75
        self.canvas.create_rectangle(bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, fill="#333333", outline="")
        self.canvas.create_rectangle(bar_x, bar_y, bar_x + bar_w * progress, bar_y + bar_h, fill=bar_color, outline="")

        # Show live data
        nose = read_raw_nose()
        if nose:
            self.canvas.create_text(
                self.screen_w / 2, self.screen_h - 40,
                text=f"Raw: ({nose[0]:.4f}, {nose[1]:.4f})  EMA: ({nose[2]:.4f}, {nose[3]:.4f})  Samples: {len(target.samples)}",
                font=("SF Mono", 11),
                fill="#555555",
            )

    def _poll_loop(self):
        if self.done:
            return
        if self.current_target_idx >= len(self.targets):
            return

        target = self.targets[self.current_target_idx]
        elapsed = time.time() - self.phase_start

        if self.phase == "settling":
            if elapsed >= SETTLE_TIME:
                self.phase = "collecting"
                self.phase_start = time.time()
            self._draw_target_screen(target)
            self.root.after(POLL_INTERVAL, self._poll_loop)
            return

        if self.phase == "collecting":
            # Read and store sample
            nose = read_raw_nose()
            if nose:
                target.samples.append(Sample(
                    raw_x=nose[0], raw_y=nose[1],
                    ema_x=nose[2], ema_y=nose[3],
                    timestamp=time.time(),
                ))

            if elapsed >= COLLECT_TIME:
                # Move to next target
                self.current_target_idx += 1
                self._show_target()
                return

            self._draw_target_screen(target)
            self.root.after(POLL_INTERVAL, self._poll_loop)

    def _compute_and_show_results(self):
        self.done = True
        self.canvas.delete("all")

        # ── Compute calibration from collected data ──
        # The Rust tracker uses nose.x for horizontal (INVERTED: look right = nose moves left in camera)
        # and forehead.y for vertical.
        # We need to find the nose_x range and nose_y range that map to the full screen.

        # Collect per-target statistics
        valid_targets = [t for t in self.targets if len(t.samples) >= 10]
        if len(valid_targets) < 3:
            self._show_error("Not enough data collected. Make sure IRIS is running.")
            return

        # Group by screen position
        left_targets = [t for t in valid_targets if t.screen_x < 0.3]
        right_targets = [t for t in valid_targets if t.screen_x > 0.7]
        top_targets = [t for t in valid_targets if t.screen_y < 0.3]
        bottom_targets = [t for t in valid_targets if t.screen_y > 0.7]
        center_targets = [t for t in valid_targets if 0.3 <= t.screen_x <= 0.7 and 0.3 <= t.screen_y <= 0.7]

        # For horizontal: looking LEFT -> high nose_x, looking RIGHT -> low nose_x (camera mirror)
        # So left screen edge = high nose_x, right screen edge = low nose_x
        # nose_x_min corresponds to looking RIGHT (right screen edge)
        # nose_x_max corresponds to looking LEFT (left screen edge)

        all_raw_x = []
        all_raw_y = []
        screen_x_vs_nose_x = []  # (screen_x, median_nose_x)
        screen_y_vs_nose_y = []  # (screen_y, median_nose_y)

        for t in valid_targets:
            mx = t.median_raw_x
            my = t.median_raw_y
            if mx is not None and my is not None:
                all_raw_x.append(mx)
                all_raw_y.append(my)
                screen_x_vs_nose_x.append((t.screen_x, mx))
                screen_y_vs_nose_y.append((t.screen_y, my))

        # Find the nose ranges
        # For X: we need to find nose_x when looking at screen edges
        # Camera is mirrored: looking at left screen edge -> nose points right in camera -> HIGH nose_x
        #                      looking at right screen edge -> nose points left in camera -> LOW nose_x

        # Use linear regression to find the mapping
        # screen_x = 1 - (nose_x - nose_x_min) / (nose_x_max - nose_x_min)
        # This means: nose_x_min = nose_x when screen_x = 1 (right edge)
        #             nose_x_max = nose_x when screen_x = 0 (left edge)

        # Simple approach: use the observed range with some extrapolation
        if right_targets and left_targets:
            # We have both edges
            nose_x_at_right = statistics.median(s.raw_x for t in right_targets for s in t.samples)
            nose_x_at_left = statistics.median(s.raw_x for t in left_targets for s in t.samples)
            # Right screen = low nose_x, Left screen = high nose_x (camera mirror)
            nose_x_min = min(nose_x_at_right, nose_x_at_left)
            nose_x_max = max(nose_x_at_right, nose_x_at_left)
        else:
            # Fallback: use observed min/max
            nose_x_min = min(all_raw_x)
            nose_x_max = max(all_raw_x)

        if top_targets and bottom_targets:
            nose_y_at_top = statistics.median(s.raw_y for t in top_targets for s in t.samples)
            nose_y_at_bottom = statistics.median(s.raw_y for t in bottom_targets for s in t.samples)
            nose_y_min = min(nose_y_at_top, nose_y_at_bottom)
            nose_y_max = max(nose_y_at_top, nose_y_at_bottom)
        else:
            nose_y_min = min(all_raw_y)
            nose_y_max = max(all_raw_y)

        # Add padding to make edges easier to reach (15% on each side)
        x_range = nose_x_max - nose_x_min
        y_range = nose_y_max - nose_y_min
        x_pad = x_range * 0.15
        y_pad = y_range * 0.15
        nose_x_min -= x_pad
        nose_x_max += x_pad
        nose_y_min -= y_pad
        nose_y_max += y_pad

        # Compute optimal reach gain
        # The gain expands the normalized range around center.
        # If the user could barely reach edges, we need higher gain.
        # If they overshot, lower gain.
        # Target: the margin targets should map to ~margin normalized position

        # Check how well the center maps
        center_nose_x = None
        center_nose_y = None
        if center_targets:
            center_nose_x = statistics.median(s.raw_x for t in center_targets for s in t.samples)
            center_nose_y = statistics.median(s.raw_y for t in center_targets for s in t.samples)

        # Compute per-axis jitter (standard deviation)
        all_stds_x = [t.std_raw_x for t in valid_targets if t.std_raw_x > 0]
        all_stds_y = [t.std_raw_y for t in valid_targets if t.std_raw_y > 0]
        avg_jitter_x = statistics.mean(all_stds_x) if all_stds_x else 0
        avg_jitter_y = statistics.mean(all_stds_y) if all_stds_y else 0

        # Store result
        self.calibration_result = {
            "nose_x_min": nose_x_min,
            "nose_x_max": nose_x_max,
            "nose_y_min": nose_y_min,
            "nose_y_max": nose_y_max,
            "x_range": x_range,
            "y_range": y_range,
            "center_nose_x": center_nose_x,
            "center_nose_y": center_nose_y,
            "avg_jitter_x": avg_jitter_x,
            "avg_jitter_y": avg_jitter_y,
            "targets": {t.name: {
                "screen": (t.screen_x, t.screen_y),
                "nose_median": (t.median_raw_x, t.median_raw_y),
                "nose_std": (t.std_raw_x, t.std_raw_y),
                "samples": len(t.samples),
            } for t in valid_targets},
        }

        self._draw_results()

    def _draw_results(self):
        self.canvas.delete("all")
        r = self.calibration_result
        cx, cy = self.screen_w / 2, 60

        self.canvas.create_text(cx, cy, text="Calibration Results",
                                font=("SF Pro Display", 30, "bold"), fill=TARGET_COLOR)

        # Draw the nose position map
        map_size = 300
        map_x = self.screen_w / 2 - map_size / 2
        map_y = 110
        self.canvas.create_rectangle(map_x, map_y, map_x + map_size, map_y + map_size,
                                     outline="#333333", width=1)
        self.canvas.create_text(map_x + map_size / 2, map_y - 12,
                                text="Nose Position Map (raw)", font=("SF Mono", 10), fill="#666666")

        # Find plot bounds
        all_nx = []
        all_ny = []
        for name, td in r["targets"].items():
            if td["nose_median"][0] is not None:
                all_nx.append(td["nose_median"][0])
                all_ny.append(td["nose_median"][1])

        if all_nx and all_ny:
            plot_x_min = min(all_nx) - 0.01
            plot_x_max = max(all_nx) + 0.01
            plot_y_min = min(all_ny) - 0.01
            plot_y_max = max(all_ny) + 0.01

            for name, td in r["targets"].items():
                nx, ny = td["nose_median"]
                if nx is None:
                    continue
                # Map to plot coords
                px = map_x + (nx - plot_x_min) / (plot_x_max - plot_x_min) * map_size
                py = map_y + (ny - plot_y_min) / (plot_y_max - plot_y_min) * map_size
                sx, sy = td["screen"]
                # Color by screen position
                cr = int(sx * 255)
                cg = int((1 - sy) * 255)
                cb = 100
                color = f"#{cr:02x}{cg:02x}{cb:02x}"
                self.canvas.create_oval(px - 6, py - 6, px + 6, py + 6, fill=color, outline="white", width=1)
                self.canvas.create_text(px, py + 14, text=name[:3], font=("SF Mono", 8), fill="#999999")

        # Stats table
        ty = map_y + map_size + 30
        stats = [
            f"Nose X range: {r['nose_x_min']:.4f} — {r['nose_x_max']:.4f}  (span: {r['x_range']:.4f})",
            f"Nose Y range: {r['nose_y_min']:.4f} — {r['nose_y_max']:.4f}  (span: {r['y_range']:.4f})",
            f"Avg jitter X: {r['avg_jitter_x']:.5f}   Y: {r['avg_jitter_y']:.5f}",
        ]
        if r["center_nose_x"] is not None:
            stats.append(f"Center nose:  ({r['center_nose_x']:.4f}, {r['center_nose_y']:.4f})")

        for i, line in enumerate(stats):
            self.canvas.create_text(cx, ty + i * 24, text=line,
                                    font=("SF Mono", 13), fill=TEXT_COLOR)

        # Per-target details
        ty += len(stats) * 24 + 20
        self.canvas.create_text(cx, ty, text="Per-target details:",
                                font=("SF Pro Display", 14, "bold"), fill=ACCENT_COLOR)
        ty += 25
        for name, td in r["targets"].items():
            nx, ny = td["nose_median"]
            sx_std, sy_std = td["nose_std"]
            line = f"{name:15s}  nose=({nx:.4f}, {ny:.4f})  std=({sx_std:.5f}, {sy_std:.5f})  n={td['samples']}"
            self.canvas.create_text(cx, ty, text=line, font=("SF Mono", 11), fill="#999999")
            ty += 20

        # Action buttons
        ty += 20
        self.canvas.create_text(cx, ty, text="Press A to apply calibration, R to redo, ESC to cancel",
                                font=("SF Pro Display", 15, "bold"), fill=TARGET_COLOR)

        self.root.bind("<a>", lambda e: self._apply_calibration())
        self.root.bind("<r>", lambda e: self._redo())

    def _apply_calibration(self):
        r = self.calibration_result
        if not r:
            return

        # Write calibration file (for gaze.rs GazeEstimator)
        cal_content = (
            f"# IRIS Calibration — generated {time.strftime('%Y-%m-%d %H:%M:%S')}\n"
            f"# Collected from {sum(t['samples'] for t in r['targets'].values())} samples across {len(r['targets'])} targets\n"
            f"nose_x_min, nose_x_max = {r['nose_x_min']:.6f}, {r['nose_x_max']:.6f}\n"
            f"nose_y_min, nose_y_max = {r['nose_y_min']:.6f}, {r['nose_y_max']:.6f}\n"
        )
        Path(CALIBRATION_FILE).write_text(cal_content)

        # Persist a copy in the user's home so values survive reboots
        home_cal_path = Path.home() / ".iris_calibration.txt"
        try:
            home_cal_path.write_text(cal_content)
        except Exception as e:
            print(f"Warning: could not write {home_cal_path}: {e}")

        # Also save full JSON for reference
        json_path = "/tmp/iris_calibration_data.json"
        # Convert for JSON serialization
        json_data = {
            "timestamp": time.strftime('%Y-%m-%d %H:%M:%S'),
            "nose_x_min": r["nose_x_min"],
            "nose_x_max": r["nose_x_max"],
            "nose_y_min": r["nose_y_min"],
            "nose_y_max": r["nose_y_max"],
            "x_range": r["x_range"],
            "y_range": r["y_range"],
            "avg_jitter_x": r["avg_jitter_x"],
            "avg_jitter_y": r["avg_jitter_y"],
        }
        Path(json_path).write_text(json.dumps(json_data, indent=2))

        self.canvas.delete("all")
        cx, cy = self.screen_w / 2, self.screen_h / 2
        self.canvas.create_text(cx, cy - 40, text="Calibration Applied!",
                                font=("SF Pro Display", 30, "bold"), fill=TARGET_COLOR)
        self.canvas.create_text(cx, cy + 10,
                                text=f"Written to {CALIBRATION_FILE}",
                                font=("SF Mono", 13), fill=TEXT_COLOR)
        self.canvas.create_text(cx, cy + 40,
                                text=f"Full data saved to {json_path}",
                                font=("SF Mono", 13), fill="#666666")
        self.canvas.create_text(cx, cy + 80,
                                text="IRIS will pick up the new calibration within ~2 seconds.",
                                font=("SF Pro Display", 14), fill=ACCENT_COLOR)
        self.canvas.create_text(cx, cy + 120,
                                text="Press T to test live, ESC to exit",
                                font=("SF Pro Display", 14), fill=TEXT_COLOR)

        self.root.bind("<t>", lambda e: self._start_live_test())

    def _redo(self):
        self.root.unbind("<a>")
        self.root.unbind("<r>")
        for t in self.targets:
            t.samples.clear()
        self.current_target_idx = -1
        self.done = False
        self.phase = "intro"
        self._draw_intro()

    def _start_live_test(self):
        """Show live gaze position on screen to verify calibration."""
        self.root.unbind("<t>")
        self.canvas.delete("all")
        self._live_test_loop()

    def _live_test_loop(self):
        self.canvas.delete("all")

        # Draw grid
        for i in range(1, 4):
            x = self.screen_w * i / 4
            self.canvas.create_line(x, 0, x, self.screen_h, fill="#1a1a1a", width=1)
        for i in range(1, 4):
            y = self.screen_h * i / 4
            self.canvas.create_line(0, y, self.screen_w, y, fill="#1a1a1a", width=1)

        # Draw target corners
        m = MARGIN
        for sx, sy in [(m, m), (1-m, m), (m, 1-m), (1-m, 1-m), (0.5, 0.5)]:
            px = sx * self.screen_w
            py = sy * self.screen_h
            self.canvas.create_oval(px - 8, py - 8, px + 8, py + 8,
                                    outline="#333333", width=1)

        nose = read_raw_nose()
        if nose:
            raw_x, raw_y, ema_x, ema_y = nose
            r = self.calibration_result
            if r:
                # Compute where the gaze would map (mimicking Rust tracker logic)
                # Horizontal is INVERTED
                h_norm = 1.0 - (ema_x - r["nose_x_min"]) / (r["nose_x_max"] - r["nose_x_min"])
                v_norm = (ema_y - r["nose_y_min"]) / (r["nose_y_max"] - r["nose_y_min"])

                # Apply gain (default 1.3 from lib.rs)
                gain = 1.3
                h_norm = 0.5 + (h_norm - 0.5) * gain
                v_norm = 0.5 + (v_norm - 0.5) * gain

                h_norm = max(0, min(1, h_norm))
                v_norm = max(0, min(1, v_norm))

                gaze_x = h_norm * self.screen_w
                gaze_y = v_norm * self.screen_h

                # Draw gaze point
                self.canvas.create_oval(gaze_x - 15, gaze_y - 15, gaze_x + 15, gaze_y + 15,
                                        outline=TARGET_COLOR, width=2)
                self.canvas.create_oval(gaze_x - 3, gaze_y - 3, gaze_x + 3, gaze_y + 3,
                                        fill=TARGET_COLOR, outline=TARGET_COLOR)

            self.canvas.create_text(
                self.screen_w / 2, 30,
                text=f"Live Test — Raw: ({raw_x:.4f}, {raw_y:.4f})  EMA: ({ema_x:.4f}, {ema_y:.4f})",
                font=("SF Mono", 12), fill=TEXT_COLOR,
            )
        else:
            self.canvas.create_text(
                self.screen_w / 2, 30,
                text="No IRIS data — is it running?",
                font=("SF Mono", 12), fill=TARGET_ACTIVE,
            )

        self.canvas.create_text(
            self.screen_w / 2, self.screen_h - 20,
            text="Press ESC to exit",
            font=("SF Pro Display", 12), fill="#555555",
        )

        self.root.after(POLL_INTERVAL, self._live_test_loop)

    def _show_error(self, msg):
        self.canvas.delete("all")
        cx, cy = self.screen_w / 2, self.screen_h / 2
        self.canvas.create_text(cx, cy, text=msg,
                                font=("SF Pro Display", 18), fill=TARGET_ACTIVE)
        self.canvas.create_text(cx, cy + 40, text="Press ESC to exit",
                                font=("SF Pro Display", 14), fill=TEXT_COLOR)


class LiveTestApp:
    """Standalone live test mode — shows gaze position using current calibration."""

    def __init__(self):
        self.root = tk.Tk()
        self.root.title("IRIS Live Test")
        self.root.configure(bg=BG_COLOR)
        self.root.attributes("-fullscreen", True)
        self.root.attributes("-topmost", True)
        self.root.update()

        self.screen_w = self.root.winfo_screenwidth()
        self.screen_h = self.root.winfo_screenheight()

        self.canvas = tk.Canvas(self.root, width=self.screen_w, height=self.screen_h,
                                bg=BG_COLOR, highlightthickness=0)
        self.canvas.pack()
        self.root.bind("<Escape>", lambda e: self.root.destroy())
        self.root.bind("<q>", lambda e: self.root.destroy())

        # Load calibration
        self.cal = self._load_calibration()
        self._loop()

    def _load_calibration(self):
        paths = [Path(CALIBRATION_FILE), Path.home() / ".iris_calibration.txt"]
        for p in paths:
            try:
                content = p.read_text()
            except Exception:
                continue

            cal = {}
            for line in content.splitlines():
                if line.startswith("nose_x_min"):
                    parts = line.split("=")[1].split(",")
                    cal["nose_x_min"] = float(parts[0].strip())
                    cal["nose_x_max"] = float(parts[1].strip())
                elif line.startswith("nose_y_min"):
                    parts = line.split("=")[1].split(",")
                    cal["nose_y_min"] = float(parts[0].strip())
                    cal["nose_y_max"] = float(parts[1].strip())
            if len(cal) == 4:
                return cal
        return None

    def _loop(self):
        self.canvas.delete("all")

        # Grid
        for i in range(1, 4):
            x = self.screen_w * i / 4
            self.canvas.create_line(x, 0, x, self.screen_h, fill="#1a1a1a")
        for i in range(1, 4):
            y = self.screen_h * i / 4
            self.canvas.create_line(0, y, self.screen_w, y, fill="#1a1a1a")

        # Target positions
        m = MARGIN
        for sx, sy in [(m, m), (0.5, m), (1-m, m), (m, 0.5), (0.5, 0.5),
                        (1-m, 0.5), (m, 1-m), (0.5, 1-m), (1-m, 1-m)]:
            px, py = sx * self.screen_w, sy * self.screen_h
            self.canvas.create_oval(px-6, py-6, px+6, py+6, outline="#333333", width=1)
            self.canvas.create_oval(px-2, py-2, px+2, py+2, fill="#333333")

        nose = read_raw_nose()
        if nose and self.cal:
            raw_x, raw_y, ema_x, ema_y = nose
            c = self.cal
            h_norm = 1.0 - (ema_x - c["nose_x_min"]) / (c["nose_x_max"] - c["nose_x_min"])
            v_norm = (ema_y - c["nose_y_min"]) / (c["nose_y_max"] - c["nose_y_min"])
            gain = 1.3
            h_norm = 0.5 + (h_norm - 0.5) * gain
            v_norm = 0.5 + (v_norm - 0.5) * gain
            h_norm = max(0, min(1, h_norm))
            v_norm = max(0, min(1, v_norm))

            gx = h_norm * self.screen_w
            gy = v_norm * self.screen_h

            self.canvas.create_oval(gx-20, gy-20, gx+20, gy+20, outline=TARGET_COLOR, width=2)
            self.canvas.create_oval(gx-4, gy-4, gx+4, gy+4, fill=TARGET_COLOR)

            self.canvas.create_text(self.screen_w/2, 25,
                text=f"Raw: ({raw_x:.4f}, {raw_y:.4f})  Norm: ({h_norm:.3f}, {v_norm:.3f})  Screen: ({gx:.0f}, {gy:.0f})",
                font=("SF Mono", 12), fill=TEXT_COLOR)
        elif nose and not self.cal:
            self.canvas.create_text(self.screen_w/2, self.screen_h/2,
                text="No calibration found. Run: python3 calibrate.py",
                font=("SF Pro Display", 18), fill=TARGET_ACTIVE)
        else:
            self.canvas.create_text(self.screen_w/2, self.screen_h/2,
                text="IRIS not running — no data at /tmp/iris_raw_nose.txt",
                font=("SF Pro Display", 18), fill=TARGET_ACTIVE)

        self.canvas.create_text(self.screen_w/2, self.screen_h - 20,
            text="ESC to exit", font=("SF Pro Display", 11), fill="#444444")

        self.root.after(POLL_INTERVAL, self._loop)

    def run(self):
        self.root.mainloop()


def main():
    mode = "full"
    if "--quick" in sys.argv:
        mode = "quick"
    elif "--test" in sys.argv:
        app = LiveTestApp()
        app.run()
        return

    app = CalibrationApp(mode=mode)
    app.run()


if __name__ == "__main__":
    main()
