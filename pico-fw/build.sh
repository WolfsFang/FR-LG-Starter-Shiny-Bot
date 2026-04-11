#!/usr/bin/env bash
# Build script for shinybot Pico 2 W firmware
# Usage:
#   ./build.sh                           # rebuild only (uses cached config)
#   ./build.sh --clean                   # full clean rebuild
#   ./build.sh --ssid "MySSID" --pass "MyPassword"          # set WiFi creds
#   ./build.sh --clean --ssid "MySSID" --pass "MyPassword"  # clean + creds
#   ./build.sh --flash                   # build and copy .uf2 to RPI-RP2 drive

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"

# --- Toolchain paths (override via environment if your paths differ) ---
export PICO_SDK_PATH="${PICO_SDK_PATH:-$HOME/pico-sdk}"
export MINGW_PATH="${MINGW_PATH:-/c/msys64/mingw64/bin}"
export ARM_GCC_PATH="${ARM_GCC_PATH:-/c/Program Files (x86)/Arm GNU Toolchain arm-none-eabi/14.2 rel1/bin}"
export CMAKE_PATH="${CMAKE_PATH:-/c/Program Files/CMake/bin}"

# Auto-detect Ninja in winget packages folder if not already on PATH
if ! command -v ninja &>/dev/null; then
    NINJA_DIR=$(find "$LOCALAPPDATA/Microsoft/WinGet/Packages" -maxdepth 1 -name "Ninja*" -type d 2>/dev/null | head -1)
    if [ -n "$NINJA_DIR" ]; then
        export NINJA_PATH="$NINJA_DIR"
    fi
fi
export NINJA_PATH="${NINJA_PATH:-}"

export PATH="$CMAKE_PATH:$NINJA_PATH:$MINGW_PATH:$ARM_GCC_PATH:$PATH"

# --- Parse arguments ---
CLEAN=false
FLASH=false
WIFI_SSID=""
WIFI_PASSWORD=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)  CLEAN=true; shift ;;
        --flash)  FLASH=true; shift ;;
        --ssid)   WIFI_SSID="$2"; shift 2 ;;
        --pass)   WIFI_PASSWORD="$2"; shift 2 ;;
        *)        echo "Unknown option: $1"; exit 1 ;;
    esac
done

# --- Clean if requested ---
if $CLEAN; then
    echo "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
fi

# --- Configure if needed ---
if [ ! -f "$BUILD_DIR/build.ninja" ]; then
    echo "Configuring CMake..."
    mkdir -p "$BUILD_DIR"

    CMAKE_ARGS=("-G" "Ninja" "-DPICO_BOARD=pico2_w")
    if [ -n "$WIFI_SSID" ]; then
        CMAKE_ARGS+=("-DWIFI_SSID='\"$WIFI_SSID\"'")
    fi
    if [ -n "$WIFI_PASSWORD" ]; then
        CMAKE_ARGS+=("-DWIFI_PASSWORD='\"$WIFI_PASSWORD\"'")
    fi

    cmake -S "$SCRIPT_DIR" -B "$BUILD_DIR" "${CMAKE_ARGS[@]}"
fi

# --- Build ---
echo "Building..."
cmake --build "$BUILD_DIR" -j

echo ""
echo "Build complete: $BUILD_DIR/shinybot_pico_fw.uf2"

# --- Flash if requested ---
if $FLASH; then
    # Look for RPI-RP2 drive
    for drive in /d /e /f /g /h; do
        if [ -f "$drive/INFO_UF2.TXT" ]; then
            echo "Flashing to $drive..."
            cp "$BUILD_DIR/shinybot_pico_fw.uf2" "$drive/"
            echo "Flashed successfully!"
            exit 0
        fi
    done
    echo "ERROR: RPI-RP2 drive not found. Hold BOOTSEL and plug in the Pico first."
    exit 1
fi
