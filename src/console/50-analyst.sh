# shellcheck shell=sh
# 50-analyst.sh - analyst verbs. marks.log and notes.log are append-only;
# the effective verdict for a ref is its last mark/unmark line.

# @verb    mark
# @kind    builtin
# @domain  analyst
# @accepts any
# @usage   mark <ref|sN> mal|sus|ben [-t T####[.###],...] "reason"
# @summary Tag an item (or whole step) with a verdict, optional ATT&CK IDs and a reason
# @example mark 1.6 mal -t T1059.004,T1036.005 "bash reverse shell from /tmp"
# @example mark s3 ben "routine cron"
b_mark() {
	[ $# -ge 2 ] || { err "usage: mark <ref|sN> mal|sus|ben [-t T####,...] \"reason\""; return 1; }
	ref_resolve "$1" || return 1
	bm_v=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]'); shift 2
	case $bm_v in mal | sus | ben) ;; *) err "verdict must be mal, sus or ben"; return 1 ;; esac
	bm_t=''
	if [ "${1:-}" = -t ]; then
		[ $# -ge 2 ] || { err "-t needs ATT&CK IDs"; return 1; }
		bm_t=$(printf '%s' "$2" | tr '[:lower:]' '[:upper:]' | tr -d ' '); shift 2
		for bm_x in $(printf '%s' "$bm_t" | tr ',' ' '); do
			printf '%s' "$bm_x" | grep -Eq '^T[0-9]{4}(\.[0-9]{3})?$' || { err "bad ATT&CK ID: $bm_x (T#### or T####.###)"; return 1; }
		done
	fi
	bm_r=$(printf '%s' "$*" | tr '\t\n' '  ')
	bm_e=''
	[ -n "$R_ENT" ] && bm_e="$R_ENT=$R_VAL"
	printf '%s\tmark\t%s\t%s\t%s\t%s\t%s\n' "$(utc_now)" "$R_ID" "$bm_v" "$bm_t" "$bm_r" "$bm_e" >>"$CASE/marks.log"
	msg "marked $R_ID $(printf '%s' "$bm_v" | tr '[:lower:]' '[:upper:]')${bm_t:+ [$bm_t]}${bm_e:+ ($bm_e)}"
}

# @verb    unmark
# @kind    builtin
# @domain  analyst
# @accepts any
# @usage   unmark <ref|sN>
# @summary Remove the verdict from an item or step (history stays in marks.log)
# @example unmark 1.6
b_unmark() {
	[ $# -eq 1 ] || { err "usage: unmark <ref|sN>"; return 1; }
	ref_resolve "$1" || return 1
	printf '%s\tunmark\t%s\t\t\t\t\n' "$(utc_now)" "$R_ID" >>"$CASE/marks.log"
	msg "unmarked $R_ID"
}

# @verb    note
# @kind    builtin
# @domain  analyst
# @accepts any
# @usage   note [ref|sN] "text"
# @summary Attach a free-text analyst note to the current step or a ref
# @example note "sshd spawned bash with no tty - check auth.log"
# @example note 1.6 "parent is cron"
b_note() {
	[ $# -ge 1 ] || { err "usage: note [ref] \"text\""; return 1; }
	bn_ref=''
	if [ $# -ge 2 ] && is_ref "$1"; then ref_resolve "$1" || return 1; bn_ref=$R_ID; shift; fi
	bn_t=$(printf '%s' "$*" | tr '\t\n' '  ')
	printf '%s\t%s\t%s\t%s\n' "$(utc_now)" "${CUR:-0}" "$bn_ref" "$bn_t" >>"$CASE/notes.log"
	msg "noted${bn_ref:+ on $bn_ref}"
}

# @verb    steps
# @kind    builtin
# @domain  analyst
# @accepts none
# @usage   steps
# @summary Show the step tree (parent chain, status, item and mark counts)
# @example steps
b_steps() {
	awk -F '\t' '
	FILENAME ~ /marks\.log$/ { if ($2 == "mark") M[$3] = toupper($4); else delete M[$3]; next }
	{ S[++n] = $0; P[$1] = $2 }
	END {
		for (r in M) { s = r; sub(/^s/, "", s); sub(/\..*/, "", s); C[s] = C[s] " " r ":" M[r] }
		for (i = 1; i <= n; i++) {
			split(S[i], f, "\t"); d = 0; p = f[2]
			while (p != "root" && d < 50) { sp = p; sub(/\..*/, "", sp); p = P[sp]; d++ }
			printf "%s[%s] %s %s  <- %s  items:%s %s%s\n", sprintf("%" (2 * d) "s", ""), f[1], f[4], f[5], f[2], f[11], (f[13] == "ok" ? "" : f[13]), C[f[1]]
		}
	}' "$CASE/marks.log" "$CASE/steps.tsv"
}

# @verb    list
# @kind    builtin
# @domain  analyst
# @accepts none
# @usage   list [S]
# @summary Re-show the current list, or step S's list (and make it current)
# @example list 1
b_list() {
	if [ $# -ge 1 ]; then
		[ -f "$CASE/steps/$(pad4 "$1").items" ] || { err "no step $1"; return 1; }
		CUR=$1
	fi
	[ -n "$CUR" ] || { msg "no current list yet - start with: ps"; return 0; }
	show_list "$CUR"
}

# @verb    back
# @kind    builtin
# @domain  analyst
# @accepts none
# @usage   back
# @summary Make the parent step's list current again
# @example back
b_back() {
	[ -n "$CUR" ] || { msg "no current list"; return 0; }
	bb_p=$(step_field "$CUR" 2)
	if [ "$bb_p" = root ]; then msg "step $CUR is a root step"; return 0; fi
	CUR=${bb_p%%.*}
	show_list "$CUR"
}

# @verb    exit
# @kind    builtin
# @domain  analyst
# @accepts none
# @usage   exit
# @summary Write reports, seal the case (case.sha256 + case.md5), close transport
# @example exit
