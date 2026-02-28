#!/bin/bash

# --- CONFIGURATION ---
ORIGINAL_IPK="ntripclient_1_51_1_mipsel_24kc.ipk"
REPO_DIR="ntrip-failover"
BUILD_DIR="ipk_build"
RESULT_NAME="ntrip-failover-plus_1.0.0_mipsel_24kc.ipk"

echo "🚀 Starting build process for $RESULT_NAME..."

# 1. Cleanup and create build structure
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/data/usr/bin"
mkdir -p "$BUILD_DIR/data/etc/init.d"
mkdir -p "$BUILD_DIR/data/etc/config"
mkdir -p "$BUILD_DIR/control"

# 2. Extract original binary from provided IPK
echo "📦 Extracting binary from $ORIGINAL_IPK..."
mkdir -p temp_extract
tar -xzf "$ORIGINAL_IPK" -C temp_extract
tar -xzf temp_extract/data.tar.gz -C temp_extract
# Move and rename binary to .exe to avoid system conflicts
mv temp_extract/usr/bin/ntripclient "$BUILD_DIR/data/usr/bin/ntripclient.exe"
rm -rf temp_extract

# 3. Copy files from your repository
echo "📂 Copying files from $REPO_DIR..."
cp "$REPO_DIR/files/usr/bin/ntrip-stream.sh" "$BUILD_DIR/data/usr/bin/ntrip-stream"
cp "$REPO_DIR/files/etc/init.d/ntrip-stream" "$BUILD_DIR/data/etc/init.d/ntrip-stream"
cp "$REPO_DIR/files/etc/init.d/config/ntrip" "$BUILD_DIR/data/etc/config/ntrip"

# 4. Create control file
echo "📝 Generating control file..."
cat <<EOF > "$BUILD_DIR/control/control"
Package: ntrip-failover-plus
Version: 1.0.0
Depends: libc, uci
Section: net
Architecture: mipsel_24kc
Maintainer: Alexey Kravchenko
Description: Professional NTRIP client with automatic failover watchdog.
EOF

# 5. Create post-installation script
echo "🛠 Generating postinst script..."
cat <<EOF > "$BUILD_DIR/control/postinst"
#!/bin/sh
chmod +x /usr/bin/ntrip-stream
chmod +x /etc/init.d/ntrip-stream
/etc/init.d/ntrip-stream enable
/etc/init.d/ntrip-stream start
exit 0
EOF
chmod +x "$BUILD_DIR/control/postinst"

# 6. Packaging
echo "🏗  Assembling IPK..."
cd "$BUILD_DIR/data"
tar -czf ../data.tar.gz .
cd "../control"
tar -czf ../control.tar.gz .
cd ..
echo "2.0" > debian-binary
tar -czf "../$RESULT_NAME" debian-binary data.tar.gz control.tar.gz

cd ..
rm -rf "$BUILD_DIR"

echo "✅ Success! Packet created: $RESULT_NAME"