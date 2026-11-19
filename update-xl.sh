#!/usr/bin/env bash
# Updates ArchiveXL to 1.28.8 and TweakXL to 1.12.2 so both players match.
# Run with the game closed. The old versions are backed up first.
set -euo pipefail

AX_URL="https://github.com/psiberx/cp2077-archive-xl/releases/download/v1.28.8/ArchiveXL-1.28.8.zip"
AX_SHA="b2a1c5777d3d0484475e1a1c034a1dc1dcada386595335e480c134fe7128a270"
TX_URL="https://github.com/psiberx/cp2077-tweak-xl/releases/download/v1.12.2/TweakXL-1.12.2.zip"
TX_SHA="b416a3d063823b347e933c30f7acafb1539813e9a36cce89d282f3b649705128"

say()  { printf '\n%s\n' "$*"; }
fail() { printf '\nERROR: %s\nTake a photo of this screen and send it to your friend.\n' "$*"; exit 1; }

for t in curl unzip sha256sum; do
  command -v "$t" >/dev/null || fail "'$t' is missing. Run: sudo apt install curl unzip   (then run this again)"
done

say "[1/4] Finding Cyberpunk 2077..."
GAME=""
for root in "$HOME/.local/share/Steam" "$HOME/.steam/steam" "$HOME/.steam/debian-installation" "$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam"; do
  if [ -f "$root/steamapps/common/Cyberpunk 2077/bin/x64/Cyberpunk2077.exe" ]; then GAME="$root/steamapps/common/Cyberpunk 2077"; break; fi
done
[ -n "$GAME" ] || fail "Cyberpunk 2077 was not found."
echo "Found: $GAME"
if ps -eo comm= | grep -qE '^(Cyberpunk2077|REDprelauncher)'; then
  fail "The game is open. Close Cyberpunk 2077, then run this again."
fi

say "[2/4] Downloading ArchiveXL 1.28.8 and TweakXL 1.12.2..."
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
get() { # file url sha
  curl -fsSL --retry 3 -o "$TMP/$1" "$2" || fail "Download failed ($1). Check your internet and run again."
  [ "$(sha256sum "$TMP/$1" | cut -d' ' -f1)" = "$3" ] || fail "$1 does not match its checksum. Run this again."
}
get ax.zip "$AX_URL" "$AX_SHA"; get tx.zip "$TX_URL" "$TX_SHA"
echo "Checksums OK"

say "[3/4] Backing up the old versions..."
B="$HOME/cyberpunk-backups/pre-xl-update-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$B"
for p in ArchiveXL TweakXL; do
  [ -d "$GAME/red4ext/plugins/$p" ] && cp -r "$GAME/red4ext/plugins/$p" "$B/"
done
echo "Backup: $B"

say "[4/4] Installing..."
unzip -oq "$TMP/ax.zip" -d "$GAME" || fail "Installing ArchiveXL failed."
unzip -oq "$TMP/tx.zip" -d "$GAME" || fail "Installing TweakXL failed."
rm -f "$GAME/r6/cache/final.redscripts.modded"
[ -f "$GAME/red4ext/plugins/ArchiveXL/ArchiveXL.dll" ] && [ -f "$GAME/red4ext/plugins/TweakXL/TweakXL.dll" ] || fail "A file is missing after install."

say "Done. ArchiveXL 1.28.8 and TweakXL 1.12.2 are installed. Start the game from Steam as usual."
