#!/usr/bin/env bash
# Captures fixed notch states from the debug build, verifies panel sizes and compares the
# shape/alpha mask against a committed golden set. Dynamic clock/media content is ignored;
# the PNGs remain available for manual visual review.
#
# Usage:
#   ./Scripts/parity.sh             compare against Docs/Images/Parity-Golden
#   ./Scripts/parity.sh --update    replace the golden set with this run
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
OUT="$ROOT/build/Parity"
GOLDEN="$ROOT/Docs/Images/Parity-Golden"
BIN="$OUT/bin"
UPDATE=0
[[ "${1:-}" == "--update" ]] && UPDATE=1

mkdir -p "$OUT" "$BIN" "$GOLDEN"
swiftc -O -o "$BIN/parity-notify" Scripts/Parity/notify.swift
swiftc -O -o "$BIN/parity-window" Scripts/Parity/window-id.swift
swiftc -O -o "$BIN/parity-diff" Scripts/Parity/diff.swift

BEFORE="$(mktemp)"
HAVE_DEFAULTS=0
if defaults export com.j4yop.arrowslit "$BEFORE" >/dev/null 2>&1; then HAVE_DEFAULTS=1; fi
cleanup() {
    killall Arrowslit 2>/dev/null || true
    sleep 0.4
    if [[ "$HAVE_DEFAULTS" == "1" ]]; then
        defaults import com.j4yop.arrowslit "$BEFORE" >/dev/null 2>&1 || true
    fi
    rm -f "$BEFORE"
}
trap cleanup EXIT

pkill -f '/tmp/vdisplay' 2>/dev/null || true
killall Arrowslit 2>/dev/null || true
sleep 0.5
defaults write com.j4yop.arrowslit arrowslit.display -string automatic
defaults write com.j4yop.arrowslit arrowslit.openSettingsOnLaunch -bool false

CONFIG=debug VERSION=0.10.0 BUILD_NUMBER=35 ./Scripts/build-app.sh >/tmp/parity-build.log 2>&1
"$ROOT/build/Arrowslit.app/Contents/MacOS/Arrowslit" >/tmp/parity-app.log 2>&1 &
sleep 3

STATES=(
  "compact|parity-compact|274x32|0.9"
  "home|parity-home|560x178|1.0"
  "elongated|parity-elongated|1240x178|1.0"
  "launcher|parity-launcher|560x228|1.0"
  "tray|parity-tray|560x178|1.0"
  "clipboard|parity-clipboard|560x178|1.0"
  "hud|parity-hud|340x32|0.45"
  "goal|parity-goal||0.6"
  "nowplaying|parity-nowplaying|390x218|1.0"
  "agent|parity-agent||0.6"
)

REPORT="$OUT/report.md"
{
    echo "# Notch parity report"
    echo
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    echo "| State | Theme | Expected | Actual | Size | Shape mask |"
    echo "| :--- | :--- | :--- | :--- | :--- | :--- |"
} > "$REPORT"

FAIL=0
for spec in "${STATES[@]}"; do
    IFS='|' read -r name command expected delay <<< "$spec"
    "$BIN/parity-notify" "$command"
    sleep "$delay"
    WINDOW="$("$BIN/parity-window" || true)"
    if [[ -z "$WINDOW" ]]; then
        echo "| $name | black | $expected | missing window | ✗ | — |" >> "$REPORT"
        FAIL=1
        continue
    fi
    read -r id width height <<< "$WINDOW"
    FILE="$OUT/$name.png"
    screencapture -x -o -l "$id" "$FILE"
    ACTUAL="${width}x${height}"
    SIZE="—"
    if [[ -n "$expected" ]]; then
        ew="${expected%x*}"; eh="${expected#*x}"
        if (( width >= ew - 2 && width <= ew + 2 && height >= eh - 2 && height <= eh + 2 )); then
            SIZE="✓"
        else
            SIZE="✗"
            FAIL=1
        fi
    fi
    DIFF="baseline"
    GOLD="$GOLDEN/$name.png"
    if [[ "$UPDATE" == "1" ]]; then
        cp "$FILE" "$GOLD"
        DIFF="updated"
    elif [[ -f "$GOLD" ]]; then
        if RESULT="$("$BIN/parity-diff" "$GOLD" "$FILE" 2>&1)"; then
            DIFF="✓ $RESULT"
        else
            DIFF="✗ $RESULT"
            FAIL=1
        fi
    else
        DIFF="no golden"
    fi
    echo "| $name | black | $expected | $ACTUAL | $SIZE | $DIFF |" >> "$REPORT"
done

"$BIN/parity-notify" parity-reset
sleep 0.5
{
    echo
    echo "Shape comparison uses the alpha channel only, so clock, media and calendar text can"
    echo "change without false failures. Review the PNGs in \`build/Parity/\` for visual parity;"
    echo "Glass/backdrop states are manual-review by design."
} >> "$REPORT"
cat "$REPORT"
if [[ "$FAIL" != "0" ]]; then
    echo "Parity check failed" >&2
    exit 1
fi
echo "Parity check passed"
