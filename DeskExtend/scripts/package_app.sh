#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="DeskExtend"
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
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep -o 'Apple Development: [^"]*' | head -n 1 || true)
if [ -n "$SIGN_IDENTITY" ]; then
    echo "🔐 Signing with Apple Development identity: $SIGN_IDENTITY..."
    codesign --force --deep --sign "$SIGN_IDENTITY" "$BUNDLE_DIR"
else
    echo "🔐 Ad-hoc code signing..."
    codesign --force --deep --sign - "$BUNDLE_DIR"
fi

echo "✅ $APP_NAME.app successfully packaged at: $BUNDLE_DIR"
echo "👉 You can run it via: open '$BUNDLE_DIR' or move it to /Applications"
