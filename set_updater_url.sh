#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(pwd)"
STRINGS_FILE="packages/apps/Updater/app/src/main/res/values/strings.xml"
TARGET_FILE=""
DEFAULT_UPDATER_URL="https://raw.githubusercontent.com/Pixelos-xaga/pixelos-releases/refs/heads/main/updates.json"
DEFAULT_CHANGELOG_URL="https://raw.githubusercontent.com/Pixelos-xaga/pixelos-releases/refs/heads/main/xaga.md"
UPDATER_URL="${DEFAULT_UPDATER_URL}"
CHANGELOG_URL="${DEFAULT_CHANGELOG_URL}"

usage() {
  cat <<'EOF'
Usage: ./set_updater_url.sh [--url <updates-json-url>] [--changelog-url <changelog-md-url>] [--source-root <path>] [--file <strings.xml path>]

Options:
  --url <url>     Updater feed URL (default: Pixelos-xaga/pixelos-releases raw updates.json)
  --changelog-url <url>
                  Changelog markdown URL (default: Pixelos-xaga/pixelos-releases raw xaga.md)
  --source-root <path>
                  Android source root (default: current directory)
  --file <path>   Override target strings.xml path
  -h, --help      Show this help

Example:
  ./set_updater_url.sh --source-root ~/android/pixelos --url https://ota.example.com/xaga/updates.json --changelog-url https://ota.example.com/xaga/changelog.md
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      UPDATER_URL="$2"
      shift 2
      ;;
    --changelog-url)
      CHANGELOG_URL="$2"
      shift 2
      ;;
    --source-root)
      SOURCE_ROOT="$2"
      shift 2
      ;;
    --file)
      STRINGS_FILE="$2"
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

if [[ "${STRINGS_FILE}" = /* ]]; then
  TARGET_FILE="${STRINGS_FILE}"
else
  TARGET_FILE="${SOURCE_ROOT}/${STRINGS_FILE}"
fi

if [[ ! -f "${TARGET_FILE}" ]]; then
  echo "File not found: ${TARGET_FILE}" >&2
  echo "Pass --source-root <android-root> or --file <absolute-path>." >&2
  exit 1
fi

if ! grep -q 'name="updater_server_url"' "${TARGET_FILE}"; then
  echo "Could not find <string name=\"updater_server_url\"> in ${TARGET_FILE}" >&2
  exit 1
fi

if ! grep -q 'name="changelog_url"' "${TARGET_FILE}"; then
  echo "Could not find <string name=\"changelog_url\"> in ${TARGET_FILE}" >&2
  exit 1
fi

# Replace only the updater_server_url string value while preserving its tag.
sed -Ei 's#(<string[[:space:]]+name="updater_server_url"[^>]*>)[^<]*(</string>)#\1'"${UPDATER_URL}"'\2#' "${TARGET_FILE}"
sed -Ei 's#(<string[[:space:]]+name="changelog_url"[^>]*>)[^<]*(</string>)#\1'"${CHANGELOG_URL}"'\2#' "${TARGET_FILE}"

echo "Updated updater_server_url and changelog_url in ${TARGET_FILE}"
grep -n 'name="updater_server_url"' "${TARGET_FILE}" | head -n 1
grep -n 'name="changelog_url"' "${TARGET_FILE}" | head -n 1
