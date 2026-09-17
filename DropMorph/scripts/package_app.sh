#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="DropMorph"
BUNDLE_DIR="$PROJECT_DIR/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "🔨 Building $APP_NAME (Release)..."
cd "$PROJECT_DIR"
swift build -c release

echo "📦 Creating macOS App Bundle structure..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "🚚 Copying binary and assets..."
cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "🔐 Ad-hoc code signing..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo "✅ $APP_NAME.app successfully packaged at: $BUNDLE_DIR"
echo "👉 You can run it via: open '$BUNDLE_DIR' or move it to /Applications"
