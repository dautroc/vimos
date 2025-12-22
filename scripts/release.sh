#!/bin/bash
set -e

# release.sh
# Usage: ./scripts/release.sh [version]
# Example: ./scripts/release.sh v1.1.0

VERSION="$1"
if [ -z "$VERSION" ]; then
    VERSION="v1.1.0"
    echo "No version specified, defaulting to $VERSION"
fi

# Build
echo "Building VimOS (Release)..."
swift build -c release --product VimOS

# Bundle
echo "Bundling App..."
./scripts/bundle_app.sh

# Changelog
echo "Generating Changelog..."
# Try to find the latest tag that is reachable
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$LAST_TAG" ]; then
    echo "No previous tag found. Using full history."
    git log --pretty=format:"- %s (%h)" > Changelog.txt
else
    echo "Changes since $LAST_TAG:"
    git log "${LAST_TAG}..HEAD" --pretty=format:"- %s (%h)" > Changelog.txt
fi

echo "" >> Changelog.txt # Ensure newline
cat Changelog.txt

# Package
ARCHIVE_NAME="VimOS_${VERSION}.zip"
echo "Packaging ${ARCHIVE_NAME}..."
zip -r "$ARCHIVE_NAME" VimOS.app Changelog.txt

echo "Release $VERSION created successfully: $ARCHIVE_NAME"
