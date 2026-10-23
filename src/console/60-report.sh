# shellcheck shell=sh
# 60-report.sh - report generation and case seal. Reports are a pure function
# of the case dir, so `trail report --case DIR` reproduces them byte for byte.

# @verb    report
# @kind    builtin
# @domain  analyst
# @accepts none
# @usage   report
# @summary Regenerate reports now (ASCII + JSONL); exit also seals the case
# @example report
b_report() { report_build && msg "reports: $CASE/reports/"; }

report_build() {
	set -- "$CASE"/steps/*.items
	[ -e "$1" ] || set --
	awk -v D="$CASE/reports" -v SJ="$CASE/session.json" "$(awkp parsers/lib.awk console/report.awk)" \
		"$CASE/session.tsv" "$CASE/steps.tsv" "$CASE/marks.log" "$CASE/notes.log" "$CASE/entities.idx" "$@"
}

# case.sha256 / case.md5 over every case file (sorted, relative paths)
case_seal() {
	cs_l=$(cd "$CASE" && find . -type f ! -name case.sha256 ! -name case.md5 | sort)
	for cs_a in sha256 md5; do
		printf '%s\n' "$cs_l" | while IFS= read -r cs_f; do
			printf '%s  %s\n' "$(hash_file "$cs_a" "$CASE/$cs_f")" "$cs_f"
		done >"$CASE/case.$cs_a"
	done
}

# session facts from step 0 (facts) -> session.tsv
facts_to_session() {
	ft_i="$CASE/steps/0000.items"
	for ft_k in hostname:target_host kernel:target_kernel os:target_os uid:target_uid ssh_connection:self_src; do
		ft_v=$(awk -F '\t' -v k="${ft_k%%:*}" "$(_src parsers/lib.awk)"' fld($0, "key") == k { print fld($0, "value"); exit }' "$ft_i")
		[ "${ft_k%%:*}" = ssh_connection ] && ft_v=${ft_v%% *}
		sess_set "${ft_k#*:}" "$ft_v"
	done
}
