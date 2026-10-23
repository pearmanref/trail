# _prelude.sh - target-side helpers emitted before every collector snippet.
# POSIX sh only; no state, no writes outside the hasher reading files. Not a
# verb (no @verb header), so it never appears in the registry.

# hashf FILE -> "<md5> <sha256>" on one line; "unavailable" for a missing
# hasher. Tries coreutils, then busybox, then openssl. Never fails the step.
hashf() {
	hf_f=$1 hf_m=unavailable hf_s=unavailable
	if command -v md5sum >/dev/null 2>&1; then hf_m=$(md5sum <"$hf_f" 2>/dev/null | cut -d' ' -f1)
	elif command -v busybox >/dev/null 2>&1; then hf_m=$(busybox md5sum <"$hf_f" 2>/dev/null | cut -d' ' -f1)
	elif command -v openssl >/dev/null 2>&1; then hf_m=$(openssl dgst -md5 <"$hf_f" 2>/dev/null | sed 's/.* //'); fi
	if command -v sha256sum >/dev/null 2>&1; then hf_s=$(sha256sum <"$hf_f" 2>/dev/null | cut -d' ' -f1)
	elif command -v busybox >/dev/null 2>&1; then hf_s=$(busybox sha256sum <"$hf_f" 2>/dev/null | cut -d' ' -f1)
	elif command -v openssl >/dev/null 2>&1; then hf_s=$(openssl dgst -sha256 <"$hf_f" 2>/dev/null | sed 's/.* //'); fi
	printf '%s %s' "${hf_m:-unavailable}" "${hf_s:-unavailable}"
}

# readable_file FILE -> 0 only for a regular file under the size cap, unless
# FORCE=1. Refuses char/block devices, FIFOs, sockets, and oversize files, and
# echoes a "#@skip" line explaining why. Guards cat/strings/log so a snippet
# can never hang on /proc/kcore or a named pipe.
readable_file() {
	rf_f=$1
	if [ -c "$rf_f" ] || [ -b "$rf_f" ]; then echo "#@skip $rf_f: device file (use --force)"; [ -n "$FORCE" ] || return 1; fi
	if [ -p "$rf_f" ]; then echo "#@skip $rf_f: FIFO (use --force)"; [ -n "$FORCE" ] || return 1; fi
	if [ -S "$rf_f" ]; then echo "#@skip $rf_f: socket"; return 1; fi
	if [ ! -e "$rf_f" ]; then echo "#@skip $rf_f: not found"; return 1; fi
	if [ ! -r "$rf_f" ]; then echo "#@skip $rf_f: not readable (permission)"; return 1; fi
	rf_sz=$(wc -c <"$rf_f" 2>/dev/null || echo 0)
	if [ -z "$FORCE" ] && [ "${rf_sz:-0}" -gt "${SIZECAP:-10485760}" ]; then
		echo "#@skip $rf_f: ${rf_sz} bytes over cap ${SIZECAP} (use --force)"; return 1
	fi
	return 0
}

# net_dump - raw socket tables from /proc/net plus an inode->pid->comm map, so
# the analyst-side parser can join sockets to processes without any parsing on
# the target. Used by `net` and `who-port`.
net_dump() {
	echo "#@bin /proc"
	for nd_p in tcp tcp6 udp udp6; do
		[ -r "/proc/net/$nd_p" ] || continue
		echo "#@proto $nd_p"
		cat "/proc/net/$nd_p" 2>/dev/null
	done
	echo "#@fdmap"
	# inode -> pid, from socket fd symlinks; comm alongside for display
	for nd_d in /proc/[0-9]*; do
		nd_pid=${nd_d#/proc/}
		nd_comm=$(cat "$nd_d/comm" 2>/dev/null) || continue
		for nd_fd in "$nd_d"/fd/*; do
			nd_l=$(readlink "$nd_fd" 2>/dev/null) || continue
			case $nd_l in
			socket:\[*\]) nd_i=${nd_l#socket:[}; nd_i=${nd_i%]}; echo "$nd_i $nd_pid $nd_comm" ;;
			esac
		done
	done 2>/dev/null
}
# ss fallback when /proc/net is unreadable (rare; some containers)
net_dump_ss() {
	if command -v ss >/dev/null 2>&1; then
		echo "#@bin ss"
		echo "#@ss"
		ss -tulpnH 2>/dev/null
		ss -tunpH state established 2>/dev/null
	else echo "#@unavailable ss"; fi
}

# emit_meta emits #@bin for the data source actually used by a collector.
