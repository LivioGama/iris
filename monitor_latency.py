#!/usr/bin/env python3
"""
Voice Interaction Latency Monitor for IRIS
Tracks timing between voice events and Gemini responses
"""

import subprocess
import time
import re
from datetime import datetime
from collections import deque

def tail_log(log_file):
    """Tail a log file and yield new lines"""
    try:
        proc = subprocess.Popen(
            ['tail', '-f', '-n', '0', log_file],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        for line in iter(proc.stdout.readline, ''):
            if line:
                yield line.strip()
    except KeyboardInterrupt:
        proc.terminate()
        raise

def parse_timestamp(line):
    """Extract timestamp from log line if present"""
    # Look for HH:MM:SS pattern
    match = re.search(r'(\d{2}:\d{2}:\d{2})', line)
    if match:
        return match.group(1)
    return datetime.now().strftime("%H:%M:%S")

class LatencyTracker:
    def __init__(self):
        self.voice_start_time = None
        self.voice_end_time = None
        self.response_start_time = None
        self.response_end_time = None
        self.recent_latencies = deque(maxlen=10)
        
    def mark_voice_start(self, timestamp):
        self.voice_start_time = timestamp
        self.voice_end_time = None
        self.response_start_time = None
        self.response_end_time = None
        print(f"\n🎤 [{timestamp}] Voice START")
        
    def mark_voice_end(self, timestamp):
        self.voice_end_time = timestamp
        if self.voice_start_time:
            duration = self.time_diff(self.voice_start_time, timestamp)
            print(f"🔇 [{timestamp}] Voice END (spoke for {duration:.1f}s)")
    
    def mark_response_start(self, timestamp):
        self.response_start_time = timestamp
        if self.voice_end_time:
            latency = self.time_diff(self.voice_end_time, timestamp)
            print(f"🤖 [{timestamp}] Response START (latency: {latency:.2f}s)")
            self.recent_latencies.append(latency)
        elif self.voice_start_time:
            latency = self.time_diff(self.voice_start_time, timestamp)
            print(f"🤖 [{timestamp}] Response START (from voice start: {latency:.2f}s)")
    
    def mark_response_end(self, timestamp):
        self.response_end_time = timestamp
        if self.response_start_time:
            duration = self.time_diff(self.response_start_time, timestamp)
            print(f"✅ [{timestamp}] Response END (duration: {duration:.1f}s)")
            
            # Print full interaction summary
            if self.voice_start_time:
                total = self.time_diff(self.voice_start_time, timestamp)
                print(f"📊 Total interaction time: {total:.1f}s")
                
            # Print average latency
            if self.recent_latencies:
                avg = sum(self.recent_latencies) / len(self.recent_latencies)
                print(f"📈 Average response latency (last 10): {avg:.2f}s")
    
    def time_diff(self, start_str, end_str):
        """Calculate time difference in seconds between HH:MM:SS timestamps"""
        try:
            start = datetime.strptime(start_str, "%H:%M:%S")
            end = datetime.strptime(end_str, "%H:%M:%S")
            diff = (end - start).total_seconds()
            # Handle day rollover
            if diff < 0:
                diff += 86400
            return diff
        except:
            return 0.0

def main():
    print("🎯 IRIS Voice Latency Monitor")
    print("=" * 80)
    print("Monitoring voice interaction latency...")
    print("Press Ctrl+C to stop\n")
    
    log_file = "/tmp/iris_startup.log"
    output_file = "/tmp/iris_latency.log"
    
    tracker = LatencyTracker()
    
    with open(output_file, 'w') as f:
        f.write(f"IRIS Voice Latency Log - Started at {datetime.now()}\n")
        f.write("=" * 80 + "\n\n")
        
        try:
            for line in tail_log(log_file):
                timestamp = parse_timestamp(line)
                
                # Detect voice events
                if "Voice activity detected" in line or "🎤 Voice START" in line or "VAD: Voice detected" in line:
                    tracker.mark_voice_start(timestamp)
                    f.write(f"[{timestamp}] VOICE_START\n")
                    f.flush()
                    
                elif "Voice activity ended" in line or "🔇 Voice END" in line or "VAD: Silence detected" in line:
                    tracker.mark_voice_end(timestamp)
                    f.write(f"[{timestamp}] VOICE_END\n")
                    f.flush()
                
                # Detect Gemini response events
                elif "🤖" in line or "Gemini response" in line or "Model speaking" in line or "voiceAgentState = .modelSpeaking" in line:
                    tracker.mark_response_start(timestamp)
                    f.write(f"[{timestamp}] RESPONSE_START\n")
                    f.flush()
                    
                elif "Response complete" in line or "Model finished" in line or "voiceAgentState = .idle" in line:
                    tracker.mark_response_end(timestamp)
                    f.write(f"[{timestamp}] RESPONSE_END\n")
                    f.flush()
                
        except KeyboardInterrupt:
            print("\n\n✅ Latency monitoring stopped")
            f.write(f"\n\nStopped at {datetime.now()}\n")
            
            if tracker.recent_latencies:
                avg = sum(tracker.recent_latencies) / len(tracker.recent_latencies)
                summary = f"\n📊 Final Statistics:\n"
                summary += f"   Average response latency: {avg:.2f}s\n"
                summary += f"   Samples collected: {len(tracker.recent_latencies)}\n"
                print(summary)
                f.write(summary)

if __name__ == "__main__":
    main()
