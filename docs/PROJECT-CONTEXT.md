# Project context — full history, decisions, current state

Purpose: everything needed to resume work on this project from a fresh machine
or a fresh Claude Code session, without any external notes.
Personal values are placeholders — substitute your own (`<nas-ip>`, `<ssh-port>`, etc.).

---

## 1. Hardware / environment

| Item | Value |
|---|---|
| NAS | Synology **DS3622xs+**, DSM **7.4-90075** |
| RAM | **128 GB ECC**: internal 2×32 GB OWC DDR4-2666 / PC4-21300 CL19 2Rx8 ECC SODIMM (260-pin, 1.2 V) + accessible 2×32 GB Kingston Server Premier `KSM32SED8/32HC`; approximately 20-hour Synology memory test passed |
| HDDs | 8× WDC **WUH721818ALE6L0/L1/L4** (WD Ultrastar 18 TB, third-party) + 1× Synology **HAT5310-20T** |
| Expansion unit | **DX1222** attached — syno_hdd_db detects it and mirrors drive entries into `dx1222_v7.db` |
| Pool/Volume | Storage Pool 1 = **RAID 6**, ~98 TB; Volume 1 = btrfs, **LUKS-encrypted** (`cryptvol_1`) |
| M.2 | 2× **Samsung PM983 3.84 TB** (`MZ-1LB3T80`; DSM may expose a longer OEM identifier) on an **E10M20-T1** adapter card, PCI slot 1 (earlier: 2× Micron 7450 960 GB, since swapped out) |
| Additional NVMe cooling | **Noctua NF-A12x15 FLX**, 120×120×15 mm, 3-pin, 12 V, positioned for direct airflow over the E10M20-T1 heatsinks |
| Fan power | Custom female-to-female lead assembled from two donor leads → Akyga `AK-CA-12` P4/Molex adapter → Akyga `AK-CA-35` Molex/3-pin 12 V adapter → intermediate Noctua Low-Noise Adapter → fan; the exact donor-lead listing is unavailable because the supplied order link is account-private, so the harness is documented as a non-reproducible installation that requires independent pinout and voltage verification |
| SSD cache | **Read-write**, RAID 1 (`md3` over `nvme0n1p1`+`nvme1n1p1`), "Pin all Btrfs metadata" enabled; ~98% hit rate |
| NAS SSH | custom port (not 22); user-level login + `sudo -i` |
| Scripts on NAS | `/volume1/scripts/{setup.sh, m2-cache.sh, syno_hdd_db.sh}` |
| Scheduler tasks (user root) | Boot-up → `/volume1/scripts/setup.sh`; Daily 04:00 → `/volume1/scripts/setup.sh` |
| Old NAS | DS1821+ — ~60 TB migrated to the DS3622xs+ and unit decommissioned (as of 2026-08) |

## 2. What the whitelist does (mechanism)

