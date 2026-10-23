# shellcheck shell=sh
# 30-case.sh - case dir, step execution, parsing pipeline, list display.
# The case dir on disk is the single source of truth; nothing lives only in
# shell variables except CUR (current list pointer).
#
# Internal files (documented in docs/schema.md):
#   session.tsv   key \t value            (rendered to session.json)
#   steps.tsv     step parent ts verb args collector binary md5 sha256 rc nitems dur status
#   entities.idx  kind value item_id step
#   marks.log     ts action ref verdict attack reason entity
#   notes.log     ts step ref text

sess_set() { # KEY VALUE
	ss_v=$(printf '%s' "$2" | tr '\t\n' '  ')
	awk -F '\t' -v k="$1" -v v="$ss_v" 'BEGIN{OFS="\t"} $1==k{print k, v; f=1; next} {print} END{if(!f) print k, v}' \
		"$CASE/session.tsv" >"$CASE/session.tsv.new" && mv "$CASE/session.tsv.new" "$CASE/session.tsv"
}
sess_get() { awk -F '\t' -v k="$1" '$1==k{print $2; exit}' "$CASE/session.tsv"; }

case_init() { # TARGET_HOSTNAME
	ci_h=$(printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_')
	[ -n "$CASE_ID" ] || CASE_ID="case-${ci_h:-unknown}-$(utc_stamp)"
	ci_out=${OUT_DIR:-.}
	mkdir -p "$ci_out" || die "cannot create --out $ci_out"
	ci_out=$(cd "$ci_out" && pwd) || die "bad --out"
	CASE="$ci_out/$CASE_ID"
	[ -e "$CASE" ] && die "case dir exists: $CASE (use --case to pick another id)"
	mkdir -p "$CASE/steps" "$CASE/carved" "$CASE/reports" || die "cannot create $CASE"
	: >"$CASE/steps.tsv"; : >"$CASE/steps.log"; : >"$CASE/marks.log"
	: >"$CASE/notes.log"; : >"$CASE/entities.idx"
	{
		printf 'schema\t%s\n' "$TRAIL_SCHEMA"
		printf 'case_id\t%s\n' "$CASE_ID"
		printf 'tool_version\ttrail %s\n' "$TRAIL_VERSION"
		printf 'mode\t%s\n' "$MODE"
		printf 'target_spec\t%s\n' "${HOST:-localhost}"
		printf 'jump\t%s\n' "$JUMP"
		printf 'bin_dir\t%s\n' "$BIN_DIR"
		printf 'timeout_s\t%s\n' "$TIMEOUT"
		printf 'console_pid\t%s\n' "$SELF_TOP"
		printf 'start\t%s\n' "$(utc_now)"
		printf 'end\t\n'
	} >"$CASE/session.tsv"
}

step_next() { awk 'END{print NR}' "$CASE/steps.tsv"; }
step_field() { awk -F '\t' -v s="$1" -v c="$2" '$1==s{print $c; exit}' "$CASE/steps.tsv"; }
item_line() { # ID (S.N)
	il_s=${1%%.*}
	[ -f "$CASE/steps/$(pad4 "$il_s").items" ] || return 1
	awk -F '\t' -v id="$1" '$1==id{print; f=1; exit} END{exit !f}' "$CASE/steps/$(pad4 "$il_s").items"
}

# build_snippet VERB -> stdout; uses OPTS_SH, POS_SH from parse_cmd
build_snippet() {
	printf '# trail %s snippet: verb %s (sent verbatim to the target via sh -s)\n' "$TRAIL_VERSION" "$1"
	printf 'LC_ALL=C; export LC_ALL\n'
	# shellcheck disable=SC2016
	[ -n "$BIN_DIR" ] && printf 'PATH=%s:"$PATH"; export PATH\n' "$(q "$BIN_DIR")"
	printf '%s' "$OPTS_SH"
	printf 'set -- %s\n' "$POS_SH"
	# shellcheck disable=SC2016
	printf 'echo "#@selfsh $$"\n'
	[ "$MODE" = local ] && printf 'echo "#@trailpid %s"\n' "$SELF_TOP"
	# FORCE derives from OPT_force, which was just written above (target-side).
	# shellcheck disable=SC2016
	printf 'SIZECAP=%s; FORCE=${OPT_force:-}\n' "$SIZE_CAP"
	_src collectors/_prelude.sh
	_src "collectors/$1.sh"
}

# run_step VERB PARENT ARGS_DISPLAY [quiet]
# Requires OPTS_SH / POS_SH (set by parse_cmd; empty for no-arg verbs).
run_step() {
	rs_v=$1 rs_par=$2 rs_args=$3 rs_quiet=${4:-}
	rs_n=$(step_next); rs_p=$(pad4 "$rs_n"); rs_b="$CASE/steps/$rs_p"
	build_snippet "$rs_v" >"$rs_b.cmd"
	rs_ts=$(utc_now); rs_t0=$(epoch_now)
	xrun "$rs_b.cmd" "$rs_b.raw" "$rs_b.err"; rs_rc=$?
	rs_dur=$(( $(epoch_now) - rs_t0 ))
	[ -s "$rs_b.err" ] || rm -f "$rs_b.err"
	rs_md5=$(hash_file md5 "$rs_b.raw"); rs_sha=$(hash_file sha256 "$rs_b.raw")
	rs_bin=$(awk '/^#@bin /{print $2; exit}' "$rs_b.raw")
	rs_st=ok
	if [ "$rs_rc" -eq 124 ]; then rs_st=timeout
	elif grep -q '^#@unavailable' "$rs_b.raw"; then rs_st=unavailable
	elif [ "$rs_rc" -ne 0 ]; then rs_st="error"
	fi
	rs_parser=$(reg_get "$rs_v" 10)
	(
		eval "$OPTS_SH"
		for rs_o in $(printf '%s' "$OPTS_SH" | sed -n 's/^\(OPT_[A-Za-z0-9_]*\)=.*/\1/p'); do export "${rs_o?}"; done
		TRAIL_STEP=$rs_n; export TRAIL_STEP
		awk "$(awkp parsers/lib.awk "parsers/$rs_parser.awk")" "$rs_b.raw" |
			awk "$(awkp parsers/lib.awk parsers/entities.awk)"
	) >"$rs_b.items"
	rs_ni=$(awk 'END{print NR}' "$rs_b.items")
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$rs_n" "$rs_par" "$rs_ts" "$rs_v" "$(printf '%s' "$rs_args" | tr '\t' ' ')" "$rs_v" \
		"${rs_bin:-unknown}" "$rs_md5" "$rs_sha" "$rs_rc" "$rs_ni" "$rs_dur" "$rs_st" >>"$CASE/steps.tsv"
	printf '%s step %s %s %s parent=%s rc=%s status=%s items=%s sha256=%s\n' \
		"$rs_ts" "$rs_n" "$rs_v" "$rs_args" "$rs_par" "$rs_rc" "$rs_st" "$rs_ni" "$rs_sha" >>"$CASE/steps.log"
	awk -F '\t' -v s="$rs_n" '{for(i=3;i<=NF;i++) if(substr($i,1,1)=="@"){p=index($i,"="); printf "%s\t%s\t%s\t%s\n", substr($i,2,p-2), substr($i,p+1), $1, s}}' \
		"$rs_b.items" >>"$CASE/entities.idx"
	[ "$rs_st" = ok ] || warn "step $rs_n $rs_v: $rs_st (rc=$rs_rc)$( [ -f "$rs_b.err" ] && printf ' - %s' "$(head -n 1 "$rs_b.err")")"
	[ "$rs_st" = unavailable ] && msg "  $(sed -n 's/^#@unavailable //p' "$rs_b.raw" | head -n 1) unavailable on target"
	[ -n "$rs_quiet" ] && return 0
	if [ "$rs_ni" -gt 0 ]; then CUR=$rs_n; show_list "$rs_n"; else msg "[$rs_n] $rs_v: no items"; fi
}

# show_list STEP - numbered items, marks, convergence flags.
# Color (when on) is applied here only; truncation to width W counts visible
# characters, not SGR escapes, so colored rows still wrap at the real column.
show_list() {
	sl_f="$CASE/steps/$(pad4 "$1").items"
	[ -f "$sl_f" ] || { err "no step $1"; return 1; }
	msg "$(c "$C_HEAD" "[$1] $(step_field "$1" 4) $(step_field "$1" 5)")  (parent: $(step_field "$1" 2), items: $(step_field "$1" 11))"
	awk -F '\t' -v G="$GLYPH" -v W="${COLUMNS:-120}" -v ON="$COLOR" \
		-v cMAL="$C_MAL" -v cSUS="$C_SUS" -v cBEN="$C_BEN" -v cSELF="$C_SELF" -v cCONV="$C_CONV" \
		-v cIP="$C_IP" -v cHASH="$C_HASH" -v cDOMAIN="$C_DOMAIN" -v cPATH="$C_PATH" -v cPID="$C_PID" -v cUSER="$C_USER" -v cPORT="$C_PORT" \
		"$(_src parsers/lib.awk)"'
	function col(code, s) { return (ON != "" && code != "") ? "\033[" code "m" s "\033[0m" : s }
	function ecol(k, v) { return col(k == "ip" ? cIP : k == "path" ? cPATH : k == "pid" ? cPID : k == "user" ? cUSER : (k == "md5" || k == "sha256" || k == "hash") ? cHASH : k == "domain" ? cDOMAIN : k == "port" ? cPORT : "", v) }
	function vcol(m) { return m == "MAL" ? cMAL : m == "SUS" ? cSUS : m == "BEN" ? cBEN : "" }
	FILENAME ~ /steps\.tsv$/ { STEPVERB[$1] = $4; next }
	FILENAME ~ /marks\.log$/ { if ($2 == "mark") MARKV[$3] = toupper($4); else delete MARKV[$3]; next }
	FILENAME ~ /entities\.idx$/ { idx_add($1, $2, $3, $4); next }
	{
		st = $1; sub(/\..*/, "", st)
		d = fld($0, "_d"); self = (fld($0, "self") != "")
		row = substr(sprintf("%-7s %-6s %s", $1, $2, d), 1, W)   # truncate uncolored
		if (self) row = col(cSELF, row)   # whole SELF row dimmed
		if (MARKV[$1] != "") row = row "  " col(vcol(MARKV[$1]), "[" MARKV[$1] "]")
		print row
		for (i = 3; i <= NF; i++) if (substr($i, 1, 1) == "@") {
			p = index($i, "="); k = substr($i, 2, p - 2); v = substr($i, p + 1)
			cv = conv(k, v, $1, st, STEPVERB[st])
			if (cv != "") print col(cCONV, "        " G) " " k "=" ecol(k, v) " " col(cCONV, "seen: " cv)
		}
	}' "$CASE/steps.tsv" "$CASE/marks.log" "$CASE/entities.idx" "$sl_f"
}

# Drop mode: warn when the case dir sits on a persistent target disk.
drop_check() {
	dc_fs=$(awk -v d="$CASE" '{ m = ($2 == "/" ? "/" : $2 "/"); if (index(d "/", m) == 1 && length(m) > l) { l = length(m); t = $3; dev = $1 } }
		END { print t, dev }' /proc/mounts 2>/dev/null)
	dc_t=${dc_fs%% *}; dc_dev=${dc_fs#* }
	case $dc_t in tmpfs | ramfs) return 0 ;; esac
	dc_blk=$(basename "$dc_dev" 2>/dev/null | sed 's/[0-9]*$//; s/p$//')
	if [ -n "$dc_blk" ] && [ "$(cat "/sys/block/$dc_blk/removable" 2>/dev/null)" = 1 ]; then return 0; fi
	warn "case dir is on ${dc_t:-unknown fs} ($dc_dev): this writes to the target's disk. Prefer tmpfs or removable media (--out)."
}
