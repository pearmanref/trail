# @verb    hash
# @domain  files
# @accepts path
# @emits   md5 sha256
# @opts    --force
# @usage   hash <path-ref | /abs/path>
# @summary md5 + sha256 of a regular file (both: md5 for legacy IOC feeds, sha256 for integrity)
# @example hash 6.2.path
# @parser  hash
f=$1
echo "#@bin sh"
if readable_file "$f"; then
	if [ -f "$f" ] && [ ! -h "$f" ]; then
		h=$(hashf "$f"); echo "file $f"; echo "md5 ${h% *}"; echo "sha256 ${h#* }"
	else echo "#@skip $f: not a regular file"; fi
fi
