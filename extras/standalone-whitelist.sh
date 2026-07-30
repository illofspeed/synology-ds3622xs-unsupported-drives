#!/bin/bash
#
# synology_drive_support.sh
# Make unofficial HDDs and M.2 NVMe SSDs "supported" on a Synology DS3622xs+ (DSM 7.x).
#
#   - Injects detected non-Synology drive models into the disk-compatibility DBs
#     (host DB for HDDs/SATA-SSDs, M.2 adapter DBs for NVMe cache).
#   - Sets support_disk_compatibility="no" and support_memory_compatibility="no"
#     in both /etc/synoinfo.conf and /etc.defaults/synoinfo.conf.
#   - Keeps a pristine "original" backup so --revert always works.
#
# Modes:
#   sudo ./synology_drive_support.sh            apply (default)
#   sudo ./synology_drive_support.sh --dry-run  show what would change, change nothing
#   sudo ./synology_drive_support.sh --status   show current flag/DB state
#   sudo ./synology_drive_support.sh --revert    restore the original backup
#
set -euo pipefail

STATE_DIR="/usr/local/etc/synology_drive_support"
BACKUP_ROOT="${STATE_DIR}/backups"
ORIG_BACKUP="${BACKUP_ROOT}/original"
DB_DIR="/var/lib/disk-compatibility"
CONF_FILES=("/etc/synoinfo.conf" "/etc.defaults/synoinfo.conf")
FLAGS=("support_disk_compatibility" "support_memory_compatibility")
TS="$(date +%Y%m%d-%H%M%S)"

DRY_RUN=0
MODE="apply"

log()  { printf '[*] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1
[[ "${1:-}" == "--revert"  ]] && MODE="revert"
[[ "${1:-}" == "--status"  ]] && MODE="status"

[[ $EUID -eq 0 ]] || die "Run as root (sudo)."

MODEL_ID="$(cat /proc/sys/kernel/syno_hw_version 2>/dev/null || true)"
[[ -n "$MODEL_ID" ]] || die "Could not read model id."
log "Model: ${MODEL_ID}"

# ---------------------------------------------------------------------------
# status
# ---------------------------------------------------------------------------
show_status() {
    echo "--- synoinfo.conf flags ---"
    for f in "${CONF_FILES[@]}"; do
        echo "  $f:"
        grep -E "$(IFS='|'; echo "${FLAGS[*]}")|support_m2_pool" "$f" 2>/dev/null | sed 's/^/    /' || true
    done
    echo "--- detected non-Synology drives ---"
    detect_drives
    printf '  HDD/SATA models: %s\n' "${HDD_MODELS[*]:-(none)}"
    printf '  NVMe models    : %s\n' "${NVME_MODELS[*]:-(none)}"
}

# ---------------------------------------------------------------------------
# drive detection -> HDD_MODELS / NVME_MODELS  (+ SIZE map by model)
# ---------------------------------------------------------------------------
declare -A MODEL_SIZE_GB
HDD_MODELS=()
NVME_MODELS=()

is_synology_model() {
    # Synology first-party drives are already supported; skip them.
    case "$1" in
        HAT*|SAT*|SNV*|HAS*) return 0 ;;
        *) return 1 ;;
    esac
}

trim_model() {
    # collapse runs of whitespace, strip leading/trailing space
    printf '%s' "$1" | tr -s ' ' ' ' | sed 's/^ *//; s/ *$//'
}

add_model() {
    # $1=array-name $2=model $3=size_gb ; de-dupes
    local -n arr="$1"; local m="$2"; local sz="$3"
    [[ -n "$m" ]] || return 0
    MODEL_SIZE_GB["$m"]="$sz"
    local x; for x in "${arr[@]:-}"; do [[ "$x" == "$m" ]] && return 0; done
    arr+=("$m")
}

