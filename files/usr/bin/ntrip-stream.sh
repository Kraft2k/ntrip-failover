#!/bin/sh
# NTRIP Failover Watchdog (clean: truncate log without reconnect)
. /lib/functions.sh

TAG="ntrip-failover"

TEMP_FILE="/tmp/ntrip_corrections.log"
ERR_FIFO="/tmp/ntrip_err.fifo"

IDLE_LIMIT=20
CHECK_INTERVAL=5
MAX_LOG_SIZE=1048576  # 1 MB

LAST_RX_FILE="/tmp/ntrip_last_rx.ts"
OFFLINE_FLAG="/tmp/ntrip_offline.flag"

log() { logger -t "$TAG" "$1"; }

cleanup_fifos() {
  rm -f "$ERR_FIFO" "$OFFLINE_FLAG"
}

stop_all() {
  # Stop the NTRIP client (kill any running instances)
  killall -9 ntripclient.exe 2>/dev/null
}

# ====== start ======
stop_all
cleanup_fifos

config_load 'ntrip'
config_get SERVER      'client' 'server'
config_get PORT        'client' 'port'
config_get MODE        'client' 'mode'
config_get USER        'client' 'user'
config_get PASSWORD    'client' 'password'
config_get SERIAL_PORT 'client' 'serial_port' '/dev/ttyS0'

while true; do
  MOUNTS=$(uci -q get ntrip.client.mountpoint | tr ' ' '\n')

  for m in $MOUNTS; do
    m_clean=$(echo "$m" | tr -d " \t\r\n")
    [ -z "$m_clean" ] && continue

    cleanup_fifos
    : > "$TEMP_FILE"
    : > "$LAST_RX_FILE"
    echo "$(date +%s)" > "$LAST_RX_FILE"

    mkfifo "$ERR_FIFO" || {
      log "ERROR: cannot create fifo $ERR_FIFO"
      sleep 2
      continue
    }

    # --- Log siphon: reads stderr from FIFO, keeps the log file <= 1MB, and detects OFFLINE ---
    (
      bytes=0
      while IFS= read -r line; do
        # Append a single log line to the file
        printf '%s\n' "$line" >> "$TEMP_FILE"
        bytes=$((bytes + ${#line} + 1))

        # OFFLINE detection (server replies with SOURCETABLE instead of streaming data)
        echo "$line" | grep -qi "SOURCETABLE" && {
          echo 1 > "$OFFLINE_FLAG"
        }

        # Truncate the log without touching the NTRIP connection
        if [ "$bytes" -gt "$MAX_LOG_SIZE" ]; then
          : > "$TEMP_FILE"
          bytes=0
          log "Log truncated at 1MB (no reconnect)."
        fi
      done < "$ERR_FIFO"
    ) &
    SIPHON_PID=$!

    log "Connecting to: <$m_clean>..."
    # IMPORTANT: we assume RTCM goes to stdout, and logs go to stderr.
    /usr/bin/ntripclient.exe -s "$SERVER" -r "$PORT" -m "$m_clean" \
      -u "$USER" -p "$PASSWORD" -M "$MODE" \
      > "$SERIAL_PORT" 2> "$ERR_FIFO" &
    CPID=$!

    # Watchdog loop for this mountpoint
    while kill -0 "$CPID" 2>/dev/null; do
      sleep "$CHECK_INTERVAL"

      # OFFLINE -> switch to the next base station
      if [ -f "$OFFLINE_FLAG" ]; then
        log "OFFLINE: Station $m_clean. Switching..."
        kill -9 "$CPID" 2>/dev/null
        break
      fi

      # TIMEOUT using a "last activity" heuristic:
      # We treat "client is alive but hasn't written anything recently" as a bad state.
      # (If you want a strict byte-accurate timeout based on real RTCM bytes, we can add a data-forwarder.)
      last_rx=$(cat "$LAST_RX_FILE" 2>/dev/null)
      [ -z "$last_rx" ] && last_rx=$(date +%s)
      now=$(date +%s)
      idle=$((now - last_rx))

      if [ "$idle" -ge "$IDLE_LIMIT" ]; then
        log "TIMEOUT on $m_clean. Moving to next base..."
        kill -9 "$CPID" 2>/dev/null
        break
      fi

      # Update last_rx just because the process is alive (soft heuristic)
      echo "$now" > "$LAST_RX_FILE"
    done

    # Cleanup for this mountpoint
    kill -9 "$CPID" 2>/dev/null
    kill -9 "$SIPHON_PID" 2>/dev/null
    cleanup_fifos
    sleep 2
  done
done