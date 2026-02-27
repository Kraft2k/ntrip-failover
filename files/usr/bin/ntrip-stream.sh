#!/bin/sh
# NTRIP Failover Watchdog Script
# Ensures continuous correction stream by switching between multiple mountpoints

. /lib/functions.sh

TAG="ntrip-failover"
TEMP_FILE="/tmp/ntrip_corrections.log"
IDLE_LIMIT=20
CHECK_INTERVAL=5
MAX_LOG_SIZE=1048576  # 1 MB threshold for log rotation

log() { logger -t "$TAG" "$1"; }

# 1. Initial cleanup: kill any orphan processes
killall -9 ntripclient.exe 2>/dev/null

# Load static configuration from UCI
config_load 'ntrip'
config_get SERVER      'client' 'server'
config_get PORT        'client' 'port'
config_get MODE        'client' 'mode'
config_get USER        'client' 'user'
config_get PASSWORD    'client' 'password'
config_get SERIAL_PORT 'client' 'serial_port' '/dev/ttyS0'

while true; do
    # 2. Dynamic mountpoint list: allows changes via UCI without restarting the service
    MOUNTS=$(uci -q get ntrip.client.mountpoint | tr ' ' '\n')

    for m in $MOUNTS; do
        m_clean=$(echo "$m" | tr -d " \t\r\n")
        [ -z "$m_clean" ] && continue

        log "Connecting to: <$m_clean>..."
        
        # Clear log file before new connection
        > "$TEMP_FILE"

        # Start ntripclient with error redirection (2>&1)
        /usr/bin/ntripclient.exe -s "$SERVER" -r "$PORT" -m "$m_clean" \
            -u "$USER" -p "$PASSWORD" -M "$MODE" 2>&1 | tee "$TEMP_FILE" > "$SERIAL_PORT" &
        
        CPID=$!
        sleep 3
        
        last_size=0
        idle=0

        while kill -0 $CPID 2>/dev/null; do
            sleep $CHECK_INTERVAL
            
            # Offline detection: Server returns SOURCETABLE when mountpoint is unavailable
            if grep -qi "SOURCETABLE" "$TEMP_FILE"; then
                log "OFFLINE: Station $m_clean. Switching..."
                kill -9 $CPID
                break
            fi

            # Log rotation: prevent RAM overflow in /tmp
            curr_size=$(ls -l "$TEMP_FILE" | awk '{print $5}')
            [ -z "$curr_size" ] && curr_size=0

            if [ "$curr_size" -gt "$MAX_LOG_SIZE" ]; then
                log "Log rotation: clearing $TEMP_FILE"
                > "$TEMP_FILE"
                # Reset size tracking to prevent false timeouts after truncation
                curr_size=0
                last_size=0
            fi

            # Data flow monitoring logic
            if [ "$curr_size" -le "$last_size" ]; then
                idle=$((idle + CHECK_INTERVAL))
                log "Idle on $m_clean: $idle/$IDLE_LIMIT sec"
            else
                # Valid data flow detected: reset idle timer
                idle=0
                last_size=$curr_size
            fi

            # Failover trigger: move to next station if current is silent
            if [ "$idle" -ge "$IDLE_LIMIT" ]; then
                log "TIMEOUT on $m_clean. Moving to next mountpoint..."
                kill -9 $CPID
                break
            fi
        done

        # Small cooldown before next attempt
        sleep 2
    done
done