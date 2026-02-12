#!/usr/bin/env bash
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FILE="$ROOT/packages/apps/ParanoidSense/Android.bp"

echo "== ParanoidSense libmegface fix =="

if [ ! -f "$FILE" ]; then
  echo "ERROR: $FILE not found."
  exit 1
fi

# Backup once
if [ ! -f "$FILE.bak" ]; then
  cp "$FILE" "$FILE.bak"
  echo "Backup created: $FILE.bak"
fi

echo "1) Commenting libmegface in required[] list (if present)..."
# Comment the exact dependency line if not already commented
sed -i -E 's/^([[:space:]]*)"libmegface",/\1\/\/ "libmegface",/' "$FILE"

echo "2) Commenting the libmegface module block..."
# Comment the whole cc_* block that contains name: "libmegface"
awk '
  BEGIN { inblock=0 }
  {
    if ($0 ~ /^[[:space:]]*cc_.*\{/ && !inblock) {
      # Potential start of a module; buffer until we know if it contains libmegface
      inblock=1; buf[0]=$0; n=1; next
    }
    if (inblock) {
      buf[n++]=$0
      if ($0 ~ /^[[:space:]]*\}/) {
        # End of block; check if it contains the target name
        has=0
        for (i=0;i<n;i++) {
          if (buf[i] ~ /name:[[:space:]]*"libmegface"/) { has=1; break }
        }
        # Print commented or original
        for (i=0;i<n;i++) {
          if (has && buf[i] !~ /^[[:space:]]*\/\//) {
            print "// " buf[i]
          } else {
            print buf[i]
          }
        }
        inblock=0; n=0
      }
      next
    }
    print $0
  }
' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"

echo "3) Verifying..."
if grep -R 'name:[[:space:]]*"libmegface"' "$FILE" | grep -v '^[[:space:]]*\/\/' >/dev/null; then
  echo "WARNING: Found an uncommented libmegface definition. Please check manually."
else
  echo "OK: libmegface definitions are commented."
fi

echo "Done."
echo "Next steps:"
echo "  rm -rf $ROOT/out/soong"
echo "  (cd $ROOT && mka bacon)"