detect_drives() {
    HDD_MODELS=(); NVME_MODELS=(); MODEL_SIZE_GB=()
    local d model vendor sectors sz

    # SATA/SAS HDDs and SATA SSDs
    for d in /sys/block/sd*; do
        [[ -e "$d/device/model" ]] || continue
        model="$(trim_model "$(cat "$d/device/model" 2>/dev/null)")"
        vendor="$(trim_model "$(cat "$d/device/vendor" 2>/dev/null || true)")"
        [[ "$vendor" == "Synology" ]] && continue
        is_synology_model "$model" && continue
        sectors="$(cat "$d/size" 2>/dev/null || echo 0)"
        sz=$(( sectors / 2 / 1024 / 1024 ))   # sectors(512B) -> GB
        # primary key: full trimmed model (e.g. "WDC WUH721818ALE6L0")
        add_model HDD_MODELS "$model" "$sz"
        # secondary key: drop a leading vendor token (e.g. "WUH721818ALE6L0")
        if [[ "$model" == *" "* ]]; then
            add_model HDD_MODELS "${model#* }" "$sz"
        fi
    done

    # NVMe
    for d in /sys/block/nvme*; do
        [[ -e "$d/device/model" ]] || continue
        model="$(trim_model "$(cat "$d/device/model" 2>/dev/null)")"
        is_synology_model "$model" && continue
        sectors="$(cat "$d/size" 2>/dev/null || echo 0)"
        sz=$(( sectors / 2 / 1024 / 1024 ))
        add_model NVME_MODELS "$model" "$sz"
    done
}

