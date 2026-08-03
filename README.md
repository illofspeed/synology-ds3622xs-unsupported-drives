# Synology DS3622xs+ — Unsupported Drives + M.2 Read-Write Cache

A clean, repeatable path for running **non-Synology HDDs and M.2 NVMe SSDs** on a
**DS3622xs+ (DSM 7.4)** — including a **read-write SSD cache** on third-party NVMe,
which DSM otherwise blocks.

This repo does **not** reinvent the disk-compatibility engine. It uses the excellent,
community-maintained [**007revad/Synology_HDD_db**](https://github.com/007revad/Synology_HDD_db)
for whitelisting, and adds the missing operational pieces this specific job needs:

- the **clean step order** (the order matters — getting it wrong locks the M.2 read-only),
- a helper for the **one manual trick** required to create a read-write cache on third-party NVMe,
- a **verify** check you can run from a scheduled task.

> Tested on: **DS3622xs+**, DSM **7.4-90075**, 8× WD Ultrastar `WUH721818ALE6Lx` (18 TB),
> with both 2× `Micron_7450_MTFDKBA960TFR` (960 GB) and 2× Samsung `MZ1LB3T8HMLA` /
> PM983 (3.84 TB) on an **E10M20-T1** adapter card — including a full drive swap
> between the two NVMe sets, re-validated end to end.
> The approach generalizes to other models/drives, but the M.2 read-write-cache trick is
> what makes this repo worth keeping.

## ⚠️ Disclaimer — read this first

- This project is **not affiliated with, endorsed by, or supported by Synology Inc.**
- It modifies DSM's drive-compatibility databases, freezes their auto-update, and runs
  third-party scripts **as root** on your NAS. A mistake — yours, mine, or a future DSM
  update's — can cause **data loss**. **Back up before you start.**
- Using drives outside Synology's compatibility list may **void support or warranty
  coverage** for related issues. Enterprise NVMe can also run hot enough to throttle or
  log critical-temperature events on passive M.2 adapters — watch your temps.
- Everything here was validated on the exact hardware/DSM build listed above. Other
  models, DSM versions, or future updates may behave differently. Read each step,
  understand what it does, and proceed **at your own risk** — no warranty of any kind
  (see [`LICENSE`](LICENSE)).

---

## Is this your problem? (symptoms this repo fixes)

If you've hit any of these on a Synology NAS with third-party drives, you're in the
right place:

- **"The system failed to mount an SSD read-write cache"** when creating an SSD cache
  on non-Synology M.2 NVMe drives.
- Storage Manager only offers a **read-only cache** (or no cache at all) with
  third-party NVMe SSDs, or the M.2 drives show as **not supported / incompatible**.
- Drives listed as **"Unverified"** or *"incompatible drive"* /
  *"not on the compatibility list"* warnings after installing non-Synology HDDs or SSDs.
- NVMe block devices stuck **read-only** (`blockdev --getro` returns `1`;
  `sfdisk: Operation not permitted` in `/var/log/space_operation.log`).
- `smartctl` failing on newer NVMe with **`NVMe Status 0x4002`**.
- Wanting the whitelist to **survive DSM updates** without manual re-runs.

---

> 📋 Prefer a bare copy-paste runbook with PC/NAS/UI context tags? See [`INSTALL.md`](INSTALL.md).
> 🧠 Full project history, decisions, and current state: [`docs/PROJECT-CONTEXT.md`](docs/PROJECT-CONTEXT.md) · New dev machine: [`docs/DEV-SETUP.md`](docs/DEV-SETUP.md)

## TL;DR — the clean path

```sh
# 0. SSH in, become root (Control Panel → Terminal & SNMP → Enable SSH)
sudo -i

# 1. Whitelist drives + freeze DSM's DB auto-update.  NEVER use --force (see Gotchas).
/volume1/scripts/setup.sh

# 2. Reboot so DSM re-classifies the drives as "support".
reboot

# 3. After reboot: verify the M.2 are writable and cache-eligible
/volume1/scripts/m2-cache.sh status

# 4. Create the read-write cache WHILE holding the drives writable.
#    Run as ROOT (sudo -i) and do NOT add '&' — the script backgrounds the loop
#    itself; `sudo cmd &` instead backgrounds sudo's password prompt (SIGTTOU).
/volume1/scripts/m2-cache.sh hold-rw        # returns immediately, loop runs in background
#    → Storage Manager → SSD Cache → Create → Read-write → both NVMe → RAID 1
/volume1/scripts/m2-cache.sh stop           # after the cache is created

# 5. Add persistence tasks (see "Persistence") and set Fan Mode → Cool.
```

That's it. The cache survives reboots on its own — the `hold-rw` trick is needed **only at
creation time**.

---

## Why each step (the short version)

| Step | Why it's necessary |
|---|---|
| `setup.sh` (007revad `--noupdate --wdda --ram`) | Adds your drive models to the compat DBs, freezes DSM's DB auto-update so it can't silently revert, disables WD Drive Analytics, fixes the RAM warning. |
| **No `--force`** | `--force` sets `support_disk_compatibility="no"`, which makes DSM classify the M.2 as `disabled` and **force them read-only**. That is the single biggest trap. |
| **Reboot** | DSM only re-classifies the M.2 to `compatibility=support` (and lifts the default read-only) after a clean reboot. |
| **`hold-rw` during cache creation** | DSM re-locks third-party M.2 to read-only during the cache-creation rescan. The helper races it, keeping the devices writable so `sfdisk`/`mdadm` succeed. |

---

## Prerequisites

- SSH enabled, root access.
- A folder on a volume to hold the scripts (must be on a volume so Task Scheduler can reach it):
  ```sh
  sudo mkdir -p /volume1/scripts
  ```
- Copy `setup.sh` and `m2-cache.sh` into `/volume1/scripts/` (from your PC: `scp -O -P <ssh-port> setup.sh m2-cache.sh user@nas:/tmp/` — Synology needs `-O` because the SFTP subsystem is off by default; full transfer steps in [`INSTALL.md`](INSTALL.md)) and make them executable:
  ```sh
  sudo chmod 755 /volume1/scripts/setup.sh /volume1/scripts/m2-cache.sh
  ```

---

## Persistence

DSM **updates** reset the compat DBs and flags (and always reboot afterward), so re-apply the
whitelist on boot. The **read-write cache itself persists** across reboots once created — only
the whitelist needs re-applying.

In **Control Panel → Task Scheduler**, create as user `root`:

1. **Triggered Task → Boot-up** — *required*
   `/volume1/scripts/setup.sh`
2. **Scheduled Task → Daily** — *optional belt-and-suspenders*
   `/volume1/scripts/m2-cache.sh verify || /volume1/scripts/setup.sh`

> The daily task only re-runs the whitelist if `verify` detects drift, so it stays quiet on
> normal days.

---

## Helper: `m2-cache.sh`

```
m2-cache.sh status      # show ro flag, read_only, compatibility, cache_selectable per NVMe + md state
m2-cache.sh unlock      # one-shot: clear the kernel read-only flag on all NVMe (+ partitions)
m2-cache.sh hold-rw     # run the read-write holder loop (use during cache CREATION); 'stop' to end
m2-cache.sh stop        # stop a running hold-rw loop
m2-cache.sh verify      # exit 0 if drives are supported/writable & cache healthy, non-zero on drift
```

NVMe devices are auto-detected from `/sys/block/nvme*`.

---

## Troubleshooting / Gotchas (learned the hard way)

- **All drives show "Unverified" after a reboot** → you used `--force`. Re-run **without** it
  (`setup.sh` already omits it) and reboot. `--force` disables the verify-against-list feature
  entirely, which also forces the M.2 read-only.
- **"The system failed to mount an SSD read-write cache"** → the M.2 are read-only at creation
  time. Use `m2-cache.sh hold-rw` while creating the cache.
- **`blockdev --getro` shows `1` on the NVMe** → DSM's default lock on unverified/unassigned
  M.2. Cleared by: drives in the DB as `support` + a clean reboot (status), or `m2-cache.sh
  unlock` (one-shot, for the creation window).
- **`smartctl` says `Read NVMe Identify Controller failed: NVMe Status 0x4002`** → DSM's bundled
  smartctl 6.5 is too old for these drives. Use `synonvme --smart-info-get /dev/nvmeXn1` or
  `nvme smart-log` instead.
- **`cp: cannot stat '' … ERROR 5 Failed to backup`** → harmless, and fixed upstream in
  syno_hdd_db **v3.6.134** (this repo pins ≥ that; you'll only see it on older versions).
  **ANSI color codes** in Task Scheduler output → pass `--email` (setup.sh does), and
  upstream ≥ v3.6.135 auto-detects scheduler runs. A healthy steady-state run shows all
  **"already exists / already enabled"**.
- **Heat** → enterprise NVMe (e.g. Micron 7450) run hot on a passive M.2 card. Set
  **Control Panel → Hardware & Power → Fan Speed Mode → Cool Mode** and add a heatsink. Check
  temps with `synonvme --smart-info-get /dev/nvme0n1`.

---

## Reset / start-from-scratch notes

Resetting only the **cache** (not the volume) is data-safe on a clean state:

1. Storage Manager → remove the SSD cache (writeback flushes first).
2. Re-run the clean path from **TL;DR** above.

A full DSM re-init is **not** needed and would destroy your volume.

---

## Credits & License

- Whitelisting engine: **[007revad/Synology_HDD_db](https://github.com/007revad/Synology_HDD_db)**
  — all credit for the hard compatibility work goes there. See [`NOTICE`](NOTICE).
- Scripts and docs in this repo: MIT (see [`LICENSE`](LICENSE)).

⚠️ See the [Disclaimer](#️-disclaimer--read-this-first) at the top: not affiliated with
Synology; root-level system modifications; data-loss risk; back up first; use at your own risk.
