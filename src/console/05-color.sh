# shellcheck shell=sh
# 05-color.sh - console color. Color is a DISPLAY concern only: it is applied
# to the REPL prompt, messages, and list rendering, and NEVER written into the
# case dir or the reports (those stay plain ASCII so hashes and diffs are
# stable). The palette matches the dotfiles `hl` convention:
#   IPv4 red, hashes yellow, domains cyan, "known-bad"/convergence magenta.
#
# Resolution (color_init): --color always|never|auto (default auto). auto = on
# only when stdout is a TTY, NO_COLOR is unset, and TERM is not "dumb".
# https://no-color.org is honored: any NO_COLOR value disables color.

COLOR_MODE=auto        # set by --color
COLOR=''               # '' = off, 1 = on (resolved)

# SGR codes (semantic -> code). Kept in one place so a theme change is one edit.
# The reset (\033[0m) is emitted literally by c(); there is no C_RESET constant.
C_MAL='1;31'   C_SUS='0;33'   C_BEN='2'          # verdicts
C_IP='0;31'    C_HASH='0;33'  C_DOMAIN='0;36'    # entities (hl palette)
C_PATH='0;34'  C_PID='0;36'   C_USER='0;32'  C_PORT='0;35'
C_SELF='2'     C_CONV='0;35'  C_HEAD='1;36'  C_WARN='1;31'  C_DIM='2'

color_init() {
	case $COLOR_MODE in
	always) COLOR=1 ;;
	never) COLOR='' ;;
	*)
		if [ -t 1 ] && [ -z "${NO_COLOR+x}" ] && [ "${TERM:-dumb}" != dumb ]; then COLOR=1; else COLOR=''; fi ;;
	esac
}

# c CODE TEXT -> TEXT wrapped in SGR CODE (or TEXT unchanged when color is off)
c() { if [ -n "$COLOR" ]; then printf '\033[%sm%s\033[0m' "$1" "$2"; else printf '%s' "$2"; fi; }

# color codes for awk: emits "name=code" pairs, or blanks when off, so one
# -v COLORS="$(color_vars)" hands the whole palette to a display awk program.
# awk side: split(COLORS,_c,SUBSEP)... simpler: we pass individual -v below.
