# trail

Interactive pivot console for live Linux host investigation (DFIR / threat
hunting). You run a collector, get back numbered investigation items, and
pivot with `<verb> <ref>`. Every step is logged and hashed, and you tag items
`mal`, `sus`, or `ben`. On exit, trail writes ASCII reports for people and
JSONL for other tools, then seals the case dir.

**Defensive / authorized use only.** trail is read-only on the target. It
never kills, deletes, or modifies anything there. Run it only on systems you
are authorized to investigate.

## Quick start

```sh
./build.sh                         # -> dist/trail (single POSIX sh file)
dist/trail --ssh analyst@10.0.0.5 -J bastion --out ~/cases
dist/trail --local --out /mnt/usb --bin /mnt/usb/bin    # drop-and-run
dist/trail report --case ~/cases/case-web01-20261022T2100Z
```

In the console, `help` lists every verb by domain. `help <verb>` shows one
verb's synopsis and types, `?` explains the current list, and `? <ref>` shows
one item's type, valid verbs, and entities.

```
trail[web01] -> ps -f 'nc|/tmp/'
[1] ps -f nc|/tmp/  (parent: root, items: 2)
1.1     pid    1337    1       www-data  10-22T20:20 /tmp/.x/kworker -c 203.0.113.7:4444  (exe deleted)
trail[web01] 1> mark 1.1 mal -t T1036.005,T1059.004 "deleted exe in /tmp, beacon args"
trail[web01] 1> exit
```

## Refs

| ref | meaning |
|---|---|
| `6` | item 6 of the current list |
| `6.2` | step 6, item 2 |
| `6.2.path` `.user` `.ip` `.pid` | an extracted entity of that item (falls back to a field, e.g. `.exe`) |
| `s6` | the whole step 6 (for `mark` and `note`) |
| `@6.2` | sets this step's parent explicitly |

The first ref in a command becomes the new step's parent, and `@ref`
overrides it. A positional bare integer is read as a ref. An option value is
read as a ref only in dotted form, so `-n 50` stays the number 50 while
`-g 1.4.user` resolves. A verb rejects the wrong item type and suggests a fix:
`exe accepts pid; 1.1.path is path - try 1.1.pid`.

## Design

```
src/console/     POSIX sh console: REPL, case dir, refs, marks, reports, transport
src/collectors/  POSIX sh snippets, one per verb, each with an @-metadata header
src/parsers/     POSIX awk: per-verb parsers + generic entity extraction
build.sh         bundles src/ -> dist/trail (collectors/parsers as heredocs)
test/            fixture-driven parser tests + end-to-end runs (dash, busybox, bash)
docs/schema.md   case dir + JSONL schema (trail/1)
```

- **One runtime for both modes.** The console is strict POSIX sh plus POSIX
  awk, so `--local` works on busybox/Alpine targets that have no bash. State
  lives in TSV files in the case dir, not in shell variables. That is why
  reports can be regenerated offline and come out byte for byte identical.
- **Collectors are dumb.** They emit raw text only: no parsing, no state, and
  no writes on the target. All interpretation happens on the analyst side,
  where the raw output is hashed (md5 + sha256) as soon as it arrives. The
  same collector files can later be reused as a batch kit.
- **One transport seam.** `xrun` in `src/console/20-transport.sh` is the only
  code where local and ssh differ. In ssh mode, a single ControlMaster socket
  carries every call, with keepalives. Every call has a timeout: `timeout(1)`
  when present, otherwise a POSIX watchdog.
- **One verb list.** Help, `?`, type validation, dispatch, and completion are
  all generated from the `# @verb` header blocks. There is no hand-maintained
  verb table anywhere. To add a verb, add a collector file with a header.
- **SELF.** trail hides its own process subtree (local mode) or the ssh
  session chain that serves its channel (ssh mode), and tags them `[SELF]`.
  Use `-a` to show them.
- **Drop mode.** trail warns when `--out` sits on a persistent target disk
  rather than tmpfs or removable media, and it keeps no REPL history.

## Collector header

```sh
# @verb    exe
# @domain  process
# @accepts pid
# @emits   path
# @opts    -f:re -a           # ":name" = takes a value
# @usage   exe <pid-ref>
# @summary Resolve /proc/<pid>/exe, hash (md5+sha256), file type, deleted flag
# @example exe 1.6
# @parser  exe                # src/parsers/exe.awk (default: generic)
# @needs   file               # optional tools; reported "unavailable" if missing
```

The snippet receives positional args through `set --` and options as
`OPT_<name>` variables. The parser reads the same `OPT_*` variables from
ENVIRON.

## Requirements

- Target: any POSIX sh (dash, busybox ash, bash), `/proc`, and coreutils or
  busybox. ssh mode needs only `sh` on the target.
- Analyst box: POSIX sh and awk (mawk, busybox, or gawk), plus `ssh` for
  remote mode. `rlwrap` is optional and adds line editing. `jq` is used by
  the tests only.
- Edit on Windows with Git Bash. `.gitattributes` forces LF, because CRLF
  breaks sh.

## Tests

```sh
test/run.sh            # parser fixtures + e2e (JSONL validity, benign pruning,
                       # ASCII/80-col reports, byte-identical regen, seal check)
test/run.sh --update   # regenerate fixture expectations (review the diff!)
```

## License

Apache-2.0 © 2026 pearmanref. The ATT&CK® technique IDs that appear in
reports are © The MITRE Corporation.
