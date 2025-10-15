#!/bin/bash

# Convert PNG sequences to transparent MOV files (ProRes 4444)
# ProRes 4444 supports alpha channel for transparent backgrounds

echo "🎬 PNG Sequence → Transparent MOV Converter"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ ffmpeg is not installed"
    echo ""
    echo "Install with Homebrew:"
    echo "  brew install ffmpeg"
    echo ""
    exit 1
fi

# Base directory for PNG sequences
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)/Animations/PNGSequences"
OUTPUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/Animations"

if [ ! -d "$BASE_DIR" ]; then
    echo "❌ No PNG sequences found at: $BASE_DIR"
    echo "   Run the Swift exporter first to generate PNG sequences"
    exit 1
fi

# Find all animation folders
ANIMATION_FOLDERS=$(find "$BASE_DIR" -mindepth 1 -maxdepth 1 -type d)

if [ -z "$ANIMATION_FOLDERS" ]; then
    echo "❌ No animation folders found"
    echo "   Expected structure: PNGSequences/animation-name/animation-name_0001.png"
    exit 1
fi

# Convert each animation
for FOLDER in $ANIMATION_FOLDERS; do
    ANIMATION_NAME=$(basename "$FOLDER")

    # Check if PNG files exist
    FIRST_FRAME="$FOLDER/${ANIMATION_NAME}_0001.png"
    if [ ! -f "$FIRST_FRAME" ]; then
        echo "⚠️  Skipping $ANIMATION_NAME (no PNG files found)"
        continue
    fi

    # Count frames
    FRAME_COUNT=$(find "$FOLDER" -name "${ANIMATION_NAME}_*.png" | wc -l | tr -d ' ')

    echo "🎞️  Converting: $ANIMATION_NAME"
    echo "   Frames: $FRAME_COUNT"
    echo "   Input:  $FOLDER"

    OUTPUT_FILE="$OUTPUT_DIR/${ANIMATION_NAME}.mov"

    # Convert using ffmpeg
    # -framerate 60: 60fps input
    # -i: input pattern
    # -c:v prores_ks: ProRes encoder
    # -profile:v 4444: ProRes 4444 with alpha channel
    # -pix_fmt yuva444p10le: Pixel format with alpha
    # -y: overwrite output file

    ffmpeg -framerate 60 \
           -i "$FOLDER/${ANIMATION_NAME}_%04d.png" \
           -c:v prores_ks \
           -profile:v 4444 \
           -pix_fmt yuva444p10le \
           -y \
           "$OUTPUT_FILE" \
           2>&1 | grep -E '(frame=|error|Error)' || true

    if [ -f "$OUTPUT_FILE" ]; then
        FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
        echo "   ✅ Output: $OUTPUT_FILE ($FILE_SIZE)"
        echo ""
    else
        echo "   ❌ Failed to create MOV file"
        echo ""
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Conversion complete!"
echo ""
echo "📁 Transparent MOV files: MarketingExport/Animations/"
echo "🎥 Import into After Effects, Motion, Final Cut Pro, etc."
echo "💡 ProRes 4444 preserves alpha channel (transparency)"
echo ""
