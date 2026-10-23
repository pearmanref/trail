# Changelog

## Unreleased — milestone 2 (process/network/file verbs + hashing + color)
- Process: `exe` (resolve + hash /proc/<pid>/exe, deleted flag, libmagic type), `tree` (ancestors + descendants, indented).
- Network: `net` (listening + established sockets from /proc/net, joined to the owning pid via the inode->pid map; ss fallback), `who-port` (same table filtered to one local port).
- Files: `ls`, `stat` (+ hash), `file`, `hash`, `cat`.
- Target-side hashing: md5 + sha256 via a shared `_prelude.sh` helper (coreutils -> busybox -> openssl), reported for `exe`, `stat`, `hash`.
- Guards: `cat` (and later strings/log) refuse char/block devices, FIFOs, sockets, and files over the size cap unless `--force`.
- Ref rule: a bare integer is a ref only when that item exists in the current list; otherwise it's a literal, so `who-port 4444` works.
- Console color (`--color always|never|auto`, NO_COLOR honored): verdicts, entities (IPv4 red / hashes yellow / domains cyan per the dotfiles `hl` palette), convergence magenta, headers cyan. Color is console-only; reports and the case dir stay plain ASCII.
- Fixtures added for `net` (v4+v6 decode, inode join) and `exe`.

## Unreleased — milestone 1 (skeleton)
- POSIX sh console with REPL, case dir, and step tree (each step records its parent).
- Transport: `--local` and `--ssh` (one ControlMaster session, keepalives, a timeout on every call).
- Help, `?`, `-h`, dispatch, and completion are generated from `# @verb` headers.
- `facts` (step 0) and `ps` read /proc directly, with a ps(1) fallback; SELF is tagged and hidden.
- Refs `N`, `S.N`, `S.N.ent`, `sN`, `@ref`; type checks with hints.
- Generic entity extraction (ip, path, pid, user), `entities.idx`, convergence flags.
- `mark` / `unmark` / `note` / `steps` / `list` / `back` / `report` / `exit`.
- Reports: full-analysis-log.txt and findings-report.txt (benign branches pruned, ASCII, <=80 cols);
  steps / findings / iocs `.jsonl` (`trail/1`). `case.sha256` + `case.md5` seal.
- `build.sh` single-file bundle; `test/run.sh` runs fixtures plus e2e on dash, busybox, and bash.
