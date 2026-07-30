# INSTALL — copy-paste runbook

The exact sequence, validated end-to-end on a freshly-installed **DS3622xs+ (DSM 7.4)**.
For the *why* behind each step, see [`README.md`](README.md). Replace `<user>@<nas-ip>`,
the SSH port `<ssh-port>`, and namespaces with your own.

> **Contexts:** 🖥️ = DSM web UI · 💻 = your PC terminal · 🐧 = NAS over SSH

---

## 1. 🖥️ DSM basics
- Finish initial DSM setup.
- **Control Panel → Terminal & SNMP → Enable SSH** (note your SSH port — default 22, mine is **<ssh-port>**).

## 2. 🐧 (Optional) Pre-whitelist so pool creation is warning-free
Lets you create the HDD pool with no "unverified drive" nags. Skip if you don't mind the warnings.
```bash
sudo curl -fL -o /tmp/hdd.sh \
  https://raw.githubusercontent.com/007revad/Synology_HDD_db/v3.6.132/syno_hdd_db.sh
sudo bash /tmp/hdd.sh --noupdate --wdda --ram     # MUST be bash, not sh
```

## 3. 🖥️ Create the Storage Pool + Volume
- **Storage Manager → create Storage Pool + Volume** from your HDDs.
- If you skipped step 2, click past the compatibility warning (HDDs work unverified).
- This creates `/volume1`, needed for the scripts.

## 4. 💻 Copy the scripts to the NAS
Synology's SSH has the SFTP subsystem **off** by default, so modern `scp` needs **`-O`**
(legacy protocol). Port flag is **`-P`** (capital) for `scp`, **`-p`** (lower) for `ssh`.
```powershell
cd <this-repo>
scp -O -P <ssh-port> setup.sh m2-cache.sh <user>@<nas-ip>:/tmp/
```
> If `-O` fails too: enable **Control Panel → File Services → FTP → SFTP**, then use plain `scp -P <ssh-port>`.

## 5. 🐧 Install + run the whitelist
```bash
ssh -p <ssh-port> <user>@<nas-ip>
sudo -i
mkdir -p /volume1/scripts
cp /tmp/setup.sh /tmp/m2-cache.sh /volume1/scripts/
sed -i 's/\r$//' /volume1/scripts/*.sh      # strip CR if copied from Windows
chmod 755 /volume1/scripts/*.sh
/volume1/scripts/setup.sh                     # NO --force (omitted by design)
reboot
```
A healthy run shows mostly **"already exists / already enabled"** plus a harmless
`ERROR 5 Failed to backup` line. The reboot lets DSM re-classify the M.2 as `support`.

## 6. 🐧 Verify the M.2 are ready
```bash
sudo /volume1/scripts/m2-cache.sh status
```
Expect on both NVMe: `ro=0 read_only=0 compatibility=support "cache_selectable":"yes"`.

## 7. 🐧 + 🖥️ Create the read-write cache (the one manual trick)
Run it as **root** and **without `&`** — the script backgrounds the loop itself;
`sudo cmd &` would background sudo's password prompt instead (you'd see `Stopped (SIGTTOU)`).
```bash
sudo -i
/volume1/scripts/m2-cache.sh hold-rw          # prints "hold-rw running (PID …)" and returns
```
→ **Storage Manager → SSD Cache → Create → Read-write → both NVMe → RAID 1 → finish**
```bash
sudo /volume1/scripts/m2-cache.sh stop
sudo /volume1/scripts/m2-cache.sh verify      # → "OK: NVMe supported, writable, cache present."
```

## 8. 🖥️ Persistence + cooling
- **Task Scheduler** (user `root`):
  - **Triggered → Boot-up:** `/volume1/scripts/setup.sh`
  - **Scheduled → Daily** (optional): `/volume1/scripts/m2-cache.sh verify || /volume1/scripts/setup.sh`
- **Control Panel → Hardware & Power → Fan Speed Mode → Cool.**

---

## Gotchas cheat-sheet
| Symptom | Fix |
|---|---|
| `scp: subsystem request failed` | add `-O`, or enable SFTP service |
| `This is a bash script. Do not run it with sh` | use `bash` / direct execution, not `sh` |
| All drives "Unverified" after reboot | you used `--force` — don't; re-run without it + reboot |
| `failed to mount an SSD read-write cache` | run `m2-cache.sh hold-rw` during creation |
| `Stopped (SIGTTOU)` after `hold-rw &` | don't use `&`; run as root (`sudo -i`) then `hold-rw` (it self-backgrounds) |
| `smartctl ... 0x4002` | DSM's old smartctl; use `synonvme --smart-info-get` / `nvme smart-log` |
| custom SSH port | `ssh -p <port>` / `scp -P <port>` |
