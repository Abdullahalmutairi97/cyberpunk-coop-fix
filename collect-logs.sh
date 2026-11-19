#!/usr/bin/env bash
# Collects Cyberpunk 2077 + NightCoop crash logs into one file on the Desktop.
# Run AFTER the crash, with the game closed. It only reads and copies; nothing in the game is changed.
set -uo pipefail

say()  { printf '\n%s\n' "$*"; }
fail() { printf '\nERROR: %s\nTake a photo of this screen and send it to your friend.\n' "$*"; exit 1; }

say "[1/4] Finding Cyberpunk 2077..."
GAME=""; ROOT=""
for root in "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.steam/debian-installation" "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
  if [ -f "$root/steamapps/common/Cyberpunk 2077/bin/x64/Cyberpunk2077.exe" ]; then GAME="$root/steamapps/common/Cyberpunk 2077"; ROOT="$root"; break; fi
done
# Game installed on another drive: look in Steam's library list
if [ -z "$GAME" ]; then
  for vdf in "$HOME"/.local/share/Steam/steamapps/libraryfolders.vdf "$HOME"/.steam/steam/steamapps/libraryfolders.vdf "$HOME"/.var/app/com.valvesoftware.Steam/.local/share/Steam/steamapps/libraryfolders.vdf; do
    [ -f "$vdf" ] || continue
    while IFS= read -r lib; do
      if [ -f "$lib/steamapps/common/Cyberpunk 2077/bin/x64/Cyberpunk2077.exe" ]; then GAME="$lib/steamapps/common/Cyberpunk 2077"; ROOT="$lib"; break 2; fi
    done < <(grep '"path"' "$vdf" | sed 's/.*"path"[[:space:]]*"\(.*\)"/\1/')
  done
fi
[ -n "$GAME" ] || fail "Cyberpunk 2077 was not found."
echo "Found: $GAME"

OUT="$(mktemp -d)/cyberpunk-logs-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

# Copy files changed in the last 2 days (keeps the archive small)
grab() { # source-dir dest-name
  [ -d "$1" ] || return 0
  mkdir -p "$OUT/$2"
  (cd "$1" && find . -maxdepth 2 -type f -mtime -2 \( -name '*.log' -o -name '*.txt' -o -name '*.dmp' -o -name '*.json' \) \
       ! -name 'rtti-names-*' -size -60M -exec cp --parents -t "$OUT/$2" {} + 2>/dev/null)
}

say "[2/4] Copying logs..."
mkdir -p "$OUT/red4ext-logs"
ls -t "$GAME"/red4ext/logs/*.log 2>/dev/null | head -4 | while IFS= read -r f; do cp "$f" "$OUT/red4ext-logs/"; done
# NightCoop: every crash/hang report, plus the 3 newest session logs
NL="$GAME/red4ext/plugins/NightCoop/logs"
if [ -d "$NL" ]; then
  mkdir -p "$OUT/nightcoop-logs"
  find "$NL" -maxdepth 1 -type f -mtime -2 \( -name '*crash*' -o -name '*hang*' -o -name '*exit*' \) -exec cp -t "$OUT/nightcoop-logs" {} + 2>/dev/null
  ls -t "$NL"/nightcoop-session-*.log 2>/dev/null | head -3 | while IFS= read -r f; do cp "$f" "$OUT/nightcoop-logs/"; done
fi
cp "$GAME/red4ext/plugins/NightCoop/nightcoop-crash.log" "$OUT/" 2>/dev/null
tail -n 20000 "$GAME/red4ext/plugins/NightCoop/nightcoop.log" > "$OUT/nightcoop-tail.log" 2>/dev/null
grab "$GAME/r6/logs"                             redscript-logs
grab "$GAME/bin/x64/plugins/cyber_engine_tweaks" cet-logs
grab "$GAME/archive/pc/mod"                      archivexl-logs
# Game crash reports and dumps inside the Proton prefix
PFX="$ROOT/steamapps/compatdata/1091500/pfx/drive_c/users/steamuser"
grab "$PFX/AppData/Local/CD Projekt Red/Cyberpunk 2077" game-appdata
find "$PFX/AppData/Local/CrashDumps" "$GAME/bin/x64" -maxdepth 1 -type f -mtime -2 -name '*.dmp' -size -200M -exec cp -t "$OUT" {} + 2>/dev/null
# Proton log (only exists if PROTON_LOG=1 was in launch options)
cp "$HOME/steam-1091500.log" "$OUT/" 2>/dev/null

say "[3/4] Listing mods and system info..."
{
  echo "== Installed mods =="
  for d in red4ext/plugins r6/scripts r6/tweaks archive/pc/mod bin/x64/plugins/cyber_engine_tweaks/mods mods; do
    echo "--- $d"; ls -la "$GAME/$d" 2>/dev/null
  done
  echo; echo "== Key file versions (sha256) =="
  for f in red4ext/RED4ext.dll bin/x64/winmm.dll bin/x64/version.dll red4ext/plugins/NightCoop/NightCoop.dll \
           red4ext/plugins/Codeware/Codeware.dll red4ext/plugins/ArchiveXL/ArchiveXL.dll red4ext/plugins/TweakXL/TweakXL.dll; do
    [ -f "$GAME/$f" ] && echo "$(sha256sum "$GAME/$f" | cut -c1-16)  $(stat -c '%y' "$GAME/$f" | cut -d. -f1)  $f"
  done
  echo; echo "== Game version =="
  ls -la "$GAME/bin/x64/Cyberpunk2077.exe"
  echo; echo "== System =="
  uname -a
  grep PRETTY_NAME /etc/os-release
  lspci 2>/dev/null | grep -iE 'vga|3d|display'
  glxinfo -B 2>/dev/null | grep -iE 'renderer|version' || echo "(glxinfo not installed)"
  vulkaninfo --summary 2>/dev/null | grep -iE 'deviceName|driverInfo|apiVersion' || echo "(vulkaninfo not installed)"
  free -h
  echo; echo "== Proton / launch options =="
  cat "$ROOT/steamapps/compatdata/1091500/version" 2>/dev/null
  grep -A40 '"1091500"' "$ROOT"/userdata/*/config/localconfig.vdf 2>/dev/null | grep -m1 -i LaunchOptions
  grep -A3 '"1091500"' "$ROOT/config/config.vdf" 2>/dev/null | grep -i name
} > "$OUT/system-and-mods.txt" 2>&1

say "[4/4] Packing..."
DEST="$HOME/Desktop"; [ -d "$DEST" ] || DEST="$HOME"
FILE="$DEST/$(basename "$OUT").tar.gz"
tar -czf "$FILE" -C "$(dirname "$OUT")" "$(basename "$OUT")" || fail "Packing failed."
rm -rf "$(dirname "$OUT")"

say "Done. Send this file to your friend:"
echo "  $FILE  ($(du -h "$FILE" | cut -f1))"
