#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

KEYS_DIR="${HOME}/android-keys"
SUBJECT="/C=US/ST=California/L=Mountain View/O=PixelOS/OU=Release/CN=PixelOS Release Key"

usage() {
  cat <<'EOF'
Usage: ./setup_signing_keys.sh [options]

Options:
  --keys-dir <path>   Output key directory (default: ~/android-keys)
  --subject <dn>      Certificate subject (default: PixelOS release DN)
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keys-dir)
      KEYS_DIR="$2"
      shift 2
      ;;
    --subject)
      SUBJECT="$2"
      shift 2
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

MAKE_KEY_TOOL=""
for candidate in \
  "${ROOT_DIR}/development/tools/make_key" \
  "${ROOT_DIR}/build/make/tools/releasetools/make_key"; do
  if [[ -x "${candidate}" ]]; then
    MAKE_KEY_TOOL="${candidate}"
    break
  fi
done

if [[ -z "${MAKE_KEY_TOOL}" ]]; then
  echo "Could not find make_key tool. Expected one of:" >&2
  echo "  development/tools/make_key" >&2
  echo "  build/make/tools/releasetools/make_key" >&2
  exit 1
fi

mkdir -p "${KEYS_DIR}"
chmod 700 "${KEYS_DIR}" || true

KEY_NAMES=(
  releasekey
  platform
  shared
  media
  networkstack
  testcert
)

for name in "${KEY_NAMES[@]}"; do
  pk8="${KEYS_DIR}/${name}.pk8"
  pem="${KEYS_DIR}/${name}.x509.pem"

  if [[ -f "${pk8}" && -f "${pem}" ]]; then
    echo "Key exists, skipping: ${name}"
    continue
  fi

  if [[ -f "${pk8}" || -f "${pem}" ]]; then
    echo "Partial key material exists for ${name}. Fix manually before continuing:" >&2
    echo "  ${pk8}" >&2
    echo "  ${pem}" >&2
    exit 1
  fi

  echo "Generating key: ${name}"
  "${MAKE_KEY_TOOL}" "${KEYS_DIR}/${name}" "${SUBJECT}"
done

chmod 600 "${KEYS_DIR}"/*.pk8
chmod 644 "${KEYS_DIR}"/*.x509.pem

echo "Signing keys ready in: ${KEYS_DIR}"
