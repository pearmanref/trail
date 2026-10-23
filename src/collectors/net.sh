# @verb    net
# @domain  network
# @accepts none
# @emits   ip port pid
# @usage   net
# @summary Listening + established sockets from /proc/net, joined to owning PID (ss fallback)
# @example net
# @parser  net
if [ -r /proc/net/tcp ] || [ -r /proc/net/tcp6 ]; then
	net_dump
else
	net_dump_ss
fi
