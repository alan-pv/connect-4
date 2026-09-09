#!/usr/bin/env bash
# Exports the Web build and zips it the way itch.io expects: index.html at the
# root of the archive, never inside a folder.
#
# Needs a Godot 4.7 binary on PATH (or GODOT=/path/to/godot) and a Web export
# preset named "Web" in export_presets.cfg.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || command -v godot4 || true)}"
OUT="$ROOT/build/web"
ZIP="$ROOT/build/connect-4-web.zip"

[ -n "$GODOT" ] || { echo "No Godot binary. Set GODOT=/path/to/godot"; exit 1; }
[ -f "$ROOT/export_presets.cfg" ] || { echo "No export_presets.cfg. Create a 'Web' preset in the editor first."; exit 1; }

rm -rf "$OUT" "$ZIP"
mkdir -p "$OUT"

"$GODOT" --headless --path "$ROOT" --export-release "Web" "$OUT/index.html"

[ -f "$OUT/index.html" ] || { echo "Export produced no index.html"; exit 1; }

( cd "$OUT" && zip -qr "$ZIP" . )
echo "Built: $ZIP"
unzip -l "$ZIP" | head -15