# ---------------------------------------------------------------------------
# backups
# ---------------------------------------------------------------------------
make_backup() {
    local dest="$1"
    mkdir -p "$dest/conf" "$dest/db"
    local f
    for f in "${CONF_FILES[@]}"; do
        [[ -f "$f" ]] && cp -an "$f" "$dest/conf/$(echo "$f" | tr '/' '_')" 2>/dev/null || true
    done
    cp -an "$DB_DIR/${MODEL_ID}"*_v7.db        "$dest/db/" 2>/dev/null || true
    cp -an "$DB_DIR/${MODEL_ID}"*_v7.db.new    "$dest/db/" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# JSON injection (python3)
# ---------------------------------------------------------------------------
patch_db() {
    # $1 = db file, remaining args = "model::sizeGB" pairs
    local db="$1"; shift
    [[ -f "$db" ]] || return 0
    if (( DRY_RUN )); then
        log "  would patch $(basename "$db") with: $*"
        return 0
    fi
    DB="$db" PAIRS="$*" python3 - "$@" <<'PY'
import json, os, sys
db = os.environ["DB"]
pairs = sys.argv[1:]
with open(db) as fh:
    data = json.load(fh)
info = data.setdefault("disk_compatbility_info", {})   # Synology's spelling
entry_tmpl = {
    "compatibility": "support",
    "not_yet_rolling_status": "support",
    "fw_dsm_update_status_notify": False,
    "barebone_installable": True,
    "barebone_installable_v2": "auto",
    "smart_test_ignore": True,
    "smart_attr_ignore": True,
}
changed = 0
for p in pairs:
    model, _, sz = p.partition("::")
    try:
        size_gb = int(sz)
    except ValueError:
        size_gb = 0
    cur = info.get(model)
    want = {"default": {"size_gb": size_gb,
                        "compatibility_interval": [dict(entry_tmpl)]}}
    if cur != want:
        info[model] = want
        changed += 1
if changed:
    tmp = db + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(data, fh, separators=(",", ":"))
    os.replace(tmp, db)
print(f"    {os.path.basename(db)}: {changed} model entr{'y' if changed==1 else 'ies'} set")
PY
}

# ---------------------------------------------------------------------------
# synoinfo.conf flag flip
# ---------------------------------------------------------------------------
set_flag_no() {
    local file="$1" key="$2"
    [[ -f "$file" ]] || return 0
    if grep -q "^${key}=" "$file"; then
        local cur; cur="$(grep "^${key}=" "$file" | head -1)"
        [[ "$cur" == "${key}=\"no\"" ]] && return 0
        if (( DRY_RUN )); then log "  would set ${key}=\"no\" in $file (was: $cur)"; return 0; fi
        sed -i "s|^${key}=.*|${key}=\"no\"|" "$file"
        log "  ${file}: ${key} -> \"no\""
    else
        if (( DRY_RUN )); then log "  would append ${key}=\"no\" to $file"; return 0; fi
        printf '%s="no"\n' "$key" >> "$file"
        log "  ${file}: appended ${key}=\"no\""
    fi
}

# ---------------------------------------------------------------------------
# apply / revert
# ---------------------------------------------------------------------------
do_apply() {
    detect_drives
    log "HDD/SATA models to whitelist: ${HDD_MODELS[*]:-(none)}"
    log "NVMe models to whitelist    : ${NVME_MODELS[*]:-(none)}"

    if [[ ${#HDD_MODELS[@]} -eq 0 && ${#NVME_MODELS[@]} -eq 0 ]]; then
        warn "No non-Synology drives detected; only flags will change."
    fi

    # pristine backup once, plus a per-run backup
    if (( ! DRY_RUN )); then
        [[ -d "$ORIG_BACKUP" ]] || { mkdir -p "$ORIG_BACKUP"; make_backup "$ORIG_BACKUP"; log "Saved ORIGINAL backup -> $ORIG_BACKUP"; }
        make_backup "${BACKUP_ROOT}/${TS}"; log "Saved run backup -> ${BACKUP_ROOT}/${TS}"
    fi

    # build model::size pair arrays
    local hdd_pairs=() nvme_pairs=() m
    for m in "${HDD_MODELS[@]:-}";  do [[ -n "$m" ]] && hdd_pairs+=("${m}::${MODEL_SIZE_GB[$m]:-0}"); done
    for m in "${NVME_MODELS[@]:-}"; do [[ -n "$m" ]] && nvme_pairs+=("${m}::${MODEL_SIZE_GB[$m]:-0}"); done

    # HDDs -> host DB (and any host .db.new)
    if [[ ${#hdd_pairs[@]} -gt 0 ]]; then
        log "Patching host DB(s) for HDDs..."
        local f
        for f in "$DB_DIR/${MODEL_ID}_host_v7.db" "$DB_DIR/${MODEL_ID}_host_v7.db.new"; do
            [[ -f "$f" ]] && patch_db "$f" "${hdd_pairs[@]}"
        done
    fi

    # NVMe -> every M.2 adapter / eunit DB for this model (covers whichever card)
    if [[ ${#nvme_pairs[@]} -gt 0 ]]; then
        log "Patching M.2 adapter DB(s) for NVMe cache..."
        local f
        for f in "$DB_DIR/${MODEL_ID}_m2"*_v7.db "$DB_DIR/${MODEL_ID}_e10m20"*_v7.db \
                 "$DB_DIR/${MODEL_ID}_m2"*_v7.db.new "$DB_DIR/${MODEL_ID}_e10m20"*_v7.db.new; do
            [[ -f "$f" ]] && patch_db "$f" "${nvme_pairs[@]}"
        done
    fi

    # flags
    log "Setting compatibility-enforcement flags to \"no\"..."
    local file key
    for file in "${CONF_FILES[@]}"; do
        for key in "${FLAGS[@]}"; do set_flag_no "$file" "$key"; done
    done

    if (( DRY_RUN )); then log "Dry run complete. No changes written."; return 0; fi

    # install self for boot persistence
    mkdir -p "$STATE_DIR"
    cp -f "$0" "${STATE_DIR}/synology_drive_support.sh"
    chmod 755 "${STATE_DIR}/synology_drive_support.sh"
    log "Installed -> ${STATE_DIR}/synology_drive_support.sh"

    # nudge Storage Manager to re-read
    synosystemctl restart synostoraged 2>/dev/null \
        || systemctl restart synostoraged 2>/dev/null || true

    cat <<EOF

[+] Done.
    - Open Storage Manager and refresh. Your WD HDDs should no longer show
      "not on compatibility list", and the M.2 SSDs should now be selectable
      for an SSD read/write cache (HDD/SSD/Cache > Create).
    - A reboot guarantees every service picks up the flag change.

[i] MAKE IT SURVIVE DSM UPDATES (one-time, ~30s):
    Control Panel > Task Scheduler > Create > Triggered Task > User-defined script
      Task:  Re-apply drive support
      User:  root
      Event: Boot-up
      Run command:
        ${STATE_DIR}/synology_drive_support.sh
    DSM updates overwrite the config/DB files; this re-applies on next boot.

[i] To undo everything: sudo $0 --revert
EOF
}

do_revert() {
    [[ -d "$ORIG_BACKUP" ]] || die "No original backup at $ORIG_BACKUP — nothing to revert."
    log "Restoring original config + DBs from $ORIG_BACKUP ..."
    local f base
    for f in "$ORIG_BACKUP"/conf/*; do
        [[ -e "$f" ]] || continue
        base="$(basename "$f" | tr '_' '/')"
        cp -f "$f" "$base" && log "  restored $base"
    done
    for f in "$ORIG_BACKUP"/db/*; do
        [[ -e "$f" ]] || continue
        cp -f "$f" "$DB_DIR/$(basename "$f")" && log "  restored $DB_DIR/$(basename "$f")"
    done
    synosystemctl restart synostoraged 2>/dev/null \
        || systemctl restart synostoraged 2>/dev/null || true
    log "Revert complete. Reboot to be fully clean."
}

case "$MODE" in
    status) show_status ;;
    revert) do_revert ;;
    apply)  do_apply ;;
esac
