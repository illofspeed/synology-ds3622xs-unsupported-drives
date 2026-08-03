#!/bin/sh
#
# setup.sh — whitelist non-Synology drives on a Synology NAS (DS3622xs+ etc.)
#
# Downloads a PINNED release of 007revad/Synology_HDD_db and runs it with the
# flags that are correct for an unsupported HDD + M.2 read-write-cache setup.
#
#   IMPORTANT: this intentionally does NOT pass --force.
#   --force sets support_disk_compatibility="no", which makes DSM classify the
#   M.2 NVMe as "disabled" and force them read-only. Leaving it off lets DSM
#   verify the drives against the DB entries we add and classify them "support".
#
# Run as root (Boot-up task user = root):
#   sudo /volume1/scripts/setup.sh
#
set -e

# --- config -----------------------------------------------------------------
# Pin to a reviewed release tag (not 'master') so a daily root task can't run
# silently-changed upstream code. Bump after reviewing a newer release.
HDD_DB_VERSION="v3.6.137"
SCRIPT_DIR="/volume1/scripts"
HDD_DB="${SCRIPT_DIR}/syno_hdd_db.sh"
HDD_DB_URL="https://raw.githubusercontent.com/007revad/Synology_HDD_db/${HDD_DB_VERSION}/syno_hdd_db.sh"

# Flags: add to DB + freeze auto-update + WDDA off + RAM warning off + no ANSI
# colours in output (--email; upstream >= v3.6.135 also auto-detects scheduler
# runs). NO --force.
HDD_DB_FLAGS="--noupdate --wdda --ram --email"
# ----------------------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)."; exit 1; }
mkdir -p "$SCRIPT_DIR"

# Fetch the pinned script if missing or if the local copy is another version
# (so bumping HDD_DB_VERSION above actually refreshes an existing install).
# Keep the local copy; tasks run it offline. A failed download never clobbers
# a working copy — we fall back to whatever version is already there.
local_ver=""
[ -f "$HDD_DB" ] && local_ver=$(grep -m1 '^scriptver=' "$HDD_DB" | cut -d'"' -f2)
if [ "$local_ver" != "$HDD_DB_VERSION" ]; then
    echo "[*] Downloading Synology_HDD_db ${HDD_DB_VERSION} (local: ${local_ver:-none}) ..."
    dl_ok=1
    if command -v curl >/dev/null 2>&1; then
        curl -fL -o "${HDD_DB}.new" "$HDD_DB_URL" || dl_ok=0
    else
        wget -O "${HDD_DB}.new" "$HDD_DB_URL" || dl_ok=0
    fi
    if [ "$dl_ok" -eq 1 ] && grep -q "^scriptver=\"${HDD_DB_VERSION}\"" "${HDD_DB}.new"; then
        chmod 755 "${HDD_DB}.new"
        mv "${HDD_DB}.new" "$HDD_DB"
        echo "[*] Saved -> $HDD_DB  (review it once: less $HDD_DB)"
    elif [ -f "$HDD_DB" ]; then
        rm -f "${HDD_DB}.new"
        echo "[!] WARNING: download failed/invalid; keeping local ${local_ver:-unknown}."
    else
        rm -f "${HDD_DB}.new"
        echo "ERROR: download failed and no local copy exists."
        exit 1
    fi
fi

echo "[*] Applying whitelist: $HDD_DB $HDD_DB_FLAGS"
# Strip ANSI colour codes so Task Scheduler emails are readable.
# 2>&1 so the upstream script's stderr lines (e.g. "already exists", ERROR 5)
# also pass through the colour stripper instead of leaking raw escape codes.
"$HDD_DB" $HDD_DB_FLAGS 2>&1 | sed 's/\x1b\[[0-9;]*m//g'

cat <<'EOF'

[+] Whitelist applied.
    - First time / after a DSM update: REBOOT so DSM re-classifies the drives.
    - To (re)create a read-write M.2 cache, use:  m2-cache.sh hold-rw   (see README)
    - Sanity check anytime:                       m2-cache.sh status
EOF
