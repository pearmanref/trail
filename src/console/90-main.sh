# shellcheck shell=sh
# 90-main.sh - CLI flags, session lifecycle, REPL.

SELF_TOP=$$
OUT_DIR=''
_ENDED=''

session_end() {
	[ -n "$_ENDED" ] && return 0
	_ENDED=1
	[ -n "$CASE" ] && [ -f "$CASE/session.tsv" ] || { ssh_close; return 0; }
	sess_set end "$(utc_now)"
	report_build && case_seal
	ssh_close
	msg ""
	msg "case sealed: $CASE"
	msg "  reports/full-analysis-log.txt  reports/findings-report.txt"
	msg "  reports/steps.jsonl  reports/findings.jsonl  reports/iocs.jsonl"
	msg "  case.sha256  case.md5"
}

dispatch() { # LINE -> 0, or 99 to exit
	dp_w=$(tokenize "$1")
	eval "set -- $dp_w"
	[ $# -eq 0 ] && return 0
	dp_v=$1; shift
	case $dp_v in quit | exit) return 99 ;; esac
	if ! reg_has "$dp_v"; then err "unknown verb: $dp_v (help lists verbs)"; return 0; fi
	if [ "$(reg_get "$dp_v" 2)" = builtin ]; then
		case $dp_v in
		'?') b_qmark "$@" ;;
		*) "b_$(printf '%s' "$dp_v" | tr '-' '_')" "$@" ;;
		esac
		return 0
	fi
	parse_cmd "$dp_v" "$@" || return 0
	run_step "$dp_v" "$PARENT" "$ARGS_DISP"
}

repl() {
	trap 'printf "\n"' INT
	while :; do
		printf '%s %s> ' "$(c "$C_HEAD" "trail[$(sess_get target_host)]")" "$(c "$C_DIM" "${CUR:--}")"
		IFS= read -r rp_l || { msg ""; break; }
		dispatch "$rp_l"
		[ $? -eq 99 ] && break
	done
}

# Re-exec under rlwrap for line editing/completion when available.
# Drop mode (--local) keeps no history anywhere on the target.
maybe_rlwrap() {
	[ -t 0 ] && [ -z "${TRAIL_RLWRAP:-}" ] && have rlwrap || return 0
	TRAIL_RLWRAP=1; export TRAIL_RLWRAP
	case " $* " in *" --local "*) exec rlwrap -C trail -H /dev/null "$0" "$@" ;; esac
	exec rlwrap -C trail "$0" "$@"
}

trail_main() {
	reg_load
	case ${1:-} in
	-h | --help | '') cli_usage; return 0 ;;
	--version) msg "trail $TRAIL_VERSION"; return 0 ;;
	--completion) cli_completion; return 0 ;;
	report)
		shift
		color_init
		[ "${1:-}" = --case ] && [ -n "${2:-}" ] || die "usage: trail report --case DIR"
		CASE=$(cd "$2" && pwd) || die "no case dir: $2"
		[ -f "$CASE/session.tsv" ] || die "not a trail case dir: $CASE"
		report_build && case_seal && msg "reports regenerated + resealed: $CASE"
		return $? ;;
	esac
	maybe_rlwrap "$@"
	# rlwrap'd child: our parent (rlwrap) is part of SELF
	[ -n "${TRAIL_RLWRAP:-}" ] && SELF_TOP=$PPID
	while [ $# -gt 0 ]; do
		case $1 in
		--local) MODE=local ;;
		--ssh) MODE=ssh; HOST=${2:?--ssh needs user@host}; shift ;;
		-J) JUMP=${2:?-J needs a host}; shift ;;
		--case) CASE_ID=${2:?--case needs an id}; shift ;;
		--out) OUT_DIR=${2:?--out needs a dir}; shift ;;
		--bin) BIN_DIR=${2:?--bin needs a dir}; shift ;;
		--timeout) TIMEOUT=${2:?--timeout needs seconds}; shift ;;
		--color) COLOR_MODE=${2:?--color needs always|never|auto}; shift ;;
		--color=*) COLOR_MODE=${1#--color=} ;;
		*) die "unknown flag: $1 (trail -h)" ;;
		esac
		shift
	done
	[ -n "$MODE" ] || die "choose --local or --ssh (trail -h)"
	color_init

	trap 'session_end' EXIT
	trap 'exit 130' HUP TERM
	if [ "$MODE" = ssh ]; then
		ssh_open
		tm_h=$(ssh -n -S "$SOCK" -o ControlMaster=no -T "$HOST" 'uname -n' 2>/dev/null)
	else
		tm_h=$(uname -n)
	fi
	case_init "$tm_h"
	OPTS_SH='' POS_SH=''
	run_step facts root '' quiet
	facts_to_session
	CUR=''
	msg "trail $TRAIL_VERSION - defensive / authorized use only"
	msg "case:   $CASE"
	msg "target: $(sess_get target_host) - $(sess_get target_os) - $(sess_get target_kernel)"
	if [ "$(sess_get target_uid)" != 0 ]; then
		warn "not root on target (uid $(sess_get target_uid)): other users' /proc, sockets and files will be partial. Continuing."
	fi
	if [ "$MODE" = local ]; then
		drop_check
		msg "drop mode: this console keeps no history; also 'unset HISTFILE' in the shell that launched it."
	fi
	msg "help lists verbs. start with: ps"
	repl
}
