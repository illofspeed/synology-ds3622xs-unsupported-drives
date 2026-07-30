#!/bin/sh
#
# m2-cache.sh — operational helper for third-party M.2 NVMe read-write cache on DSM.
#
# DSM forces non-Synology M.2 NVMe read-only when it (re)detects them, including
# during the cache-creation rescan. This helper provides the one manual trick
# needed to create the cache, plus status/verify utilities.
#
# Usage:
#   m2-cache.sh status     show ro / read_only / compatibility / cache_selectable + md state
#   m2-cache.sh unlock     one-shot: clear the kernel read-only flag on all NVMe (+ partitions)
#   m2-cache.sh hold-rw     hold the NVMe writable in a tight loop (run during cache CREATION)
#   m2-cache.sh stop       stop a running hold-rw loop
#   m2-cache.sh verify     exit 0 if drives supported/writable & cache healthy; non-zero on drift
#
# NVMe devices are auto-detected from /sys/block/nvme*.
#
PIDFILE="/run/m2-cache-holdrw.pid"

nvme_namespaces() {           # -> /dev/nvme0n1 /dev/nvme1n1 ...
    for d in /sys/block/nvme*n*; do
        [ -e "$d" ] || continue
        printf '/dev/%s\n' "$(basename "$d")"
    done
}

need_root() { [ "$(id -u)" -eq 0 ] || { echo "Run as root (sudo)."; exit 1; }; }

cmd_unlock() {
    need_root
    for ns in $(nvme_namespaces); do
        for d in "$ns" "${ns}p"*; do
            [ -e "$d" ] && blockdev --setrw "$d" 2>/dev/null
        done
    done
    echo "[*] Cleared read-only on: $(nvme_namespaces | tr '\n' ' ')"
}

cmd_hold_rw() {
    need_root
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "[!] hold-rw already running (PID $(cat "$PIDFILE")). Use 'stop' first."
        exit 1
    fi
    # Tight loop (no fractional sleep; DSM busybox may reject it). Pegs one core
    # briefly — that's fine, you stop it right after the cache is created.
    (
        while true; do
            for ns in $(nvme_namespaces); do
                for d in "$ns" "${ns}p"*; do
                    [ -e "$d" ] && blockdev --setrw "$d" 2>/dev/null
                done
            done
        done
    ) &
    echo $! > "$PIDFILE"
    echo "[*] hold-rw running (PID $!). Now create the read-write cache in Storage Manager."
    echo "    When the cache is created, run:  $0 stop"
}

cmd_stop() {
    need_root
    if [ -f "$PIDFILE" ]; then
        kill "$(cat "$PIDFILE")" 2>/dev/null && echo "[*] hold-rw stopped."
        rm -f "$PIDFILE"
    else
        echo "[*] No hold-rw loop running."
    fi
}

cmd_status() {
    for ns in $(nvme_namespaces); do
        name="$(basename "$ns")"
        ro="$(blockdev --getro "$ns" 2>/dev/null)"
        rdonly="$(cat /run/synostorage/disks/${name}/read_only 2>/dev/null)"
        compat="$(cat /run/synostorage/disks/${name}/compatibility 2>/dev/null)"
        cache_sel="$(grep -o '"cache_selectable":"[a-z]*"' /run/synostorage/disks/${name}/compatibility_action 2>/dev/null)"
        printf '%-14s ro=%s read_only=%s compatibility=%s %s\n' \
            "$name" "${ro:-?}" "${rdonly:-?}" "${compat:-?}" "${cache_sel:-}"
    done
    echo "--- cache md (look for raid1 over nvme*p1) ---"
    grep -E 'nvme' /proc/mdstat 2>/dev/null || echo "(no nvme-backed md found)"
    sop="$(/usr/syno/bin/synogetkeyvalue /usr/syno/etc.defaults/SynoOnlinePack/SynoOnlinePack_v2.conf version 2>/dev/null)"
    [ -n "$sop" ] && echo "--- SynoOnlinePack version: $sop (9999... = auto-update frozen) ---"
}

cmd_verify() {
    rc=0
    for ns in $(nvme_namespaces); do
        name="$(basename "$ns")"
        ro="$(blockdev --getro "$ns" 2>/dev/null)"
        compat="$(cat /run/synostorage/disks/${name}/compatibility 2>/dev/null)"
        [ "$ro" = "0" ] || { echo "DRIFT: $name is read-only (ro=$ro)"; rc=1; }
        [ "$compat" = "support" ] || { echo "DRIFT: $name compatibility=$compat (want support)"; rc=1; }
    done
    if ! grep -q nvme /proc/mdstat 2>/dev/null; then
        echo "DRIFT: no nvme-backed cache md present"; rc=1
    fi
    [ "$rc" -eq 0 ] && echo "OK: NVMe supported, writable, cache present."
    return $rc
}

case "${1:-}" in
    status)  cmd_status ;;
    unlock)  cmd_unlock ;;
    hold-rw) cmd_hold_rw ;;
    stop)    cmd_stop ;;
    verify)  cmd_verify ;;
    *) echo "Usage: $0 {status|unlock|hold-rw|stop|verify}"; exit 2 ;;
esac
