# @verb    ls
# @domain  files
# @accepts path
# @emits   path
# @opts    -a
# @usage   ls [path-ref | /abs/path]
# @summary Long directory (or file) listing; one path item per entry
# @example ls 6.2.path
# @example ls /tmp
# @parser  ls
d=${1:-.}
echo "#@bin ls"
echo "#@dir $d"
if [ -n "${OPT_a:-}" ]; then ls -lan "$d" 2>/dev/null || echo "#@unavailable ls $d"
else ls -ln "$d" 2>/dev/null || echo "#@unavailable ls $d"; fi
