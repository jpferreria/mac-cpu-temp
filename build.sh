#!/usr/bin/env bash
set -euo pipefail

APP_NAME="cpu-temp"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"
MODULE_CACHE="/tmp/swift-cache"
CLANG_CACHE="/tmp/clang-cache"

echo "==> Building ${APP_NAME} with Apple Intelligence & App Intents..."

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${BUILD_DIR}" "${MODULE_CACHE}" "${CLANG_CACHE}"

# 1. Compile Swift App Intents
echo "--> Compiling Swift App Intents..."
swiftc -parse-as-library -O \
    -module-cache-path "${MODULE_CACHE}" \
    -Xcc -fmodules-cache-path="${CLANG_CACHE}" \
    -import-objc-header src/BridgingHeader.h \
    -emit-objc-header-path "${BUILD_DIR}/CPUTemp-Swift.h" \
    -emit-object -o "${BUILD_DIR}/CPUTempIntents.o" \
    src/CPUTempIntents.swift \
    -framework Foundation \
    -framework AppIntents

# 2. Compile Objective-C core & link Swift object
echo "--> Compiling Objective-C core & linking executable..."
SWIFT_LIB_DIR="$(xcode-select -p)/usr/lib/swift/macosx"

clang -fobjc-arc -O2 \
    -Wall -Wextra -Wformat=2 -Wformat-security \
    -fstack-protector-strong -D_FORTIFY_SOURCE=2 \
    -arch arm64 \
    -framework Cocoa \
    -framework IOKit \
    -framework ServiceManagement \
    -framework AppIntents \
    -I src \
    -I "${BUILD_DIR}" \
    -L"${SWIFT_LIB_DIR}" \
    -Wl,-rpath,"${SWIFT_LIB_DIR}" \
    -Wl,-rpath,/usr/lib/swift \
    src/main.m \
    src/AppDelegate.m \
    src/ThermalMonitor.m \
    src/SensorInfo.m \
    src/ThermalInsightEngine.m \
    "${BUILD_DIR}/CPUTempIntents.o" \
    -o "${MACOS_DIR}/${APP_NAME}"

cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

# 3. Ad-hoc codesign with hardened runtime for local execution
if command -v codesign &>/dev/null; then
    codesign --force --deep --sign - --options runtime "${APP_BUNDLE}" 2>/dev/null || true
fi

echo "==> Successfully built ${APP_BUNDLE}"
