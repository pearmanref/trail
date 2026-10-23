# @verb    tree
# @domain  process
# @accepts pid
# @emits   pid
# @usage   tree <pid-ref>
# @summary Ancestors and descendants of a pid, indented (parent/child context)
# @example tree 1.6
# @parser  tree
echo "#@bin /proc"
echo "#@target $1"
for d in /proc/[0-9]*; do
	pid=${d#/proc/}
	[ -r "$d/stat" ] || continue
	ppid=$(sed -n 's/^PPid:[[:space:]]*//p' "$d/status" 2>/dev/null)
	comm=$(cat "$d/comm" 2>/dev/null)
	cmd=$(tr '\000' ' ' <"$d/cmdline" 2>/dev/null)
	printf '%s\t%s\t%s\t%s\n' "$pid" "${ppid:-0}" "${comm:-?}" "$cmd"
done 2>/dev/null
