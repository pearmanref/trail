# shellcheck shell=sh
# 40-refs.sh - tokenizing, ref resolution, argument parsing + type checks.
#
# Ref grammar:
#   N          item N of the current list
#   S.N        step S, item N
#   S.N.ENT    entity ENT (path/user/ip/pid/...) of that item, else field ENT
#   sN         whole step N (mark/note only)
#   @REF       explicit parent for the new step (removed from args)
# Parent rule: the first ref used in a command becomes the step's parent
# unless @REF overrides it; no ref -> parent "root".
# Positional bare integers are refs; option values are refs only in dotted
# form (so `-n 50` stays the number 50, `-g 1.4.user` resolves).

# tokenize LINE -> shell-quoted words for: eval "set -- $(tokenize ...)"
tokenize() {
	printf '%s\n' "$1" | awk '{
		s = $0; n = length(s); tok = ""; inq = ""; have = 0; out = ""
		for (i = 1; i <= n; i++) {
			c = substr(s, i, 1)
			if (inq != "") { if (c == inq) inq = ""; else tok = tok c; continue }
			if (c == "\"" || c == "\047") { inq = c; have = 1; continue }
			if (c == " " || c == "\t") { if (have) { out = out " " sq(tok); tok = ""; have = 0 } continue }
			tok = tok c; have = 1
		}
		if (have) out = out " " sq(tok)
		print out
	}
	function sq(t) { gsub(/\047/, "\047\\\047\047", t); return "\047" t "\047" }'
}

is_ref() { printf '%s' "$1" | grep -Eq '^([0-9]+|[0-9]+\.[0-9]+|[0-9]+\.[0-9]+\.[A-Za-z_][A-Za-z0-9_]*|s[0-9]+)$'; }
is_dotref() { printf '%s' "$1" | grep -Eq '^[0-9]+\.[0-9]+(\.[A-Za-z_][A-Za-z0-9_]*)?$'; }

# ref_resolve TOKEN -> R_ID R_TYPE R_VAL R_ENT R_STEP (returns 1 + message)
ref_resolve() {
	R_ID='' R_TYPE='' R_VAL='' R_ENT='' R_STEP=''
	rr_t=$1
	case $rr_t in
	s[0-9]*)
		R_STEP=${rr_t#s}
		[ -n "$(step_field "$R_STEP" 1)" ] || { err "no step $R_STEP"; return 1; }
		R_ID=$rr_t R_TYPE=step R_VAL="$(step_field "$R_STEP" 4) $(step_field "$R_STEP" 5)"
		return 0 ;;
	esac
	is_ref "$rr_t" || { err "not a ref: $rr_t"; return 1; }
	rr_ent=''
	case $rr_t in
	*.*.*) rr_ent=${rr_t##*.}; rr_t=${rr_t%.*} ;;
	*.*) ;;
	*)
		[ -n "$CUR" ] || { err "no current list for bare ref $rr_t; use S.N"; return 1; }
		rr_t="$CUR.$rr_t" ;;
	esac
	rr_l=$(item_line "$rr_t") || { err "no item $rr_t"; return 1; }
	R_ID=$rr_t R_STEP=${rr_t%%.*}
	R_TYPE=$(printf '%s\n' "$rr_l" | awk -F '\t' '{print $2}')
	if [ -n "$rr_ent" ]; then
		R_ENT=$rr_ent
		R_VAL=$(printf '%s\n' "$rr_l" | awk "$(_src parsers/lib.awk)"' { v = fld($0, "@" e); if (v == "") v = fld($0, e); print v }' e="$rr_ent")
		[ -n "$R_VAL" ] || { err "$rr_t has no entity or field '$rr_ent' (try ? $rr_t)"; return 1; }
		case $rr_ent in
		pid | path | user | ip | port | domain) R_TYPE=$rr_ent ;;
		exe) R_TYPE=path ;;
		*) R_TYPE=$rr_ent ;;
		esac
		return 0
	fi
	R_VAL=$(printf '%s\n' "$rr_l" | awk "$(_src parsers/lib.awk)"' {
		t = $2; v = fld($0, t)
		if (v == "" && t == "line") v = fld($0, "text")
		if (v == "" && t == "fact") v = fld($0, "value")
		if (v == "") v = fld($0, "_d")
		print v }')
}

