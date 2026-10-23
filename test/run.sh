#!/bin/sh
# shellcheck disable=SC1090,SC2012,SC2086  # fixture env files; mktemp-made dirs; $sh split is intended
# test/run.sh - fixture-driven parser tests + end-to-end report checks.
# Each fixture dir holds VERB.raw, VERB.env (OPT_* for the parser) and the
# expected VERB.items. Regenerate expectations with: test/run.sh --update
set -u
cd "$(dirname "$0")/.." || exit 2
LC_ALL=C; export LC_ALL
upd=${1:-}; fail=0; pass=0
for raw in test/fixtures/*/*.raw; do
	dir=${raw%/*}; verb=$(basename "$raw" .raw)
	parser=$(awk -F '\t' -v v="$verb" '$1==v{print $10}' <<EOT
$(awk -f src/console/meta.awk src/console/*.sh src/collectors/*.sh)
EOT
)
	got=$(
		[ -f "$dir/$verb.env" ] && . "$dir/$verb.env" && export OPT_f OPT_u OPT_a 2>/dev/null
		TRAIL_STEP=1; export TRAIL_STEP
		awk "$(cat src/parsers/lib.awk src/parsers/"${parser:-generic}".awk)" "$raw" |
			awk "$(cat src/parsers/lib.awk src/parsers/entities.awk)"
	)
	if [ "$upd" = --update ]; then printf '%s\n' "$got" >"$dir/$verb.items"; echo "updated $dir/$verb.items"; continue; fi
	if printf '%s\n' "$got" | diff -u "$dir/$verb.items" - >/dev/null; then pass=$((pass + 1)); echo "ok   $dir/$verb"
	else fail=$((fail + 1)); echo "FAIL $dir/$verb"; printf '%s\n' "$got" | diff -u "$dir/$verb.items" - | head -20; fi
done
echo "parsers: $pass passed, $fail failed"
[ "$upd" = --update ] && exit 0

# ---- end-to-end: scripted local session per available shell
e2e() { # SHELL
	t=$(mktemp -d) || return 1
	printf '%s\n' 'ps' 'mark 1 mal -t T1059.004 "e2e finding"' 'mark 2 ben "e2e benign"' \
		'note "e2e note"' 'ps -u nobody' 'exit' |
		"$1" src/console/trail.sh --local --out "$t" >/dev/null 2>&1
	c=$(ls -d "$t"/case-* 2>/dev/null | head -n 1)
	ok=1
	[ -n "$c" ] && [ -f "$c/case.sha256" ] || { echo "FAIL e2e($1): no sealed case"; rm -rf "$t"; return 1; }
	for f in "$c"/reports/*.jsonl; do
		if command -v jq >/dev/null; then
			while IFS= read -r l; do printf '%s\n' "$l" | jq -ce . >/dev/null 2>&1 || { echo "FAIL e2e($1): bad json in $f"; ok=0; break; }; done <"$f"
		fi
	done
	grep -q 'e2e benign' "$c/reports/findings-report.txt" && { echo "FAIL e2e($1): benign leaked into findings"; ok=0; }
	grep -q 'e2e finding' "$c/reports/findings-report.txt" || { echo "FAIL e2e($1): finding missing"; ok=0; }
	awk 'length($0) > 80 || /[^ -~]/ { bad = 1 } END { exit bad }' "$c"/reports/*.txt || { echo "FAIL e2e($1): report not ASCII/<=80 cols"; ok=0; }
	h1=$(cat "$c"/reports/* | cksum)
	"$1" src/console/trail.sh report --case "$c" >/dev/null 2>&1
	[ "$(cat "$c"/reports/* | cksum)" = "$h1" ] || { echo "FAIL e2e($1): report regen not identical"; ok=0; }
	(cd "$c" && sha256sum -c --quiet case.sha256 >/dev/null 2>&1) || { command -v sha256sum >/dev/null && { echo "FAIL e2e($1): seal mismatch"; ok=0; }; }
	rm -rf "$t"
	[ "$ok" = 1 ] && echo "ok   e2e($1)"
	[ "$ok" = 1 ]
}
for sh in dash "busybox sh" bash; do
	set -- $sh; command -v "$1" >/dev/null || continue
	if [ "$1" = busybox ]; then
		bbw=$(mktemp -d); printf '#!/bin/sh\nexec busybox sh "$@"\n' >"$bbw/bbsh"; chmod +x "$bbw/bbsh"
		e2e "$bbw/bbsh" || fail=$((fail + 1)); rm -rf "$bbw"
	else
		e2e "$1" || fail=$((fail + 1))
	fi
done
[ "$fail" -eq 0 ] && echo "all tests passed"
[ "$fail" -eq 0 ]
