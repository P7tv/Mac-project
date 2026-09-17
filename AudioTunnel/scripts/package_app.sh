#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="AudioTunnel"
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

echo "🚀 Installing to /Applications/$APP_NAME.app..."
rm -rf "/Applications/$APP_NAME.app"
cp -R "$BUNDLE_DIR" "/Applications/$APP_NAME.app"

echo "✅ $APP_NAME.app successfully packaged and installed at: /Applications/$APP_NAME.app"
