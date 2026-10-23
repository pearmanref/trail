# net.awk - /proc/net/{tcp,udp}{,6} (or ss fallback) -> socket items, joined to
# the owning pid via the inode->pid map. The fd map is emitted AFTER the socket
# tables, so sockets are buffered and emitted in END once the map is complete.
# POSIX awk: hex is decoded by hand (no strtonum), so mawk/busybox awk work.
BEGIN {
	ST["01"] = "ESTAB"; ST["02"] = "SYN_SENT"; ST["03"] = "SYN_RECV"
	ST["04"] = "FIN_WAIT1"; ST["05"] = "FIN_WAIT2"; ST["06"] = "TIME_WAIT"
	ST["07"] = "CLOSE"; ST["08"] = "CLOSE_WAIT"; ST["09"] = "LAST_ACK"
	ST["0A"] = "LISTEN"; ST["0B"] = "CLOSING"
	fport = ""; ns = 0
}
function hx(ch,  p) { p = index("0123456789abcdef", tolower(ch)); return p - 1 }
function h2i(s,  i, r) { r = 0; for (i = 1; i <= length(s); i++) r = r * 16 + hx(substr(s, i, 1)); return r }
function v4(a) { return h2i(substr(a, 7, 2)) "." h2i(substr(a, 5, 2)) "." h2i(substr(a, 3, 2)) "." h2i(substr(a, 1, 2)) }
function v6(a,  w, s, out, i, r) {
	out = ""
	for (w = 0; w < 4; w++) { s = substr(a, w * 8 + 1, 8); out = out substr(s, 7, 2) substr(s, 5, 2) substr(s, 3, 2) substr(s, 1, 2) }
	r = ""; for (i = 0; i < 8; i++) r = r (i ? ":" : "") tolower(substr(out, i * 4 + 1, 4))
	return r
}
function ipof(h, proto,  a) { a = h; sub(/:.*/, "", a); return (proto ~ /6$/) ? v6(a) : v4(a) }
function portof(h,  p) { p = h; sub(/.*:/, "", p); return h2i(p) }

/^#@filter lport / { fport = $3; next }
/^#@proto / { proto = $2; mode = "proc"; next }
/^#@ss/ { mode = "ss"; next }
/^#@fdmap/ { mode = "fd"; next }
/^#@bin / || /^#@unavailable/ || /^#@skip/ { next }

mode == "fd" { INO2PID[$1] = $2; INO2COMM[$1] = $3; next }

mode == "proc" {
	if ($1 !~ /^[0-9]+:$/) next           # skip header
	ns++
	SPROTO[ns] = proto; SST[ns] = (ST[$4] != "" ? ST[$4] : $4)
	SLA[ns] = ipof($2, proto); SLP[ns] = portof($2)
	SRA[ns] = ipof($3, proto); SRP[ns] = portof($3)
	SINO[ns] = $10; SPID[ns] = ""; SCOMM[ns] = ""
	next
}

# ss -H: Netid State Recv-Q Send-Q Local:Port Peer:Port [users:(("comm",pid=N,..))]
mode == "ss" {
	if (NF < 6) next
	ns++
	SPROTO[ns] = $1; SST[ns] = $2
	lp = $5; SLP[ns] = lp; sub(/.*:/, "", SLP[ns]); SLA[ns] = lp; sub(/:[^:]*$/, "", SLA[ns])
	rp = $6; SRP[ns] = rp; sub(/.*:/, "", SRP[ns]); SRA[ns] = rp; sub(/:[^:]*$/, "", SRA[ns])
	SINO[ns] = ""
	SPID[ns] = (match($0, /pid=[0-9]+/) ? substr($0, RSTART + 4, RLENGTH - 4) : "")
	SCOMM[ns] = (match($0, /\(\("[^"]+"/) ? substr($0, RSTART + 3, RLENGTH - 3) : ""); sub(/"$/, "", SCOMM[ns])
	next
}

END {
	for (i = 1; i <= ns; i++) {
		pid = SPID[i]; comm = SCOMM[i]
		if (pid == "" && SINO[i] != "" && (SINO[i] in INO2PID)) { pid = INO2PID[SINO[i]]; comm = INO2COMM[SINO[i]] }
		emit(SPROTO[i], SST[i], SLA[i], SLP[i], SRA[i], SRP[i], pid, comm)
	}
}
function emit(proto, st, la, lp, ra, rp, pid, comm,  d, line, listen) {
	if (fport != "" && lp != fport) return
	listen = (st == "LISTEN" || ra == "0.0.0.0" || ra == "::" || ra == "0" || ra == "")
	d = sprintf("%-5s %-10s %-24s %-24s %s", proto, st, la ":" lp, (listen ? "*:*" : ra ":" rp), (pid != "" ? pid "/" comm : "-"))
	line = "socket\tproto=" proto "\tstate=" st "\tladdr=" clean(la) "\tlport=" lp "\traddr=" clean(ra) "\trport=" rp
	if (pid != "") line = line "\tpid=" pid "\tcomm=" clean(comm)
	line = line "\t_d=" clean(d) "\t@port=" lp
	if (pid != "") line = line "\t@pid=" pid
	if (!listen && ra != "" && ra != "0.0.0.0" && ra != "::") line = line "\t@ip=" ra
	print line
}
