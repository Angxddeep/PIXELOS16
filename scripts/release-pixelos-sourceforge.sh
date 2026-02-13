#!/bin/bash

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SF_USER="YOUR_SOURCEFORGE_USERNAME"  # Replace with your SourceForge username
SF_PROJECT="YOUR_PROJECT_NAME"        # Replace with your SourceForge project name
REPO="Pixelos-xaga/pixelos-releases"
BUILD_TYPE="unofficial"  # Change to "official" when ready

# Build detection configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIXELOS_ROOT="$(dirname "$SCRIPT_DIR")"  # Parent directory of scripts folder
OUT_DIR="${OUT:-$PIXELOS_ROOT/out/target/product}"  # Default Android build output directory
DEVICE="${DEVICE_CODENAME}"  # Device codename - will auto-detect if not set

# Function to print colored messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

echo "======================================"
echo "PixelOS Release Automation (SourceForge)"
echo "======================================"
echo ""

# Allow command line arguments for device and output directory
if [ $# -ge 1 ]; then
    DEVICE=$1
fi

if [ $# -ge 2 ]; then
    OUT_DIR=$2
fi

# Step 1: Auto-detect device if not provided
if [ -z "$DEVICE" ]; then
    print_info "Device codename not provided, attempting auto-detection..."
    
    # Method 1: Check TARGET_PRODUCT environment variable
    if [ -n "$TARGET_PRODUCT" ]; then
        DEVICE=$(echo "$TARGET_PRODUCT" | sed 's/^aosp_//;s/^pixelos_//;s/^custom_//;s/-.*$//')
        print_info "Detected device from TARGET_PRODUCT: ${DEVICE}"
    fi
    
    # Method 2: Look for directories in out/target/product (excluding common non-device dirs)
    if [ -z "$DEVICE" ] && [ -d "$OUT_DIR" ]; then
        DEVICE=$(ls -1 "$OUT_DIR" 2>/dev/null | grep -v "^generic" | grep -v "^emulator" | grep -v "^mainline" | head -1)
        if [ -n "$DEVICE" ]; then
            print_info "Detected device from output directory: ${DEVICE}"
        fi
    fi
    
    # Method 3: Check for boot.img and extract device from path
    if [ -z "$DEVICE" ]; then
        BOOT_PATH=$(find "$OUT_DIR" -name "boot.img" -type f 2>/dev/null | head -1)
        if [ -n "$BOOT_PATH" ]; then
            DEVICE=$(basename $(dirname "$BOOT_PATH"))
            print_info "Detected device from boot.img path: ${DEVICE}"
        fi
    fi
    
    if [ -z "$DEVICE" ]; then
        print_error "Could not auto-detect device codename!"
        echo "Please provide device codename:"
        echo "  DEVICE_CODENAME=xaga ./release-pixelos-sourceforge.sh"
        echo "  OR: ./release-pixelos-sourceforge.sh xaga"
        exit 1
    fi
fi

# Construct the full output path
if [[ "$OUT_DIR" == *"/$DEVICE" ]]; then
    FULL_OUT_DIR="$OUT_DIR"
else
    FULL_OUT_DIR="${OUT_DIR}/${DEVICE}"
fi

print_info "Device: ${DEVICE}"
print_info "Output directory: ${FULL_OUT_DIR}"
echo ""

# Check if output directory exists
if [ ! -d "$FULL_OUT_DIR" ]; then
    print_error "Output directory not found: ${FULL_OUT_DIR}"
    exit 1
fi

# Step 2: Create timestamp for this release
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BUILD_DATE_RAW=${TIMESTAMP:0:8}  # 20260212
BUILD_TIME=${TIMESTAMP:9:6}      # 213518
VERSION="1.0-${BUILD_DATE_RAW}"
BUILD_DATE="${BUILD_DATE_RAW:0:4}-${BUILD_DATE_RAW:4:2}-${BUILD_DATE_RAW:6:2}"

print_info "Version: $VERSION"
print_info "Build Date: $BUILD_DATE"
print_info "Timestamp: $TIMESTAMP"
echo ""

# Step 3: Find ROM files in the output directory
print_info "Searching for ROM files..."

# Find boot.img
BOOT_IMG=$(find "$FULL_OUT_DIR" -name "boot.img" -type f | head -1)
if [ -z "$BOOT_IMG" ]; then
    print_error "boot.img not found in ${FULL_OUT_DIR}"
    exit 1
fi
print_info "Found boot.img: ${BOOT_IMG}"

# Find vendor_boot.img
VENDOR_BOOT_IMG=$(find "$FULL_OUT_DIR" -name "vendor_boot.img" -type f | head -1)
if [ -z "$VENDOR_BOOT_IMG" ]; then
    print_error "vendor_boot.img not found in ${FULL_OUT_DIR}"
    exit 1
fi
print_info "Found vendor_boot.img: ${VENDOR_BOOT_IMG}"

# Find PixelOS zip
ROM_ZIP=$(find "$FULL_OUT_DIR" -name "PixelOS*.zip" -o -name "pixelos*.zip" -o -name "aosp*.zip" 2>/dev/null | head -1)
if [ -z "$ROM_ZIP" ]; then
    # Try finding any zip file
    ROM_ZIP=$(find "$FULL_OUT_DIR" -name "*.zip" -type f 2>/dev/null | head -1)
fi

if [ -z "$ROM_ZIP" ] || [ ! -f "$ROM_ZIP" ]; then
    print_error "ROM ZIP not found in ${FULL_OUT_DIR}"
    exit 1
fi

# Clean the ROM filename (remove device_timestamp_ prefix if present)
ROM_FILENAME=$(basename "$ROM_ZIP")
if [[ "$ROM_FILENAME" =~ ^${DEVICE}_[0-9]{8}_[0-9]{6}_ ]]; then
    ROM_FILENAME=$(echo "$ROM_FILENAME" | sed "s/^${DEVICE}_[0-9]\{8\}_[0-9]\{6\}_//")
fi
print_info "Found ROM: $ROM_FILENAME"

# Find Fastboot zip (optional)
FASTBOOT_ZIP=$(find "$FULL_OUT_DIR" -name "FASTBOOT*.zip" -type f 2>/dev/null | head -1)
if [ -n "$FASTBOOT_ZIP" ] && [ -f "$FASTBOOT_ZIP" ]; then
    FASTBOOT_FILENAME=$(basename "$FASTBOOT_ZIP")
    print_info "Found Fastboot: $FASTBOOT_FILENAME"
else
    print_warning "No fastboot zip found (optional)"
    FASTBOOT_FILENAME=""
fi
echo ""

# Step 4: Upload to SourceForge
SF_PATH="/home/frs/project/${SF_PROJECT}/${DEVICE}"  # SourceForge file release path
UPLOAD_PATH="${DEVICE}/${TIMESTAMP}"

print_info "Uploading files to SourceForge..."
print_info "Target: ${SF_USER}@frs.sourceforge.net:${SF_PATH}/${TIMESTAMP}/"
echo ""

# Create remote directory and upload files
print_info "Creating remote directory..."
ssh ${SF_USER}@frs.sourceforge.net "mkdir -p ${SF_PATH}/${TIMESTAMP}"

print_info "Uploading boot.img..."
scp "$BOOT_IMG" ${SF_USER}@frs.sourceforge.net:${SF_PATH}/${TIMESTAMP}/boot.img

print_info "Uploading vendor_boot.img..."
scp "$VENDOR_BOOT_IMG" ${SF_USER}@frs.sourceforge.net:${SF_PATH}/${TIMESTAMP}/vendor_boot.img

print_info "Uploading ROM ZIP (${ROM_FILENAME})..."
scp "$ROM_ZIP" ${SF_USER}@frs.sourceforge.net:${SF_PATH}/${TIMESTAMP}/${ROM_FILENAME}

if [ -n "$FASTBOOT_FILENAME" ] && [ -f "$FASTBOOT_ZIP" ]; then
  print_info "Uploading Fastboot ZIP..."
  scp "$FASTBOOT_ZIP" ${SF_USER}@frs.sourceforge.net:${SF_PATH}/${TIMESTAMP}/${FASTBOOT_FILENAME}
fi

echo ""
print_info "✅ Upload complete!"
echo ""

# Step 5: Generate SourceForge URLs
# SourceForge URL format: https://sourceforge.net/projects/PROJECT/files/PATH/FILE/download
BOOT_URL="https://sourceforge.net/projects/${SF_PROJECT}/files/${DEVICE}/${TIMESTAMP}/boot.img/download"
VENDOR_BOOT_URL="https://sourceforge.net/projects/${SF_PROJECT}/files/${DEVICE}/${TIMESTAMP}/vendor_boot.img/download"
ROM_URL="https://sourceforge.net/projects/${SF_PROJECT}/files/${DEVICE}/${TIMESTAMP}/${ROM_FILENAME}/download"

if [ -n "$FASTBOOT_FILENAME" ]; then
  FASTBOOT_URL="https://sourceforge.net/projects/${SF_PROJECT}/files/${DEVICE}/${TIMESTAMP}/${FASTBOOT_FILENAME}/download"
else
  FASTBOOT_URL=""
fi

print_info "URLs prepared:"
echo "  Boot: $BOOT_URL"
echo "  Vendor Boot: $VENDOR_BOOT_URL"
echo "  ROM: $ROM_URL"
if [ -n "$FASTBOOT_URL" ]; then
  echo "  Fastboot: $FASTBOOT_URL"
fi
echo ""

# Step 6: Get changelog
print_info "Enter changelog (or press Enter for default):"
read -r CHANGELOG
if [ -z "$CHANGELOG" ]; then
  CHANGELOG="Bug fixes and improvements"
fi
echo ""

# Step 7: Clone/update GitHub repo and modify xaga.json
REPO_DIR="/tmp/pixelos-releases"
echo "Updating xaga.json in GitHub repo..."

# Remove old clone if exists
rm -rf "$REPO_DIR"

# Clone the repo
git clone "https://github.com/${REPO}.git" "$REPO_DIR"
cd "$REPO_DIR" || exit 1

# Check if xaga.json exists
if [ ! -f "xaga.json" ]; then
  echo "Creating new xaga.json..."
  echo '{"response": []}' > xaga.json
fi

# Create the new release entry using jq
NEW_ENTRY=$(cat <<EOF
{
  "version": "$VERSION",
  "date": "$BUILD_DATE",
  "type": "$BUILD_TYPE",
  "changelog": "$CHANGELOG",
  "downloads": {
    "boot_img": "$BOOT_URL",
    "vendor_boot_img": "$VENDOR_BOOT_URL",
    "rom_zip": "$ROM_URL"$([ -n "$FASTBOOT_URL" ] && echo ",
    \"fastboot_zip\": \"$FASTBOOT_URL\"")
  }
}
EOF
)

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "❌ jq is required but not installed. Please install it: sudo apt install jq"
  exit 1
fi

# Add new entry to the beginning of the response array
jq --argjson new "$NEW_ENTRY" '.response = [$new] + .response' xaga.json > xaga.json.tmp
mv xaga.json.tmp xaga.json

# Pretty print the JSON
jq '.' xaga.json > xaga.json.tmp
mv xaga.json.tmp xaga.json

echo ""
echo "Updated xaga.json:"
cat xaga.json
echo ""

# Step 8: Commit and push
echo "Committing changes..."
git config user.name "PixelOS Release Bot"
git config user.email "bot@pixelos.net"
git add xaga.json
git commit -m "Release $VERSION - $BUILD_DATE

Changelog: $CHANGELOG
Build Type: $BUILD_TYPE"

echo "Pushing to GitHub..."
git push

cd - > /dev/null
rm -rf "$REPO_DIR"

echo ""
echo "======================================"
echo "✅ Release Complete!"
echo "======================================"
echo ""
echo "Build: $TIMESTAMP"
echo "Version: $VERSION"
echo "Date: $BUILD_DATE"
echo "Type: $BUILD_TYPE"
echo "Device: $DEVICE"
echo ""
echo "OTA endpoint: https://pixelos-xaga.github.io/pixelos-releases/xaga.json"
echo "GitHub repo: https://github.com/$REPO"
echo ""
