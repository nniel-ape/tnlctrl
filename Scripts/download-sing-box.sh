#!/bin/bash
# Downloads the sing-box binary for bundling with tnl_ctrl_helper.
# Usage: ./Scripts/download-sing-box.sh [version]

set -euo pipefail

VERSION="${1:-1.13.0}"
ARCH="arm64"
DEST_DIR="$(cd "$(dirname "$0")/.." && pwd)/tnl_ctrl_helper/bin"
DEST="$DEST_DIR/sing-box"

# Check if already present and correct version
if [ -f "$DEST" ]; then
    CURRENT=$("$DEST" version 2>/dev/null | head -1 | awk '{print $NF}' || echo "")
    if [ "$CURRENT" = "$VERSION" ]; then
        echo "sing-box $VERSION already present at $DEST"
        exit 0
    fi
    echo "Updating sing-box from $CURRENT to $VERSION"
fi

mkdir -p "$DEST_DIR"

TARBALL="sing-box-${VERSION}-darwin-${ARCH}.tar.gz"
URL="https://github.com/SagerNet/sing-box/releases/download/v${VERSION}/${TARBALL}"

echo "Downloading sing-box v${VERSION} (darwin-${ARCH})..."
curl -L -o "/tmp/${TARBALL}" "$URL"

echo "Extracting..."
tar -xzf "/tmp/${TARBALL}" -C /tmp

cp "/tmp/sing-box-${VERSION}-darwin-${ARCH}/sing-box" "$DEST"
chmod +x "$DEST"

# Cleanup
rm -rf "/tmp/${TARBALL}" "/tmp/sing-box-${VERSION}-darwin-${ARCH}"

echo "Installed sing-box v${VERSION} to $DEST"
"$DEST" version
