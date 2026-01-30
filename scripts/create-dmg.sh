#!/bin/bash
set -euo pipefail

APP_PATH="${1:?Usage: $0 /path/to/GestureCode.app}"
OUTPUT="$(dirname "$APP_PATH")/GestureCode.dmg"

if [ ! -d "$APP_PATH" ]; then
  echo "Error: $APP_PATH not found"
  exit 1
fi

echo "Creating DMG..."
rm -f "$OUTPUT"
create-dmg \
  --volname "GestureCode" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "GestureCode.app" 150 190 \
  --app-drop-link 450 190 \
  "$OUTPUT" \
  "$APP_PATH"

echo "Done: $OUTPUT"
