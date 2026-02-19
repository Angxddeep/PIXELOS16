#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

DEVICE="xaga"
VARIANT="user"
MODE="super"
JOBS="$(nproc)"
KEYS_DIR=""
SIGN=false
GENERATE_KEYS=false

usage() {
  cat <<'EOF'
Usage: ./build_xaga.sh [options]

Options:
  --mode <super|ota-extract>   Build mode (default: super)
  --device <codename>          Device codename (default: xaga)
  --variant <user|userdebug>   Build variant (default: user)
  --jobs <n>                   Parallel jobs for m (default: nproc)
  --keys-dir <path>            Release keys dir for signing target-files
  --sign                       Sign OTA/images output (ota-extract mode)
  --generate-keys              Generate missing keys in --keys-dir
  -h, --help                   Show this help

Examples:
  ./build_xaga.sh --mode super
  ./build_xaga.sh --mode ota-extract
  ./build_xaga.sh --mode ota-extract --sign
  ./build_xaga.sh --mode ota-extract --sign --generate-keys
  ./build_xaga.sh --mode ota-extract --keys-dir ~/android-keys
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --device)
      DEVICE="$2"
      shift 2
      ;;
    --variant)
      VARIANT="$2"
      shift 2
      ;;
    --jobs)
      JOBS="$2"
      shift 2
      ;;
    --keys-dir)
      KEYS_DIR="$2"
      shift 2
      ;;
    --sign)
      SIGN=true
      shift
      ;;
    --generate-keys)
      GENERATE_KEYS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ "${MODE}" != "super" && "${MODE}" != "ota-extract" ]]; then
  echo "Invalid mode: ${MODE}. Use super or ota-extract." >&2
  exit 1
fi

if [[ "${SIGN}" == true && "${MODE}" != "ota-extract" ]]; then
  echo "--sign is only supported with --mode ota-extract." >&2
  exit 1
fi

if [[ "${SIGN}" == true && -z "${KEYS_DIR}" ]]; then
  KEYS_DIR="${HOME}/android-keys"
fi

DO_SIGN=false
if [[ "${SIGN}" == true || -n "${KEYS_DIR}" ]]; then
  DO_SIGN=true
fi

if [[ "${DO_SIGN}" == true ]]; then
  if [[ "${GENERATE_KEYS}" == true ]]; then
    "${ROOT_DIR}/setup_signing_keys.sh" --keys-dir "${KEYS_DIR}"
  fi

  REQUIRED_KEYS=(
    releasekey
    platform
    shared
    media
    networkstack
  )
  for key in "${REQUIRED_KEYS[@]}"; do
    if [[ ! -f "${KEYS_DIR}/${key}.pk8" || ! -f "${KEYS_DIR}/${key}.x509.pem" ]]; then
      echo "Missing key pair: ${KEYS_DIR}/${key}.pk8 and ${KEYS_DIR}/${key}.x509.pem" >&2
      echo "Use --generate-keys to create missing keys automatically." >&2
      exit 1
    fi
  done
fi

if [[ ! -f build/envsetup.sh ]]; then
  echo "build/envsetup.sh not found. Run this from your Android source root." >&2
  exit 1
fi

echo "[1/4] Sourcing build environment"
source build/envsetup.sh

echo "[2/4] Running breakfast ${DEVICE} ${VARIANT}"
breakfast "${DEVICE}" "${VARIANT}"

PRODUCT_OUT="out/target/product/${DEVICE}"
TARGET_FILES_DIR="out/obj/PACKAGING/target_files_intermediates"

if [[ "${MODE}" == "super" ]]; then
  echo "[3/4] Building superimage via m -j${JOBS} pixelos superimage"
  m -j"${JOBS}" pixelos superimage
  echo "[4/4] Done. Check ${PRODUCT_OUT}"
  exit 0
fi

echo "[3/4] Building target-files and otatools"
m -j"${JOBS}" target-files-package otatools

mkdir -p "${PRODUCT_OUT}"

LATEST_TARGET_FILES="$(ls -1t "${TARGET_FILES_DIR}"/*-target_files-*.zip 2>/dev/null | head -n 1 || true)"
if [[ -z "${LATEST_TARGET_FILES}" ]]; then
  echo "Could not find target-files zip in ${TARGET_FILES_DIR}" >&2
  exit 1
fi

EXTRACT_FROM_ZIP="${LATEST_TARGET_FILES}"

if [[ "${DO_SIGN}" == true ]]; then
  mkdir -p out/signed
  SIGNED_TARGET_FILES="out/signed/signed-target_files.zip"
  SIGNED_OTA="out/signed/signed-ota.zip"

  echo "[4/4] Signing target-files with keys in ${KEYS_DIR}"
  out/host/linux-x86/bin/sign_target_files_apks -o \
    -d "${KEYS_DIR}" \
    "${LATEST_TARGET_FILES}" \
    "${SIGNED_TARGET_FILES}"

  out/host/linux-x86/bin/ota_from_target_files \
    -k "${KEYS_DIR}/releasekey" \
    "${SIGNED_TARGET_FILES}" \
    "${SIGNED_OTA}"

  EXTRACT_FROM_ZIP="${SIGNED_TARGET_FILES}"
fi

EXTRACT_DIR="${PRODUCT_OUT}/images_from_target_files"
rm -rf "${EXTRACT_DIR}"
mkdir -p "${EXTRACT_DIR}"

echo "Extracting IMAGES/*.img from: ${EXTRACT_FROM_ZIP}"
unzip -oj "${EXTRACT_FROM_ZIP}" "IMAGES/*.img" -d "${EXTRACT_DIR}" >/dev/null

echo "Copying extracted images into ${PRODUCT_OUT}"
cp -af "${EXTRACT_DIR}"/*.img "${PRODUCT_OUT}/"

echo "Done."
echo "Target-files: ${LATEST_TARGET_FILES}"
[[ "${DO_SIGN}" == true ]] && echo "Signed OTA: out/signed/signed-ota.zip"
echo "Images: ${EXTRACT_DIR} and ${PRODUCT_OUT}"
