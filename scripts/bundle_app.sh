#!/bin/bash

# Configuration
APP_NAME="VimOS"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR=".build/release"
EXECUTABLE="${BUILD_DIR}/${APP_NAME}"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

VERSION="$1"
if [ -z "$VERSION" ]; then
    VERSION="1.0"
    echo "No version specified, defaulting to ${VERSION}"
fi

# Check if build exists
if [ ! -f "$EXECUTABLE" ]; then
    echo "Error: Release executable not found at $EXECUTABLE"
    echo "Please run 'swift build -c release --product VimOS' first."
    exit 1
fi

# Cleanup previous build
rm -rf "$APP_BUNDLE"

# Create directories
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$EXECUTABLE" "$MACOS_DIR/"

# Copy icon
ICON_SOURCE="Sources/VimOS/Resources/AppIcon.icns"
if [ -f "$ICON_SOURCE" ]; then
    cp "$ICON_SOURCE" "$RESOURCES_DIR/"
    echo "Copied AppIcon.icns to bundle"
else
    echo "Warning: AppIcon.icns not found at $ICON_SOURCE"
fi

# Create Info.plist
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.vimos.app</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Ad-hoc code signing (Required for Apple Silicon)
echo "Signing app bundle..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "App bundle created at ${APP_BUNDLE}"
