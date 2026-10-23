# @verb    exe
# @domain  process
# @accepts pid
# @emits   path
# @opts    --force
# @usage   exe <pid-ref>
# @summary Resolve /proc/<pid>/exe, hash it (md5+sha256), file type, deleted flag
# @example exe 1.6
# @parser  exe
p=$1
echo "#@bin /proc"
echo "pid $p"
t=$(readlink "/proc/$p/exe" 2>/dev/null)
if [ -z "$t" ]; then echo "#@unavailable /proc/$p/exe (exited or no permission)"; exit 0; fi
echo "target $t"
case $t in *" (deleted)") echo "deleted 1" ;; *) echo "deleted 0" ;; esac
# /proc/<pid>/exe stays readable even when the on-disk file is unlinked
if [ -r "/proc/$p/exe" ]; then h=$(hashf "/proc/$p/exe"); echo "md5 ${h% *}"; echo "sha256 ${h#* }"; fi
command -v file >/dev/null 2>&1 && echo "filetype $(file -bL "/proc/$p/exe" 2>/dev/null)"
