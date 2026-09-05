#!/bin/bash
# E2E tunnel test — compiles existing shared code, runs against local qtunnel-server
#
# Prerequisites:
#   - qtunnel binary at ~/Softing/qtunnel
#   - Python3 for file server
#
# Usage: bash run_tunnel_test.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QTUNNEL=~/Softing/qtunnel
SECRET="testsecret"
SERVER_PORT=29001
BACKEND_PORT=28080

cleanup() {
    echo "[cleanup] Stopping services..."
    [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null
    [ -n "$BACKEND_PID" ] && kill $BACKEND_PID 2>/dev/null
}
trap cleanup EXIT

# 1. Start file server (backend)
echo "[1/4] Starting file server on :$BACKEND_PORT ..."
python3 -m http.server $BACKEND_PORT --directory "$SCRIPT_DIR/.." &>/dev/null &
BACKEND_PID=$!
sleep 1

# 2. Start qtunnel-server (rc4, secret=testsecret, :$SERVER_PORT -> 127.0.0.1:$BACKEND_PORT)
echo "[2/4] Starting qtunnel-server on :$SERVER_PORT -> 127.0.0.1:$BACKEND_PORT ..."
$QTUNNEL -listen=:$SERVER_PORT -backend=127.0.0.1:$BACKEND_PORT -crypto=rc4 -secret=$SECRET &>/dev/null &
SERVER_PID=$!
sleep 1

# 3. Compile Swift test (existing shared code + minimal main)
echo "[3/4] Compiling test (using existing shared code)..."
SWIFT_FILES=(
    "$SCRIPT_DIR/Models/CryptoMethod.swift"
    "$SCRIPT_DIR/Protocol/Cipher.swift"
    "$SCRIPT_DIR/Protocol/KeyDerivation.swift"
    "$SCRIPT_DIR/Protocol/RC4Cipher.swift"
    "$SCRIPT_DIR/Protocol/AES256CFBCipher.swift"
    "$SCRIPT_DIR/Util/Log.swift"
    "$SCRIPT_DIR/Protocol/TunnelConnection.swift"
    "$SCRIPT_DIR/test_tunnel_harness.swift"
)
swiftc "${SWIFT_FILES[@]}" -o /tmp/qtunnel_test -framework Network 2>&1

# 4. Run test
echo "[4/4] Running tunnel test..."
echo "---"
/tmp/qtunnel_test
