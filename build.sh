#!/bin/sh
# shellcheck disable=SC2016  # literal $1/$@ are written into the bundle on purpose
# build.sh - bundle src/ into dist/trail: one self-contained POSIX sh file.
# Collectors, parsers and report awk are embedded as quoted heredocs; the verb
# registry is generated from the @verb headers at build time.
# Version = nearest git tag + short hash, e.g. "v0.1.0 (a1b2c3d)".
set -eu
cd "$(dirname "$0")"
LC_ALL=C; export LC_ALL

tag=$(git describe --tags --abbrev=0 2>/dev/null || echo v0.0.0)
hash=$(git rev-parse --short HEAD 2>/dev/null || echo nogit)
if [ "$hash" != nogit ] && ! git diff --quiet HEAD -- src build.sh 2>/dev/null; then hash="$hash-dirty"; fi
version="$tag ($hash)"
EOF_MARK=__TRAIL_EOF__

if grep -rqx "$EOF_MARK" src; then echo "build: a source file contains $EOF_MARK" >&2; exit 1; fi

mkdir -p dist
tmp=dist/.trail.tmp
{
	printf '#!/bin/sh\n'
	printf '# trail %s - interactive pivot console for Linux host investigation\n' "$version"
	printf '# Copyright 2026 pearmanref. Licensed under the Apache License, Version 2.0.\n'
	printf '# Defensive / authorized use only. Built by build.sh - do not edit; edit src/.\n'
	printf "TRAIL_VERSION='%s'\n" "$version"
	printf '_src() {\n\tcase $1 in\n'
	for f in src/collectors/*.sh src/parsers/*.awk src/console/*.awk; do
		printf "\t%s)\n\t\tcat <<'%s'\n" "${f#src/}" "$EOF_MARK"
		cat "$f"
		printf '%s\n\t\t;;\n' "$EOF_MARK"
	done
	printf '\t*) echo "trail: missing embedded source: $1" >&2; return 1 ;;\n\tesac\n}\n'
	printf "_registry() {\n\tcat <<'%s'\n" "$EOF_MARK"
	awk -f src/console/meta.awk src/console/*.sh src/collectors/*.sh
	printf '%s\n}\n' "$EOF_MARK"
	for m in src/console/[0-9][0-9]-*.sh; do
		printf '\n# ---- %s\n' "${m#src/}"
		grep -v '^# shellcheck shell=sh$' "$m"
	done
	printf '\ntrail_main "$@"\n'
} >"$tmp"
chmod 755 "$tmp"
mv "$tmp" dist/trail
echo "built dist/trail ($version)"
