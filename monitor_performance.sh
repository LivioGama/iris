#!/bin/bash

# Performance monitoring script for IRIS
# Measures CPU, memory, threads, and file descriptors

LOG_FILE="/tmp/iris_performance.log"
INTERVAL=2  # Sample every 2 seconds

echo "🔍 IRIS Performance Monitor" | tee "$LOG_FILE"
echo "Started at $(date)" | tee -a "$LOG_FILE"
echo "Sampling every ${INTERVAL}s" | tee -a "$LOG_FILE"
echo "Log file: $LOG_FILE"
echo "Press Ctrl+C to stop"
echo ""

# Find IRIS process
get_iris_pid() {
    pgrep -x "IRIS" | head -1
}

# Wait for IRIS to start
echo "Waiting for IRIS to start..."
while true; do
    PID=$(get_iris_pid)
    if [ -n "$PID" ]; then
        echo "✅ Found IRIS process: PID $PID"
        break
    fi
    sleep 1
done

# Header
echo "" | tee -a "$LOG_FILE"
printf "%-8s %-10s %-10s %-8s %-8s %-10s %-10s\n" \
    "TIME" "CPU%" "MEM(MB)" "THREADS" "FDs" "VSIZE(GB)" "RSIZE(GB)" | tee -a "$LOG_FILE"
echo "--------------------------------------------------------------------------------" | tee -a "$LOG_FILE"

# Monitor loop
while true; do
    PID=$(get_iris_pid)
    
    if [ -z "$PID" ]; then
        echo "❌ IRIS process not found - exiting" | tee -a "$LOG_FILE"
        exit 1
    fi
    
    # Get process stats using ps
    STATS=$(ps -p "$PID" -o %cpu,rss,vsz 2>/dev/null | tail -1)
    
    if [ -z "$STATS" ]; then
        echo "❌ Failed to get process stats" | tee -a "$LOG_FILE"
        exit 1
    fi
    
    CPU=$(echo "$STATS" | awk '{print $1}')
    RSS_KB=$(echo "$STATS" | awk '{print $2}')
    VSZ_KB=$(echo "$STATS" | awk '{print $3}')
    
    # Convert to MB/GB
    MEM_MB=$(echo "scale=1; $RSS_KB / 1024" | bc)
    VSIZE_GB=$(echo "scale=2; $VSZ_KB / 1024 / 1024" | bc)
    RSIZE_GB=$(echo "scale=2; $RSS_KB / 1024 / 1024" | bc)
    
    # Count threads
    THREADS=$(ps -M -p "$PID" 2>/dev/null | wc -l)
    THREADS=$((THREADS - 1))  # Subtract header line
    
    # Count file descriptors
    FDS=$(lsof -p "$PID" 2>/dev/null | wc -l)
    FDS=$((FDS - 1))  # Subtract header line
    
    # Current time
    TIME=$(date +%H:%M:%S)
    
    # Print stats
    printf "%-8s %-10s %-10s %-8s %-8s %-10s %-10s\n" \
        "$TIME" "$CPU" "$MEM_MB" "$THREADS" "$FDS" "$VSIZE_GB" "$RSIZE_GB" | tee -a "$LOG_FILE"
    
    sleep "$INTERVAL"
done
