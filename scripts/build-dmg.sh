#!/bin/bash
set -euo pipefail

# Build PhotoExodus.app and package as a DMG for distribution.
# Usage: ./scripts/build-dmg.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="PhotoExodus"
DMG_NAME="$APP_NAME.dmg"

echo "==> Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building $APP_NAME (Release)..."
xcodebuild \
    -project "$PROJECT_DIR/$APP_NAME.xcodeproj" \
    -scheme "$APP_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    build \
    | tail -3

# Find the built .app
APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Release/$APP_NAME.app"
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: $APP_NAME.app not found at $APP_PATH"
    exit 1
fi

echo "==> Built $APP_NAME.app successfully."

# Create DMG
echo "==> Creating DMG..."
DMG_DIR="$BUILD_DIR/dmg-staging"
mkdir -p "$DMG_DIR"
cp -R "$APP_PATH" "$DMG_DIR/"
ln -s /Applications "$DMG_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$BUILD_DIR/$DMG_NAME"

echo ""
echo "==> Done! DMG at: $BUILD_DIR/$DMG_NAME"
echo "    App at: $APP_PATH"
