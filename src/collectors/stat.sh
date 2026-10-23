# @verb    stat
# @domain  files
# @accepts path
# @emits   path
# @opts    --force
# @usage   stat <path-ref | /abs/path>
# @summary stat() a path; hash regular files (md5+sha256) under the size cap
# @example stat 6.2.path
# @parser  stat
f=$1
echo "#@bin stat"
if [ ! -e "$f" ] && [ ! -h "$f" ]; then echo "#@unavailable $f (not found)"; exit 0; fi
if command -v stat >/dev/null 2>&1; then
	stat -c 'mode %a %A
uid %u %U
gid %g %G
size %s
mtime %Y
ctime %Z
atime %X
ftype %F
link %N' "$f" 2>/dev/null
else
	echo "lsline $(ls -ldn "$f" 2>/dev/null)"
fi
if [ -f "$f" ] && [ ! -h "$f" ]; then
	if readable_file "$f"; then h=$(hashf "$f"); echo "md5 ${h% *}"; echo "sha256 ${h#* }"; fi
fi
