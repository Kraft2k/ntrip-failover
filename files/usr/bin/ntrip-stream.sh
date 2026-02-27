#!/bin/sh
# NTRIP Failover Watchdog for OpenWrt
# Author: Alexey Kravchenko & Gemini AI
# Year: 2026

. /lib/functions.sh

TAG="ntrip-failover"
TEMP_FILE="/tmp/ntrip_corrections.log"
IDLE_LIMIT=20
CHECK_INTERVAL=5
MAX_LOG_SIZE=1048576 # 1MB

log() { logger -t "$TAG" "$1"; }

# Cleanup on start
killall -9 ntripclient.exe 2>/dev/null

# Load configuration
config_load 'ntrip'
config_get SERVER      'client' 'server'
config_get PORT        'client' 'port'
config_get MODE        'client' 'mode'
config_get USER        'client' 'user'
config_get PASSWORD    'client' 'password'
config_get SERIAL_PORT 'client' 'serial_port' '/dev/ttyS0'

while true; do
    # Fetch mountpoints from UCI
    MOUNTS=$(uci -q get ntrip.client.mountpoint | tr ' ' '\n')

    for m in $MOUNTS; do
        m_clean=$(echo "$m" | tr -d " \t\r\n")
        [ -z "$m_clean" ] && continue

        log "Connecting to: <$m_clean>..."
        > "$TEMP_FILE"

        # Start ntripclient and redirect both stdout and stderr to log
        /usr/bin/ntripclient.exe -s "$SERVER" -r "$PORT" -m "$m_clean" \
            -u "$USER" -p "$PASSWORD" -M "$MODE" 2>&1 | tee "$TEMP_FILE" > "$SERIAL_PORT" &
        
        CPID=$!
        sleep 3
        
        last_size=0
        idle=0

        while kill -0 $CPID 2>/dev/null; do
            sleep $CHECK_INTERVAL
            
            # Check for offline status (Sourcetable response)
            if grep -qi "SOURCETABLE" "$TEMP_FILE"; then
                log "Station $m_clean is OFFLINE. Switching..."
                kill -9 $CPID
                break
            fi

            # Log rotation (prevent RAM overflow)
            curr_size=$(ls -l "$TEMP_FILE" | awk '{print $5}')
            [ -z "$curr_size" ] && curr_size=0

            if [ "$curr_size" -gt "$MAX_LOG_SIZE" ]; then
                log "Log rotation: clearing $TEMP_FILE"
                > "$TEMP_FILE"
                curr_size=0
            fi

            # Data flow monitoring
            if [ "$curr_size" -le "$last_size" ]; then
                idle=$((idle + CHECK_INTERVAL))
                log "Idle on $m_clean: $idle/$IDLE_LIMIT sec"
            else
                idle=0
                last_size=$curr_size
            fi

            if [ "$idle" -ge "$IDLE_LIMIT" ]; then
                log "TIMEOUT on $m_clean. Moving to next station."
                kill -9 $CPID
                break
            fi
        done
        sleep 2
    done
done