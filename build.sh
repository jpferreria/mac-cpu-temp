#!/usr/bin/env bash
set -euo pipefail

APP_NAME="cpu-temp"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"

echo "==> Building ${APP_NAME}..."

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

clang -fobjc-arc -O2 \
    -arch arm64 \
    -framework Cocoa \
    -framework IOKit \
    -framework ServiceManagement \
    -I src \
    src/main.m \
    src/AppDelegate.m \
    src/ThermalMonitor.m \
    src/SensorInfo.m \
    -o "${MACOS_DIR}/${APP_NAME}"

cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

# Ad-hoc codesign for local execution
if command -v codesign &>/dev/null; then
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
fi

echo "==> Successfully built ${APP_BUNDLE}"
