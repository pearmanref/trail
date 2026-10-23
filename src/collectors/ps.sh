# @verb    ps
# @domain  process
# @accepts none
# @emits   pid
# @opts    -f:re -u:user -a
# @usage   ps [-f re] [-u user] [-a]
# @summary Process list read from /proc (stat, status, cmdline, exe); ps(1) fallback
# @example ps
# @example ps -u www-data
# @example ps -f 'nc|socat|/tmp/'
# @parser  ps
# Collector contract: emit raw text only. No parsing, no state, no writes.
# Lines starting "#@" are metadata for the parser. -f/-u/-a filter analyst-side.
if [ -r /proc/1/stat ]; then
	echo "#@bin /proc"
	echo "#@clk $(getconf CLK_TCK 2>/dev/null || echo 100)"
	while read -r k v _; do [ "$k" = btime ] && echo "#@btime $v"; done </proc/stat
	{ while IFS=: read -r n _ u _; do echo "#@user $u $n"; done </etc/passwd; } 2>/dev/null
	for d in /proc/[0-9]*; do
		[ -r "$d/stat" ] || continue
		{
			s=$(cat "$d/stat") || continue
			echo "#@proc ${d#/proc/}"
			printf 'stat %s\n' "$s"
			while read -r k a _; do [ "$k" = Uid: ] && echo "uid $a"; done <"$d/status"
			printf 'cmd %s\n' "$(tr '\000' ' ' <"$d/cmdline")"
			printf 'exe %s\n' "$(readlink "$d/exe")"
		} 2>/dev/null
	done
else
	echo "#@bin ps"
	ps -eo pid=,ppid=,uid=,user=,args= 2>/dev/null || ps -o pid,ppid,user,args
fi
