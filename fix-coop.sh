#!/usr/bin/env bash
# Cyberpunk 2077 co-op crash fix: NightCoop 0.2.1-beta, Codeware 1.21.4, RED4ext 1.31.1, flight mod off.
# Run with the game closed. Safe to run twice. Nothing is deleted: old files are backed up or moved aside.
set -euo pipefail

URL="https://nightcoop.net/dl/0.2.1-beta/NightCoop-0.2.1-beta-2.5.zip"
SHA="fa6e6eb24dd935cac432da3f58736ab6a76633f05c28615a0aa05ca54d7c4807"
CW_URL="https://github.com/psiberx/cp2077-codeware/releases/download/v1.21.4/Codeware-1.21.4.zip"
CW_SHA="cb929d1edb72e23d7e7cc6420014b6557c363992ed6092c8453be9b185d0376b"
R4_URL="https://github.com/wopss/RED4ext/releases/download/v1.31.1/red4ext-1.31.1.zip"
R4_SHA="ce10bda503fd48c8674ef3e517d635636a262c089055f189caabeb300eef7932"

say()  { printf '\n%s\n' "$*"; }
fail() { printf '\nERROR: %s\nTake a photo of this screen and send it to your friend.\n' "$*"; exit 1; }

for t in curl unzip sha256sum; do
  command -v "$t" >/dev/null || fail "'$t' is missing. Run: sudo apt install curl unzip   (then run this again)"
done

say "[1/5] Finding Cyberpunk 2077..."
GAME=""
for root in "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.steam/debian-installation" "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
  if [ -f "$root/steamapps/common/Cyberpunk 2077/bin/x64/Cyberpunk2077.exe" ]; then GAME="$root/steamapps/common/Cyberpunk 2077"; ROOT="$root"; break; fi
done
[ -n "$GAME" ] || fail "Cyberpunk 2077 was not found."
echo "Found: $GAME"
if ps -eo comm= | grep -qE '^(Cyberpunk2077|REDprelauncher)'; then
  fail "The game is open. Close Cyberpunk 2077, then run this again."
fi

say "[2/5] Downloading NightCoop 0.2.1-beta, Codeware 1.21.4, RED4ext 1.31.1 (14 MB)..."
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
get() { # file url sha
  curl -fsSL --retry 3 -o "$TMP/$1" "$2" || fail "Download failed ($1). Check your internet and run again."
  [ "$(sha256sum "$TMP/$1" | cut -d' ' -f1)" = "$3" ] || fail "$1 does not match its checksum. Run this again."
}
get nc.zip "$URL" "$SHA"; get cw.zip "$CW_URL" "$CW_SHA"; get r4.zip "$R4_URL" "$R4_SHA"
echo "Checksums OK"

say "[3/5] Backing up..."
STAMP=$(date +%Y%m%d-%H%M%S)
B="$HOME/cyberpunk-backups/pre-0.2.1-$STAMP"
mkdir -p "$B"
if [ -d "$GAME/red4ext/plugins/NightCoop" ]; then
  mkdir -p "$B/NightCoop"
  (cd "$GAME/red4ext/plugins/NightCoop" && tar --exclude=./logs --exclude='./rtti-names-*' --exclude=./nightcoop.log -cf - .) | tar -xf - -C "$B/NightCoop"
fi
[ -d "$GAME/red4ext/plugins/Codeware" ] && cp -r "$GAME/red4ext/plugins/Codeware" "$B/Codeware"
cp "$GAME/red4ext/RED4ext.dll" "$GAME/bin/x64/winmm.dll" "$B/" 2>/dev/null || true
SAVES="$ROOT/steamapps/compatdata/1091500/pfx/drive_c/users/steamuser/Saved Games/CD Projekt Red/Cyberpunk 2077"
[ -d "$SAVES" ] && cp -r "$SAVES" "$B/saves"
echo "Backup: $B"

say "[4/5] Turning off the flight mod (it crashes and breaks sync)..."
D="$HOME/cyberpunk-disabled-mods"; mkdir -p "$D"
for p in "red4ext/plugins/let_there_be_flight" "red4ext/plugins/let_there_be_flight_uninstall.bat" "r6/scripts/NightCoopFlight"; do
  if [ -e "$GAME/$p" ]; then rm -rf "$D/$(basename "$p")"; mv "$GAME/$p" "$D/"; echo "moved aside: $p"; fi
done

say "[5/5] Installing..."
unzip -oq "$TMP/nc.zip" -x 'r6/scripts/NightCoopFlight/*' -d "$GAME" || fail "Installing NightCoop failed."
unzip -oq "$TMP/cw.zip" -d "$GAME" || fail "Installing Codeware failed."
unzip -oq "$TMP/r4.zip" -d "$GAME" || fail "Installing RED4ext failed."
rm -f "$GAME/r6/cache/final.redscripts.modded"
[ -f "$GAME/red4ext/plugins/NightCoop/NightCoop.dll" ] || fail "NightCoop.dll is missing after install."

say "Done. Start the game from Steam as usual. You and your friend must both be on 0.2.1-beta."
