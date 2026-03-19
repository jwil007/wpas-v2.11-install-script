#!/usr/bin/env bash
# install_wpa_supplicant_2.11.sh
#
# Builds and installs wpa_supplicant v2.11 from source, replacing the
# distro-packaged version in-place. Tested on Debian/Kali-based systems.
#
# Motivation: distro packages (as of early 2026) still ship v2.10, which
# lacks NL80211_SCAN_FLAG_COLOCATED_6GHZ support. Without this flag,
# 6 GHz APs are scanned passively only and frequently missing from
# SCAN_RESULTS even when the hardware and kernel support 6 GHz.
#
# What this script does:
#   1. Installs build dependencies via apt
#   2. Downloads and verifies wpa_supplicant-2.11.tar.gz from w1.fi
#   3. Builds with defconfig (nl80211, dbus, SAE, all standard features)
#   4. Stops the running wpa_supplicant service
#   5. Replaces the existing binary in /usr/sbin/wpa_supplicant
#   6. Restarts the service and verifies the version
#
# Usage:
#   chmod +x install_wpa_supplicant_2.11.sh
#   sudo ./install_wpa_supplicant_2.11.sh
#
# Requirements: Debian/Ubuntu/Kali-based distro with apt, systemd, wget

set -euo pipefail

VERSION="2.11"
TARBALL="wpa_supplicant-${VERSION}.tar.gz"
URL="https://w1.fi/releases/${TARBALL}"
MD5_EXPECTED="72a4a00eddb7a499a58113c3361ab094"
BUILD_DIR=$(mktemp -d)

# ── helpers ──────────────────────────────────────────────────────────────────

info()  { echo "[INFO]  $*"; }
error() { echo "[ERROR] $*" >&2; exit 1; }

require_root() {
    [[ $EUID -eq 0 ]] || error "This script must be run as root (sudo)."
}

cleanup() {
    info "Cleaning up build directory: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

# ── preflight ────────────────────────────────────────────────────────────────

require_root

INSTALL_TARGET=$(command -v wpa_supplicant 2>/dev/null || true)
if [[ -z "$INSTALL_TARGET" ]]; then
    # Fall back to the standard location if not in PATH
    INSTALL_TARGET="/usr/sbin/wpa_supplicant"
fi

info "Target binary: $INSTALL_TARGET"
if [[ -f "$INSTALL_TARGET" ]]; then
    CURRENT_VERSION=$("$INSTALL_TARGET" -v 2>&1 | grep -oP 'v\K[\d.]+' | head -1 || true)
    info "Currently installed version: ${CURRENT_VERSION:-unknown}"
fi

# ── dependencies ─────────────────────────────────────────────────────────────

info "Installing build dependencies..."
apt-get install -y \
    build-essential \
    pkg-config \
    libssl-dev \
    libnl-3-dev \
    libnl-genl-3-dev \
    libnl-route-3-dev \
    libdbus-1-dev

# ── download and verify ───────────────────────────────────────────────────────

info "Downloading wpa_supplicant ${VERSION}..."
cd "$BUILD_DIR"
wget -q --show-progress "$URL" -O "$TARBALL"

info "Verifying MD5 checksum..."
MD5_ACTUAL=$(md5sum "$TARBALL" | awk '{print $1}')
if [[ "$MD5_ACTUAL" != "$MD5_EXPECTED" ]]; then
    error "MD5 mismatch. Expected: $MD5_EXPECTED  Got: $MD5_ACTUAL"
fi
info "Checksum OK."

# ── build ─────────────────────────────────────────────────────────────────────

info "Extracting..."
tar xzf "$TARBALL"
cd "wpa_supplicant-${VERSION}/wpa_supplicant"

info "Configuring build..."
cp defconfig .config

info "Building (using $(nproc) cores)..."
make -j"$(nproc)"

# ── install ───────────────────────────────────────────────────────────────────

info "Stopping wpa_supplicant service..."
systemctl stop wpa_supplicant || true

info "Installing binary to $INSTALL_TARGET..."
install -m 755 wpa_supplicant "$INSTALL_TARGET"
install -m 755 wpa_cli /usr/sbin/wpa_cli
install -m 755 wpa_passphrase /usr/sbin/wpa_passphrase

info "Restarting wpa_supplicant service..."
systemctl start wpa_supplicant

# ── verify ────────────────────────────────────────────────────────────────────

sleep 1
NEW_VERSION=$("$INSTALL_TARGET" -v 2>&1 | grep -oP 'v\K[\d.]+' | head -1 || true)
if [[ "$NEW_VERSION" == "$VERSION" ]]; then
    info "Success. wpa_supplicant ${NEW_VERSION} installed at $INSTALL_TARGET."
else
    error "Version check failed. Got: '${NEW_VERSION}'. Check $INSTALL_TARGET manually."
fi

info "Verifying service is running..."
if systemctl is-active --quiet wpa_supplicant; then
    info "Service is running."
else
    error "Service failed to start. Check: journalctl -u wpa_supplicant"
fi

info "Done."
