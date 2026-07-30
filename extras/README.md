# extras/

`standalone-whitelist.sh` — a self-contained, dependency-free whitelist script
(auto-detects drives, injects them into the compat DBs, sets the flags).

**Not the recommended path.** It does NOT implement DSM's DB auto-update freeze
and would need manual maintenance every time Synology changes the DB/rule format.
For real use, prefer the orchestrated `setup.sh` in the repo root, which uses the
maintained 007revad/Synology_HDD_db. Kept here only as a transparent reference /
emergency fallback.