- DSM keeps per-model compatibility DBs in `/var/lib/disk-compatibility/`
  (`ds3622xs+_host_v7.db`, `ds3622xs+_e10m20-t1_v7.db`, plus `rule_v2_*` action
  rules). JSON key `disk_compatbility_info` (Synology's typo) → model → firmware/default →
  `compatibility_interval[].compatibility: "support"`.
- 007revad's `syno_hdd_db.sh` (pinned **v3.6.137**) injects detected drive models
  into those DBs, and with `--noupdate` freezes DSM's DB auto-update by prefixing
  the SynoOnlinePack version with `9999` (visible as `SynoOnlinePack_v2 version 9999...`).
- `--wdda` disables WD Drive Analytics; `--ram` clears the third-party RAM warning
  and sets `mem_max_mb`.
- Runtime per-disk verdicts live in `/run/synostorage/disks/<dev>/`
  (`compatibility`, `compatibility_action`, `read_only`, …) and are recomputed
  at boot / rescan.

## 3. The M.2 read-write cache saga (why the trick exists)

Chronology of root-causing, so nobody re-derives it:

1. First attempt used `--force` → **all** drives (incl. genuine Synology) showed
   "Unverified", and the M.2 were classified `disabled` → DSM forced the NVMe
   block devices **read-only** (`blockdev --getro` = 1; raw `dd` write = EPERM).
2. Cache creation failed with *"failed to mount an SSD read-write cache"*;
   real error in `/var/log/space_operation.log`:
   `sfdisk -M1 /dev/nvme1n1 … Operation not permitted during write`.
3. Ruled out: leftover RAID metadata (mdadm --examine clean), 4K+DIF namespace
   format (LBA format 0, 512B, no metadata), hardware write-protect (dmesg clean;
   after `blockdev --setrw`, dd writes succeeded).
4. Removing `--force` + clean reboot → runtime flipped to `compatibility=support`,
   `read_only=0`, `compatibility_action.cache_selectable="yes"`.
5. Creation STILL failed: DSM re-locks third-party M.2 to read-only **during the
   creation flow's NVMe rescan** (dmesg `nvme nvme0: rescanning`). Not udev
   (udevadm change doesn't re-lock; no rules touch `ro`); Synology patched layer;
   `/sys/class/nvme/*/rescan_controller` is root-denied.
6. **Fix**: a tight loop holding the devices writable during creation out-races
   the re-lock → `sfdisk`/`mdadm -C md3`/`pvcreate`/`vgcreate shared_cache_vg1`/
   `flashcache_enable -p back cachedev_0` all succeed. This is `m2-cache.sh hold-rw`.
7. Once created, the cache **survives reboots** (DSM only locks unassigned M.2).
   Verified across multiple reboots and a full volume rebuild + drive swap
   (Micron → Samsung PM983): same procedure worked first try.

## 4. Decisions made (and why) — don't relitigate

- **Use 007revad, not a homegrown script**, for whitelisting: it's maintained
  against DSM changes and does the DB-freeze; a from-scratch script (kept in
  `extras/`) lacks the freeze and would rot. Pin the version; review before bumping.
- **No `--force`, ever** (see saga above). Correct flags: `--noupdate --wdda --ram`.
- **Persistence = Task Scheduler**, root: Boot-up (survives DSM updates, which
  always reboot) + Daily (belt-and-suspenders; idempotent, all-"already" output
  on healthy days). No hacking of Synology's scheduler DB.
- **M.2 kept as RW cache only** — owner declined splitting cache+volume
  (DSM GUI can't; manual partition hack is fragile) and declined an NVMe
  storage pool (cache fits the workload; 98% hit rate).
- **Deduplication / "Storage efficiency" gate left alone** — DSM requires
  all-Synology HDDs; 007revad's enable-dedup script patches system libraries
  (too invasive). The dialog is informational; click OK.
- **Commit identity**: history rewritten (while private) to the GitHub noreply
  address; personal email/IPs/usernames scrubbed from files. Keep the repo
  public-safe.

## 5. Known cosmetic noise (ignore, don't "fix")

- `cp: cannot stat '' … ERROR 5 Failed to backup !` — upstream quirk, fixed in
  v3.6.134 (per 007revad, 2026-08); only seen on older pinned versions.
- `You may need to reboot the Synology…` — printed unconditionally.
- DSM's bundled smartctl 6.5 fails on these NVMe (`NVMe Status 0x4002`) —
  use `synonvme --smart-info-get /dev/nvmeXn1` or `nvme smart-log`.
- Healthy steady-state run = every line "already exists / already enabled".

## 6. Operational notes

- **Adding/replacing drives**: just re-run `/volume1/scripts/setup.sh` (it
  re-detects everything), reboot if M.2 changed, then normal procedure.
  Validated during the Micron→Samsung swap.
- **Recreating the cache** (e.g. after cooling changes): remove cache in
  Storage Manager (writeback flushes safely), then `m2-cache.sh status` →
  `hold-rw` → create in UI → `stop` → `verify`. Re-enable "Pin all Btrfs metadata".
- **Temps**: enterprise NVMe ran 55–65 °C and had logged critical-temperature
  minutes on the stock passive setup. Sustained benchmarks with the dual PM983
  setup could fail from overheating. Fan Speed Mode = Cool Mode, appropriate
  heatsinks, and a Noctua NF-A12x15 FLX providing direct airflow over the E10M20-T1
  eliminated the observed benchmark failures. Check with
  `synonvme --smart-info-get /dev/nvme0n1`.
- **Transfers to NAS**: `scp -O -P <ssh-port> …` (SFTP subsystem off by default);
  strip CRLF after copying from Windows (`sed -i 's/\r$//'`).
- **User home warning** (`Could not chdir to home directory`) after volume
  rebuild = User Home service not re-enabled; harmless.

## 7. Repo / mirror layout

- **Canonical**: public GitHub repository
  `illofspeed/synology-ds3622xs-unsupported-drives` (scrubbed; disclaimer and
  trademark notice included).
- **Mirror**: self-hosted Gitea (`<gitea-user>/<same-name>`), reached via SSH on the
  Gitea SSH port (2222) at the LAN address — NOT port 22 (that's the host OS sshd)
  and NOT via the HTTPS reverse proxy hostname for SSH.
- Mirroring = second push URL on `origin` (lives in `.git/config`; must be
  re-added after every fresh clone — see `docs/DEV-SETUP.md`).

## 8. Open items / backlog

- [x] Make the GitHub repo public; description and topics are set.
- [x] Migrate ~60 TB from the DS1821+ — done; DS1821+ decommissioned (2026-08).
- [ ] Monitor NVMe temps under sustained write load after cooling changes.
- [ ] Add annotated disassembly and E10M20-T1 cooling photos to the new hardware guides.
- [ ] Occasionally review + bump the pinned `HDD_DB_VERSION` in `setup.sh`.
      (Last bump: v3.6.132 → v3.6.137 on 2026-08-03 — picks up the ERROR-5 fix
      (v3.6.134), scheduler auto-detect (v3.6.135), and an E10M20-T1 db-file fix
      (v3.6.137). setup.sh now auto-refreshes the NAS copy when the pin changes.
      Validated on the NAS same day: auto-refresh 132→137 worked, no ERROR 5,
      colour-free output, `verify` OK, second run correctly skipped the download.
      One-time change seen: newer --ram also disables memory compatibility —
      expected, idempotent.)
