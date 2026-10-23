#!/bin/sh
# trail - interactive pivot console for Linux host investigation (dev entry).
# Copyright 2026 pearmanref. Licensed under the Apache License, Version 2.0.
# Defensive / authorized use only.
#
# Dev mode: sources modules from src/. build.sh concatenates the same modules
# into dist/trail and replaces the _src* functions below with embedded copies.

TRAIL_ROOT=$(cd "$(dirname "$0")/../.." && pwd) || exit 2
if [ -z "${TRAIL_VERSION:-}" ]; then
	TRAIL_VERSION=$(git -C "$TRAIL_ROOT" describe --tags --always --dirty 2>/dev/null) || TRAIL_VERSION=''
	TRAIL_VERSION="dev${TRAIL_VERSION:+ ($TRAIL_VERSION)}"
fi

# _src RELPATH -> contents of an embedded source file
_src() { cat "$TRAIL_ROOT/src/$1"; }
# _registry -> verb registry TSV generated from metadata headers
_registry() {
	awk "$(cat "$TRAIL_ROOT/src/console/meta.awk")" \
		"$TRAIL_ROOT"/src/console/*.sh "$TRAIL_ROOT"/src/collectors/*.sh
}

for _m in "$TRAIL_ROOT"/src/console/[0-9][0-9]-*.sh; do
	# shellcheck source=/dev/null
	. "$_m"
done
unset _m

trail_main "$@"
