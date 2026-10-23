# @verb    who-port
# @domain  network
# @accepts port
# @emits   pid ip
# @usage   who-port <port-ref | N>
# @summary Which process owns a given local port (filters the socket table)
# @example who-port 6.2.port
# @example who-port 4444
# @parser  net
echo "#@filter lport $1"
if [ -r /proc/net/tcp ] || [ -r /proc/net/tcp6 ]; then
	net_dump
else
	net_dump_ss
fi
