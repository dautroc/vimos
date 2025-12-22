#!/bin/bash

# process_icon.sh
# Usage: ./process_icon.sh <source_image> <output_dir>

SOURCE_IMAGE="$1"
OUTPUT_DIR="$2"
ICONSET_DIR="${OUTPUT_DIR}/VimOS.iconset"

if [ -z "$SOURCE_IMAGE" ] || [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <source_image> <output_dir>"
    exit 1
fi

mkdir -p "$ICONSET_DIR"

# Resize images for iconset
sips -s format png -z 16 16     "$SOURCE_IMAGE" --out "${ICONSET_DIR}/icon_16x16.png"
sips -s format png -z 32 32     "$SOURCE_IMAGE" --out "${ICONSET_DIR}/icon_16x16@2x.png"
sips -s format png -z 32 32     "$SOURCE_IMAGE" --out "${ICONSET_DIR}/icon_32x32.png"
sips -s format png -z 64 64     "$SOURCE_IMAGE" --out "${ICONSET_DIR}/icon_32x32@2x.png"
sips -s format png -z 128 128   "$SOURCE_IMAGE" --out "${ICONSET_DIR}/icon_128x128.png"
sips -s format png -z 256 256   "$SOURCE_IMAGE" --out "${ICONSET_DIR}/icon_128x128@2x.png"
sips -s format png -z 256 256   "$SOURCE_IMAGE" --out "${ICONSET_DIR}/icon_256x256.png"
sips -s format png -z 512 512   "$SOURCE_IMAGE" --out "${ICONSET_DIR}/icon_256x256@2x.png"
sips -s format png -z 512 512   "$SOURCE_IMAGE" --out "${ICONSET_DIR}/icon_512x512.png"
sips -s format png -z 1024 1024 "$SOURCE_IMAGE" --out "${ICONSET_DIR}/icon_512x512@2x.png"

# Convert iconset to icns
iconutil -c icns "$ICONSET_DIR" -o "${OUTPUT_DIR}/AppIcon.icns" || echo "iconutil failed"

# Cleanup if successful
if [ -f "${OUTPUT_DIR}/AppIcon.icns" ]; then
    rm -rf "$ICONSET_DIR"
    echo "Icon created at ${OUTPUT_DIR}/AppIcon.icns"
else
    echo "Failed to create ${OUTPUT_DIR}/AppIcon.icns. Iconset left at $ICONSET_DIR for debugging."
fi
