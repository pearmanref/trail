# trail case and JSONL schema — `trail/1`

Every JSONL record carries `"schema":"trail/1"` and `"case_id"`. Keys are
stable snake_case. A breaking change (removing or renaming a key, or changing
a type) bumps the schema to `trail/2`. Adding a key is not a breaking change,
so consumers must ignore keys they don't recognize.

Encoding: one JSON object per line. Times are UTC ISO-8601 with `Z`. Strings
are ASCII-safe: control characters and every byte >= 0x80 are written as
`\u00XX`, one escape per byte. To get the original bytes back, decode the JSON
string and then encode it as Latin-1. The authoritative bytes are always in
`steps/NNNN.raw`, and `raw_sha256` pins them.

## reports/steps.jsonl — one record per step

| key | type | notes |
|---|---|---|
| schema, case_id | string | |
| step | int | 0 = session facts |
| parent | string | `root`, or the item ref (`S.N`) this step pivoted from |
| ts | string | UTC start of the collector call |
| verb, args | string | `args` holds the arguments as the analyst typed them; the exact snippet is in `steps/NNNN.cmd` |
| collector | string | collector file name |
| binary | string | data source that ran (`/proc`, `ps`, `sh`, ...) |
| raw_md5, raw_sha256 | string | hashes of `steps/NNNN.raw`, computed on receipt (analyst side); `unavailable` if no hasher exists |
| status | string | `ok` \| `timeout` \| `error` \| `unavailable` |
| rc | int | collector exit status (124 = timeout) |
| items | array | `{id, type, fields{}, entities{}}`; `entities` maps a kind to an array of strings |
| flags | array | convergence strings, `"<id> <kind>=<value> seen: <refs>"` |

## reports/findings.jsonl — one record per effective MAL/SUS mark

`finding_id` (F001…, in mark order), `verdict` (`mal`\|`sus`), `ref` (`S.N` or
`sN`), `entities{}`, `reason`, `attack[]` (IDs checked for format only),
`path[]` (refs from the root to the leaf, e.g. `["s1","1.6","s2","2.3"]`),
`evidence[{step, raw_sha256}]`, `ts_marked`, `ts_evidence[]` (every ISO
timestamp found on the marked item).

BEN marks and unmarked branches are never written here.

## reports/iocs.jsonl — one record per (kind, value)

`kind`: `ip|md5|sha256|path|key|domain`, plus `value`, `finding_ids[]`, `first_seen`, and
`last_seen`. The two seen times are the earliest and latest step times at which
the value appeared anywhere in the case. When a mark targets an entity ref
(`mark 1.6.path mal`), only that entity becomes an IOC. Otherwise every
ip/path/domain entity on the marked item does, plus its md5/sha256 fields.

## Case dir internals (TSV, tab-separated, append-only unless noted)

| file | columns |
|---|---|
| session.tsv | key, value (rewritten in place; rendered to session.json) |
| steps.tsv | step, parent, ts, verb, args, collector, binary, md5, sha256, rc, nitems, dur_s, status |
| steps/NNNN.items | id, type, `k=v`…, `@kind=v`… (entities; parser-supplied entities come first, so `S.N.pid` is the item's own pid) |
| entities.idx | kind, value, item_id, step |
| marks.log | ts, action (`mark`\|`unmark`), ref, verdict, attack (comma-separated), reason, entity (`kind=value` when an entity ref was marked) |
| notes.log | ts, current step, ref (may be empty), text |

The effective verdict for a ref is its last `mark`/`unmark` line. Reports are
a pure function of these files, so `trail report --case DIR` reproduces them
byte for byte. `case.sha256` and `case.md5` cover every other file in the
case dir, with sorted relative paths.

## Item types and their entities

| type | emitted by | key fields | entities |
|---|---|---|---|
| fact | facts | key, value | — |
| pid | ps, tree | pid, ppid, uid, user, comm, exe, cmd, start | @pid, @user, @path |
| path | exe, stat, file, hash, ls | path, md5, sha256, ftype, size, mode, owner, mtime | @path, @md5, @sha256 |
| socket | net, who-port | proto, state, laddr, lport, raddr, rport, pid, comm | @ip (remote), @port (local), @pid |
| line | cat, generic | text | ip/path/pid/user by generic scan |

Entity kinds: `ip`, `path`, `pid`, `user`, `port`, `md5`, `sha256`, `domain`.
Wildcard bind addresses (`0.0.0.0`, `::`) are never recorded as `ip` entities.

## Collector raw metadata lines

Collectors emit raw text only; `#@` lines carry metadata the parser or console
consumes (parsers strip every `#@` line):

- `#@bin <source>` — the binary or data source actually used (`/proc`, `ss`, `stat`, ...).
- `#@selfsh <pid>` / `#@trailpid <pid>` — SELF detection.
- `#@unavailable <tool>` — step status becomes `unavailable`.
- `#@skip <path>: <reason>` — a cat/strings/hash guard refused a target (device, FIFO, oversize).
- `#@proto <p>` / `#@fdmap` / `#@ss` — section markers in the `net` dump.
- `#@filter lport <N>` — `who-port` restricts the socket table to one local port.
- `#@dir <d>` — base directory for `ls`, so names become absolute paths.
- `#@target <pid>` — the pid `tree` builds its ancestry/descendants around.
