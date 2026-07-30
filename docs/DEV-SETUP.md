# Dev machine setup (new PC)

Steps to work on this repo from a fresh machine. Substitute your own values for
placeholders.

## 1. Clone

```powershell
git clone https://github.com/illofspeed/synology-ds3622xs-unsupported-drives.git C:\dev\claude\synology-drives-script
cd C:\dev\claude\synology-drives-script
```

Keeping the same local path is recommended: Claude Code project memory is keyed
to the project path, so an identical path lets a copied memory folder work as-is.

## 2. Re-add the Gitea mirror (not carried by clone)

The dual-push setup lives in `.git/config` and must be re-created after cloning:

```powershell
git remote set-url --add --push origin https://github.com/illofspeed/synology-ds3622xs-unsupported-drives.git
git remote set-url --add --push origin ssh://git@<gitea-lan-ip>:2222/<gitea-user>/synology-ds3622xs-unsupported-drives.git
```

Result: one `git push origin main` updates GitHub **and** the Gitea mirror
(mirror reachable on LAN/VPN only). Note: Gitea SSH is on **port 2222** — port 22
on that host is the OS sshd and will reject your Gitea key.

## 3. Git identity (keep history scrubbed)

```powershell
git config user.name "illofspeed"
git config user.email "22580385+illofspeed@users.noreply.github.com"
```

## 4. Credentials

- **GitHub**: `gh auth login` (browser flow), or let Git Credential Manager
  prompt on first push.
- **Gitea**: generate a per-machine key and register it in Gitea →
  Settings → SSH Keys:
  ```powershell
  ssh-keygen -t ed25519 -C "<machine-name>"
  ```
  Don't copy private keys between machines.
- **NAS**: password SSH on the custom port — `ssh -p <ssh-port> <user>@<nas-ip>`.

## 5. (Optional) Claude Code continuity

- `CLAUDE.md` in the repo root is auto-loaded by Claude Code — that plus
  `docs/PROJECT-CONTEXT.md` is enough to resume with full context.
- For deeper continuity you can additionally copy the project memory folder from
  the old machine:
  `%USERPROFILE%\.claude\projects\C--dev-claude-synology-drives-script\memory\`
  (folder name is the mangled project path — keep the same repo path and it maps 1:1).

## 6. Windows gotchas

- Shell scripts must stay **LF** (`.gitattributes` enforces this) — DSM's busybox
  `ash` breaks on CRLF. After `scp`-ing to the NAS, `sed -i 's/\r$//' file.sh`
  is a harmless belt-and-suspenders.
- `scp` to Synology needs `-O` (legacy protocol; SFTP subsystem is off by default)
  and `-P <ssh-port>` (capital P; `ssh` uses lowercase `-p`).
