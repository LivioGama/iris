#!/usr/bin/env python3
"""
Detailed memory profiler for IRIS
Analyzes memory usage by category and identifies potential leaks
"""

import subprocess
import time
import sys
from datetime import datetime

def get_iris_pid():
    """Find IRIS process ID"""
    try:
        result = subprocess.run(['pgrep', '-x', 'IRIS'],
                              capture_output=True, text=True)
        pids = result.stdout.strip().split('\n')
        return pids[0] if pids and pids[0] else None
    except:
        return None

def get_memory_regions(pid):
    """Get detailed memory breakdown using vmmap"""
    try:
        result = subprocess.run(['vmmap', '-summary', pid],
                              capture_output=True, text=True, timeout=5)
        return result.stdoutI think you can remove the turn complete debug stuff, it's useless. But I would like you to put at the very bottom, like a small console transparent text about what you are doing so I can have a bit of visibility.
    except:
        return None

def parse_vmmap_summary(output):
    """Parse vmmap summary output"""
    regions = {}
    in_summary = False

    for line in output.split('\n'):
        if 'REGION TYPE' in line:
            in_summary = True
            continue
        if in_summary and line.strip():
            parts = line.split()
            if len(parts) >= 2:
                region_name = parts[0]
                size_str = parts[1]
                # Parse size (e.g., "123.4M" or "1.2G")
                if 'K' in size_str:
                    size_mb = float(size_str.replace('K', '')) / 1024
                elif 'M' in size_str:
                    size_mb = float(size_str.replace('M', ''))
                elif 'G' in size_str:
                    size_mb = float(size_str.replace('G', '')) * 1024
                else:
                    size_mb = 0
                regions[region_name] = size_mb

    return regions

def main():
    print("🔬 IRIS Memory Profiler")
    print("=" * 80)

    # Wait for IRIS
    print("Waiting for IRIS to start...")
    while True:
        pid = get_iris_pid()
        if pid:
            print(f"✅ Found IRIS process: PID {pid}\n")
            break
        time.sleep(1)

    log_file = "/tmp/iris_memory_profile.log"
    print(f"Logging to: {log_file}")
    print("Press Ctrl+C to stop\n")

    with open(log_file, 'w') as f:
        f.write(f"IRIS Memory Profile - Started at {datetime.now()}\n")
        f.write("=" * 80 + "\n\n")

        sample_count = 0

        try:
            while True:
                pid = get_iris_pid()
                if not pid:
                    print("❌ IRIS process not found")
                    break

                sample_count += 1
                timestamp = datetime.now().strftime("%H:%M:%S")

                # Get memory regions
                vmmap_output = get_memory_regions(pid)
                if vmmap_output:
                    regions = parse_vmmap_summary(vmmap_output)

                    # Calculate totals
                    total_mb = sum(regions.values())

                    # Print summary
                    print(f"\n[{timestamp}] Sample #{sample_count}")
                    print(f"Total Memory: {total_mb:.1f} MB")

                    # Top memory consumers
                    sorted_regions = sorted(regions.items(),
                                          key=lambda x: x[1], reverse=True)[:10]

                    print("\nTop 10 Memory Regions:")
                    for name, size in sorted_regions:
                        print(f"  {name:30s} {size:8.1f} MB")

                    # Log to file
                    f.write(f"\n[{timestamp}] Sample #{sample_count}\n")
                    f.write(f"Total: {total_mb:.1f} MB\n")
                    for name, size in sorted_regions:
                        f.write(f"  {name:30s} {size:8.1f} MB\n")
                    f.flush()

                time.sleep(5)  # Sample every 5 seconds

        except KeyboardInterrupt:
            print("\n\n✅ Profiling stopped")
            f.write(f"\n\nStopped at {datetime.now()}\n")

if __name__ == "__main__":
    main()
