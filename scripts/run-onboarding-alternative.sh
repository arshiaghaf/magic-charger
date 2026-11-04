#!/bin/sh
# Local comparison build. Does not install or modify the standard app bundle.
set -eu
cd "$(dirname "$0")/.."
sh build-app.sh
SOURCE="build/Magic Charger.app"
PREVIEW="build/Magic Charger — Quiet Current.app"
if [ -e "$PREVIEW" ]; then
    # Preserve earlier local builds so a running preview is never overwritten.
    PREVIEW="build/Magic Charger — Quiet Current $(date +%Y%m%d-%H%M%S).app"
fi
ditto "$SOURCE" "$PREVIEW"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier co.arshia.magiccharger.alternative.quietcurrent' "$PREVIEW/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Magic Charger — Quiet Current' "$PREVIEW/Contents/Info.plist"
codesign --force --sign - "$PREVIEW"
codesign --verify --deep --strict "$PREVIEW"
printf 'Opening the local alternative: %s\n' "$PREVIEW"
open -n "$PREVIEW"
