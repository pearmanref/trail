# shellcheck shell=sh
# 00-env.sh - globals and small utilities shared by every console module.
# Strict POSIX sh: no `local`, no arrays. Function-scoped temporaries are
# prefixed with the function's initials to avoid collisions.

TRAIL_SCHEMA='trail/1'
: "${TRAIL_VERSION:=dev}"
# Console-only convergence glyph; report files always use "!" (ASCII).
case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
*UTF-8* | *utf8* | *UTF8* | *utf-8*) GLYPH=$(printf '\342\232\221') ;;
*) GLYPH='!' ;;
esac
LC_ALL=C; export LC_ALL
umask 077

# Console state (populated by main / case init)
MODE=''          # local | ssh
HOST=''          # ssh target spec (user@host)
JUMP=''          # ssh -J value
SOCK=''          # ssh ControlMaster socket
BIN_DIR=''       # --bin DIR on the target
CASE=''          # absolute case dir
CASE_ID=''
CUR=''           # step number whose items are the "current list"
TIMEOUT=60       # per-collector-call seconds
# shellcheck disable=SC2034 # used by cat/strings/log guards (M2+)
SIZE_CAP=10485760

msg()  { printf '%s\n' "$*"; }
# warn/err color only when stderr is itself a TTY, independent of stdout.
_estamp() { if [ -n "$COLOR" ] && [ -t 2 ]; then printf '\033[%sm%s\033[0m' "$C_WARN" "$1"; else printf '%s' "$1"; fi; }
warn() { printf '%s %s\n' "$(_estamp 'trail: warning:')" "$*" >&2; }
err()  { printf '%s %s\n' "$(_estamp 'trail:')" "$*" >&2; }
die()  { err "$*"; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

# q STR -> STR single-quoted for safe re-reading by sh (eval / snippets)
q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

utc_now()   { date -u +%Y-%m-%dT%H:%M:%SZ; }
utc_stamp() { date -u +%Y%m%dT%H%MZ; }
epoch_now() { date -u +%s; }

# hash_file md5|sha256 FILE -> hex digest, or "unavailable" (never fails)
hash_file() {
	hf_a=$1 hf_f=$2
	if have "${hf_a}sum"; then
		"${hf_a}sum" <"$hf_f" | awk '{print $1}'; return 0
	fi
	if have busybox && busybox "${hf_a}sum" </dev/null >/dev/null 2>&1; then
		busybox "${hf_a}sum" <"$hf_f" | awk '{print $1}'; return 0
	fi
	if have openssl; then
		openssl dgst -"$hf_a" -r <"$hf_f" 2>/dev/null | awk '{print $1}'; return 0
	fi
	echo unavailable
}

# pad4 N -> 0004
pad4() { printf '%04d' "$1"; }

# awkp FILE... -> awk program text assembled from embedded sources
# (avoids -f temp files so drop mode writes nothing outside the case dir)
awkp() { for ap_f in "$@"; do _src "$ap_f"; printf '\n'; done; }
