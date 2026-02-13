#!/bin/bash

# Simple script to fix and package a single batch file
# Usage: ./fix_and_zip_batch.sh [path_to_batch_file]

set -e

# Default to win_installation.bat if no argument provided
BATCH_FILE="${1:-win_installation.bat}"

# Check if file exists
if [ ! -f "$BATCH_FILE" ]; then
    echo "ERROR: File not found: $BATCH_FILE"
    echo "Usage: $0 [path_to_batch_file]"
    exit 1
fi

# Get filename without path
FILENAME=$(basename "$BATCH_FILE")
TIMESTAMP=$(date +%Y%m%d-%H%M)
OUTPUT_NAME="${FILENAME%.bat}_fixed_${TIMESTAMP}"

echo "============================================"
echo "  Batch File Fix & Package"
echo "============================================"
echo ""
echo "Input file: $BATCH_FILE"
echo "Output: ${OUTPUT_NAME}.zip"
echo ""

# Create temporary directory
TEMP_DIR=$(mktemp -d)
echo ">>> Creating temporary directory: $TEMP_DIR"

# Copy the batch file to temp directory
cp "$BATCH_FILE" "$TEMP_DIR/$FILENAME"
echo ">>> Copied batch file to temp directory"

# Fix encoding and line endings
echo ">>> Fixing encoding and line endings..."
# Remove UTF-8 BOM if present (1s/^\xEF\xBB\xBF//)
# Remove any existing CR (s/\r$//)
# Add CR to create CRLF (s/$/\r/)
sed -i '1s/^\xEF\xBB\xBF//;s/\r$//;s/$/\r/' "$TEMP_DIR/$FILENAME"

echo "    ✓ Removed UTF-8 BOM (if present)"
echo "    ✓ Converted to CRLF line endings"

# Create ZIP file
echo ">>> Creating ZIP file..."
cd "$TEMP_DIR"
zip -q "${OUTPUT_NAME}.zip" "$FILENAME"

# Move ZIP to current directory
mv "${OUTPUT_NAME}.zip" "$OLDPWD/"
cd "$OLDPWD"

# Clean up
rm -rf "$TEMP_DIR"

echo ""
echo "============================================"
echo ">>> Done!"
echo "============================================"
echo ""
echo "Output: ${OUTPUT_NAME}.zip"
echo ""
echo "To test the fixed file:"
echo "  1. Extract ${OUTPUT_NAME}.zip"
echo "  2. Run $FILENAME on Windows"
