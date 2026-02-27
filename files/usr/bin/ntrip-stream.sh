#!/bin/sh
# NTRIP Failover Watchdog (Fixed Truncation Logic)
. /lib/functions.sh

TAG="ntrip-failover"
TEMP_FILE="/tmp/ntrip_corrections.log"
IDLE_LIMIT=20
CHECK_INTERVAL=5
MAX_LOG_SIZE=1048576  # 1 MB as requested for testing

log() { logger -t "$TAG" "$1"; }

# Cleanup on start
killall -9 ntripclient.exe 2>/dev/null

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

        log "Connecting to: <$m_clean>..."
        > "$TEMP_FILE"

        # Start process
        /usr/bin/ntripclient.exe -s "$SERVER" -r "$PORT" -m "$m_clean" \
            -u "$USER" -p "$PASSWORD" -M "$MODE" 2>&1 | tee "$TEMP_FILE" > "$SERIAL_PORT" &
        
        CPID=$!
        sleep 3
        
        last_size=0
        idle=0

        while kill -0 $CPID 2>/dev/null; do
            sleep $CHECK_INTERVAL
            
            # 1. Offline detection (Sourcetable)
            if grep -qi "SOURCETABLE" "$TEMP_FILE"; then
                log "OFFLINE: Station $m_clean. Switching..."
                kill -9 $CPID
                break
            fi

            # 2. Log size check
            curr_size=$(ls -l "$TEMP_FILE" | awk '{print $5}')
            [ -z "$curr_size" ] && curr_size=0

            if [ "$curr_size" -gt "$MAX_LOG_SIZE" ]; then
                log "Log limit reached (1MB). Restarting connection to clear cache..."
                kill -9 $CPID
                # Breaking this loop will trigger a fresh start in the outer loop
                break 
            fi

            # 3. Data flow monitoring
            if [ "$curr_size" -le "$last_size" ]; then
                idle=$((idle + CHECK_INTERVAL))
                log "Idle on $m_clean: $idle/$IDLE_LIMIT sec"
            else
                idle=0
                last_size=$curr_size
            fi

            if [ "$idle" -ge "$IDLE_LIMIT" ]; then
                log "TIMEOUT on $m_clean. Moving to next base..."
                kill -9 $CPID
                break
            fi
        done
        sleep 2
    done
done