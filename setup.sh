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
HDD_DB_VERSION="v3.6.132"
SCRIPT_DIR="/volume1/scripts"
HDD_DB="${SCRIPT_DIR}/syno_hdd_db.sh"
HDD_DB_URL="https://raw.githubusercontent.com/007revad/Synology_HDD_db/${HDD_DB_VERSION}/syno_hdd_db.sh"

# Flags: add to DB + freeze auto-update + WDDA off + RAM warning off. NO --force.
HDD_DB_FLAGS="--noupdate --wdda --ram"
# ----------------------------------------------------------------------------

[ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)."; exit 1; }
mkdir -p "$SCRIPT_DIR"

# Fetch the pinned script if missing (keep the local copy; tasks run it offline).
if [ ! -f "$HDD_DB" ]; then
    echo "[*] Downloading Synology_HDD_db ${HDD_DB_VERSION} ..."
    if command -v curl >/dev/null 2>&1; then
        curl -fL -o "$HDD_DB" "$HDD_DB_URL"
    else
        wget -O "$HDD_DB" "$HDD_DB_URL"
    fi
    chmod 755 "$HDD_DB"
    echo "[*] Saved -> $HDD_DB  (review it once: less $HDD_DB)"
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
