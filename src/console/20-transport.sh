# shellcheck shell=sh
# 20-transport.sh - the ONLY place local and ssh modes differ.
# A snippet file (steps/NNNN.cmd) is fed on stdin to `sh -s`, locally or over
# the session's ControlMaster socket. Every call is bounded by $TIMEOUT.

# with_timeout SECS INFILE CMD... - prefer timeout(1); POSIX watchdog fallback.
# INFILE is explicit because async lists get /dev/null as stdin in sh.
# The watchdog only ever signals our own child, never target processes.
with_timeout() {
	wt_s=$1 wt_i=$2; shift 2
	if have timeout; then timeout "$wt_s" "$@" <"$wt_i"; return $?; fi
	"$@" <"$wt_i" &
	wt_c=$!
	( sleep "$wt_s"; kill -TERM "$wt_c" 2>/dev/null ) &
	wt_w=$!
	wait "$wt_c"; wt_rc=$?
	kill "$wt_w" 2>/dev/null; wait "$wt_w" 2>/dev/null
	[ "$wt_rc" -eq 143 ] && wt_rc=124   # match timeout(1)
	return "$wt_rc"
}

# xrun CMDFILE OUTFILE ERRFILE -> collector exit status (124 = timeout)
xrun() {
	xr_c=$1 xr_o=$2 xr_e=$3
	if [ "$MODE" = local ]; then
		set -- sh -s
	else
		set -- ssh -S "$SOCK" -o ControlMaster=no -o BatchMode=yes -T "$HOST" 'sh -s'
	fi
	with_timeout "$TIMEOUT" "$xr_c" "$@" >"$xr_o" 2>"$xr_e"
}

ssh_open() {
	ss_d=$(mktemp -d 2>/dev/null) || { ss_d="${TMPDIR:-/tmp}/trail.$$"; mkdir -m 700 "$ss_d" || die "cannot create socket dir"; }
	SOCK="$ss_d/cm.sock"
	# Master authenticates interactively (keys, agent, password, MFA), then
	# backgrounds; all collector calls ride this one connection.
	set -- -M -S "$SOCK" -fN -o ControlPersist=yes -o ServerAliveInterval=15 \
		-o ServerAliveCountMax=3 -o ConnectTimeout=20
	[ -n "$JUMP" ] && set -- "$@" -J "$JUMP"
	# shellcheck disable=SC2029
	ssh "$@" "$HOST" || die "ssh master connection to $HOST failed"
}

ssh_close() {
	[ -n "$SOCK" ] || return 0
	ssh -S "$SOCK" -O exit "$HOST" >/dev/null 2>&1
	rm -f "$SOCK"; rmdir "$(dirname "$SOCK")" 2>/dev/null
	SOCK=''
}
