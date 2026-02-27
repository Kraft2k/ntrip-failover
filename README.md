# OpenWrt NTRIP Failover Watchdog

A robust watchdog script for ntripclient designed for OpenWrt-based industrial routers . It provides automatic switching between multiple mountpoints to ensure continuous GNSS correction streaming.



## Key Features
- Automatic Failover: Cycles through a list of mountpoints until a working one is found.
- Instant Offline Detection: Recognizes SOURCETABLE responses and skips inactive stations immediately without waiting for timeouts.
- Log Management: Built-in log rotation (1MB limit) to protect router RAM.
- Procd Integration: Runs as a system service with auto-respawn capabilities.

## Installation

### Manual Installation
1. Move the original binary: mv /usr/bin/ntripclient /usr/bin/ntripclient.exe
2. Upload ntrip-stream.sh to /usr/bin/ and chmod +x.
3. Upload the init script to /etc/init.d/ntrip-stream and chmod +x.
4. Enable the service:
   ```bash
   /etc/init.d/ntrip-stream enable
   /etc/init.d/ntrip-stream start

## Configuration Reference

The configuration is stored in /etc/config/ntrip. You can edit it manually or use the uci tool:

| Option | Description | Example |
| :--- | :--- | :--- |
| server | NTRIP Caster address | server |
| port | Caster port | 2101 |
| user | Your login | user |
| password | Your password | password |
| mountpoint| Space-separated list of bases | 'MOUNT_1 MOUNT_2' |
| serial_port| Target serial device | /dev/ttyS0 |

### Command Line Configuration Example:
```bash
uci set ntrip.client.mountpoint='MOUNT_1 MOUNT_2'
uci set ntrip.client.user='my_user'
uci commit ntrip
/etc/init.d/ntrip-stream restart