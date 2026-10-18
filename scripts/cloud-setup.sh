#!/bin/bash
# Setup script for the Claude Code cloud environment (runs as root on Ubuntu 24.04 x86_64, before
# Claude starts). Installs a Swift toolchain, mingw-w64 for the XInput stub, and pulls the Swift
# Docker image as a fallback. Every step is best-effort so the session still starts if one fails.
# Keep total runtime under ~5 minutes or the environment snapshot is not cached.

set -u
SWIFT_VERSION="${SWIFT_VERSION:-6.2}"
SWIFT_TAG="swift-${SWIFT_VERSION}-RELEASE"
SWIFT_URL="https://download.swift.org/swift-${SWIFT_VERSION}-release/ubuntu2404/${SWIFT_TAG}/${SWIFT_TAG}-ubuntu24.04.tar.gz"
INSTALL_DIR="/opt/${SWIFT_TAG}-ubuntu24.04"

export DEBIAN_FRONTEND=noninteractive

# 1. apt packages: Swift runtime dependencies for Ubuntu 24.04 plus the Windows cross-compiler.
(
  apt-get update -qq || true
  apt-get install -y -qq --no-install-recommends \
    binutils gnupg2 libc6-dev libcurl4-openssl-dev libedit2 libgcc-13-dev libpython3-dev \
    libsqlite3-0 libstdc++-13-dev libxml2-dev libncurses-dev pkg-config tzdata unzip zlib1g-dev \
    mingw-w64 xxd || true
) &
APT_PID=$!

# 2. Swift toolchain from download.swift.org (needs that host on the environment's allowlist).
(
  if [ ! -x "${INSTALL_DIR}/usr/bin/swift" ]; then
    if curl -fsSL --connect-timeout 15 --max-time 200 "${SWIFT_URL}" -o /tmp/swift.tar.gz; then
      tar -xzf /tmp/swift.tar.gz -C /opt && rm -f /tmp/swift.tar.gz
    else
      echo "cloud-setup: Swift tarball download failed; will rely on the Docker fallback" >&2
    fi
  fi
  if [ -x "${INSTALL_DIR}/usr/bin/swift" ]; then
    ln -sf "${INSTALL_DIR}/usr/bin/swift" /usr/local/bin/swift
    ln -sf "${INSTALL_DIR}/usr/bin/swiftc" /usr/local/bin/swiftc
    echo "export PATH=\"${INSTALL_DIR}/usr/bin:\$PATH\"" > /etc/profile.d/swift.sh
  fi
) &
SWIFT_PID=$!

# 3. Docker fallback: pull the official Swift image only if step 2 did not produce a toolchain.
#    A blocked download fails fast, so this rarely adds much time; a working download skips it.
wait "$SWIFT_PID" 2>/dev/null || true
if [ ! -x "${INSTALL_DIR}/usr/bin/swift" ] && command -v docker >/dev/null 2>&1; then
  if ! docker info >/dev/null 2>&1; then
    (dockerd >/var/log/dockerd-setup.log 2>&1 &)
    for _ in $(seq 1 20); do docker info >/dev/null 2>&1 && break; sleep 1; done
  fi
  docker pull -q "swift:${SWIFT_VERSION}-noble" || echo "cloud-setup: docker pull failed" >&2
fi

wait "$APT_PID" 2>/dev/null || true

echo "cloud-setup: swift=$(command -v swift || echo missing) mingw=$(command -v x86_64-w64-mingw32-gcc || echo missing)"
exit 0
