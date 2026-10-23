# @verb    cat
# @domain  files
# @accepts path
# @emits   line
# @opts    --force
# @usage   cat <path-ref | /abs/path>
# @summary Print a text file's contents as line items (guards devices/FIFOs/oversize)
# @example cat 6.2.path
# @parser  generic
f=$1
echo "#@bin cat"
if readable_file "$f"; then echo "#@file $f"; cat "$f" 2>/dev/null; fi