# accepts_type VERB TYPE -> 0 if VERB @accepts TYPE (or any)
accepts_type() {
	at_a=$(reg_get "$1" 4)
	for at_x in $(printf '%s' "$at_a" | tr ',' ' '); do
		[ "$at_x" = "$2" ] || [ "$at_x" = any ] && return 0
	done
	return 1
}

# type_hint VERB REF -> suggestion when the item carries a usable entity
type_hint() {
	th_a=$(reg_get "$1" 4)
	for th_x in $(printf '%s' "$th_a" | tr ',' ' '); do
		if item_line "$R_ID" | grep -q "$(printf '\t')@$th_x="; then printf ' - try %s.%s' "$R_ID" "$th_x"; return 0; fi
	done
}

# parse_cmd VERB ARGS... -> OPTS_SH POS_SH PARENT ARGS_DISP (returns 1 on error)
parse_cmd() {
	pc_v=$1; shift
	OPTS_SH='' POS_SH='' PARENT='' ARGS_DISP="$*" pc_npos=0
	pc_opts=" $(reg_get "$pc_v" 6) "
	pc_acc=$(reg_get "$pc_v" 4)
	while [ $# -gt 0 ]; do
		pc_t=$1; shift
		case $pc_t in
		@*)
			ref_resolve "${pc_t#@}" || return 1
			PARENT=$R_ID; continue ;;
		-*)
			case $pc_opts in
			*" $pc_t:"*)
				[ $# -gt 0 ] || { err "$pc_v: $pc_t needs a value"; return 1; }
				pc_val=$1; shift
				if is_dotref "$pc_val"; then
					ref_resolve "$pc_val" || return 1
					[ -n "$PARENT" ] || PARENT=$R_ID
					pc_val=$R_VAL
				fi ;;
			*" $pc_t "*) pc_val=1 ;;
			*) err "$pc_v: unknown option $pc_t (help $pc_v)"; return 1 ;;
			esac
			pc_name=$(printf '%s' "$pc_t" | sed 's/^-*//; s/-/_/g')
			OPTS_SH="${OPTS_SH}OPT_$pc_name=$(q "$pc_val")
"
			continue ;;
		esac
		[ "$pc_acc" = none ] && { err "$pc_v takes no arguments (help $pc_v)"; return 1; }
		if is_ref "$pc_t"; then
			# A bare integer is a ref into the current list, but only if that
			# item exists; otherwise it is a literal (so `who-port 4444` and
			# `log ... -n 50`-style literals work). Dotted refs (6.2) never
			# fall back - a missing one is an error, not a filename.
			case $pc_t in
			'' | *[!0-9]*) ;;
			*) if [ -z "$CUR" ] || ! item_line "$CUR.$pc_t" >/dev/null 2>&1; then
					POS_SH="$POS_SH $(q "$pc_t")"; pc_npos=$((pc_npos + 1)); continue
				fi ;;
			esac
			ref_resolve "$pc_t" || return 1
			if ! accepts_type "$pc_v" "$R_TYPE"; then
				err "$pc_v accepts $pc_acc; $R_ID${R_ENT:+.$R_ENT} is $R_TYPE$(type_hint "$pc_v")"
				return 1
			fi
			[ -n "$PARENT" ] || PARENT=$R_ID${R_ENT:+}
			pc_t=$R_VAL
		fi
		POS_SH="$POS_SH $(q "$pc_t")"; pc_npos=$((pc_npos + 1))
	done
	[ -n "$PARENT" ] || PARENT=root
	return 0
}
