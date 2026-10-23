# @verb    facts
# @domain  session
# @accepts none
# @emits   fact
# @usage   facts
# @summary Target facts: hostname, kernel, OS release, uid/id, ssh peer, clock (runs as step 0)
# @example facts
# @parser  facts
echo "#@bin sh"
echo "hostname $(uname -n 2>/dev/null)"
echo "kernel $(uname -srm 2>/dev/null)"
if [ -r /etc/os-release ]; then
	while IFS='=' read -r k v; do
		[ "$k" = PRETTY_NAME ] && { v=${v#\"}; echo "os ${v%\"}"; }
	done </etc/os-release
fi
echo "uid $(id -u 2>/dev/null)"
echo "id $(id 2>/dev/null)"
echo "ssh_connection ${SSH_CONNECTION:-}"
echo "target_utc $(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
echo "uptime $(cut -d' ' -f1 /proc/uptime 2>/dev/null)"
