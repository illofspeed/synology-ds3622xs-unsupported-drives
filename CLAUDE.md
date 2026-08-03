# Project brief (auto-loaded by Claude Code)

Helper scripts + docs for running **non-Synology HDDs and M.2 NVMe** on a
**Synology DS3622xs+ (DSM 7.4)**, including a **read-write SSD cache** on
third-party NVMe. Whitelisting is delegated to the community-maintained
[007revad/Synology_HDD_db](https://github.com/007revad/Synology_HDD_db)
(pinned version, run by `setup.sh`); this repo adds ordering, the cache-creation
trick, and verification.

**Read `docs/PROJECT-CONTEXT.md` for the full history, decisions, and current
NAS state before advising on anything non-trivial.**

## Hard-won rules — do not violate

1. **NEVER use `--force`** with syno_hdd_db.sh here. It sets
   `support_disk_compatibility="no"`, which makes DSM classify M.2 NVMe as
   `disabled` → forces them **read-only** and shows every drive "Unverified".
   Correct flags: `--noupdate --wdda --ram` (what `setup.sh` uses).
2. **Read-write cache creation on third-party M.2 requires `m2-cache.sh hold-rw`**
   running during creation (DSM re-locks the drives to read-only mid-flow).
   Run it as root via `sudo -i`, **without `&`** (the script self-backgrounds;
   `sudo cmd &` suspends on the password prompt with SIGTTOU).
3. A **reboot after whitelisting** is required before M.2 reads
   `compatibility=support` / becomes writable. Don't fight read-only flags
   before a clean reboot.
4. The cache **persists across reboots once created** — DSM only locks
   *unassigned* third-party M.2. No boot-time hacks needed.
5. Known-cosmetic, do not "fix": the unconditional "may need to reboot" line,
   DSM's bundled smartctl failing with NVMe status 0x4002 (use
   `synonvme --smart-info-get` instead). (`ERROR 5 Failed to backup` was fixed
   upstream in v3.6.134; ANSI colours handled by `--email` + upstream ≥ v3.6.135.)
6. Owner **declined** (don't re-suggest): splitting M.2 drives into cache+volume
   (unsupported hack), and 007revad's Synology_enable_Deduplication for the
   "Storage efficiency requires Synology HDDs" gate (too invasive — patches libs).

## Repo layout

- `setup.sh` — downloads pinned syno_hdd_db.sh, applies whitelist (no --force)
- `m2-cache.sh` — `status | unlock | hold-rw | stop | verify`
- `README.md` — explained clean path; `INSTALL.md` — copy-paste runbook
- `docs/PROJECT-CONTEXT.md` — full session history/state; `docs/DEV-SETUP.md` — new-PC setup
- `extras/standalone-whitelist.sh` — not recommended, reference only

## Conventions

- Shell scripts are POSIX-ish `sh` for DSM busybox; **LF endings enforced**
  (`.gitattributes`) — never commit CRLF.
- Commit author uses the GitHub noreply address (history was scrubbed of the
  personal email while private — keep it that way).
- Repo is public-safe: placeholders (`<user>@<nas-ip>`, `<ssh-port>`) instead of
  real hosts/IPs. Don't commit LAN IPs, usernames, or the mirror's real host.
- Dual-push remote: GitHub is canonical; a self-hosted Gitea mirror is a second
  push URL on `origin` (see docs/DEV-SETUP.md — it lives in `.git/config`, not
  in the repo, and must be re-added after a fresh clone).
