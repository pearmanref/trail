# @verb    file
# @domain  files
# @accepts path
# @emits   path
# @usage   file <path-ref | /abs/path>
# @summary libmagic type of a path (file -b)
# @example file 6.2.path
# @parser  file
f=$1
if command -v file >/dev/null 2>&1; then
	echo "#@bin file"; echo "path $f"; echo "type $(file -b "$f" 2>/dev/null)"
else echo "#@unavailable file"; fi
