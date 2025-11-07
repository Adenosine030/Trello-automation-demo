#!/usr/bin/env bash
# healthcheck.sh - simple server health monitor (fixed version)

# Config
LOGFILE="/var/log/healthcheck.log"
THRESHOLD_CPU=85
THRESHOLD_MEM=85
THRESHOLD_DISK=85
SLACK_WEBHOOK_URL=""

timestamp() { date +"%d-%m-%Y %H:%M:%S"; }

# --- CPU USAGE ---
# This works across Ubuntu, Amazon Linux, and Debian
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk -F'id,' -v prefix="$prefix" '{split($1, vs, ","); v=vs[length(vs)]; sub("%","",v); printf "%d", 100 - v}')
# Fallback if CPU_USAGE is empty
if [ -z "$CPU_USAGE" ]; then
  CPU_USAGE=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print int(usage)}')
fi

# --- MEMORY USAGE ---
MEM_USED=$(free | awk '/Mem/ {printf("%d", $3/$2 * 100)}')

# --- DISK USAGE ---
DISK_USED=$(df -h / | awk 'NR==2 {gsub("%",""); print int($5)}')

# --- LOGGING ---
MSG="$(timestamp) | CPU=${CPU_USAGE}% MEM=${MEM_USED}% DISK=${DISK_USED}%"
echo "$MSG" >> "$LOGFILE"

# --- ALERT FUNCTION ---
alert() {
  local text="$1"
  echo "$(timestamp) ALERT: $text" >> "$LOGFILE"
  if [ -n "$SLACK_WEBHOOK_URL" ]; then
    curl -s -X POST -H 'Content-type: application/json' \
      --data "{\"text\":\"$text\"}" "$SLACK_WEBHOOK_URL" >/dev/null 2>&1
  fi
}

# --- THRESHOLD CHECKS ---
if [ "$CPU_USAGE" -ge "$THRESHOLD_CPU" ]; then
  alert "High CPU usage: ${CPU_USAGE}%"
fi

if [ "$MEM_USED" -ge "$THRESHOLD_MEM" ]; then
  alert "High Memory usage: ${MEM_USED}%"
fi

if [ "$DISK_USED" -ge "$THRESHOLD_DISK" ]; then
  alert "Low Disk space: ${DISK_USED}% used"
fi

# Print summary for manual run
echo "$MSG"
