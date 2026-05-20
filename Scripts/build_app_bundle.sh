#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/Luma.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/Luma" "$MACOS_DIR/Luma"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp -R "$ROOT_DIR/.build/arm64-apple-macosx/release/Luma_AIPet.bundle" "$APP_DIR/Luma_AIPet.bundle"
cp -R "$ROOT_DIR/.build/arm64-apple-macosx/release/Luma_AIPet.bundle" "$RESOURCES_DIR/Luma_AIPet.bundle"

echo "Built $APP_DIR"
