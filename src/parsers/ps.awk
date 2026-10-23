# ps.awk - /proc records (or ps(1) fallback) -> pid items.
# SELF: the console's own process subtree (local) or the ssh session chain
# serving our channel (ssh) is tagged and hidden unless -a.
BEGIN {
	fre = ENVIRON["OPT_f"]; fu = ENVIRON["OPT_u"]; fa = (ENVIRON["OPT_a"] != "")
	clk = 100; np = 0
}
/^#@clk / { clk = $2 + 0; if (clk <= 0) clk = 100; next }
/^#@btime / { btime = $2 + 0; next }
/^#@user / { UN[$2] = $3; next }
/^#@selfsh / { selfsh = $2; next }
/^#@trailpid / { trailpid = $2; next }
/^#@bin ps/ { fallback = 1; next }
/^#@proc / { cur = $2; P[++np] = cur; next }
/^#@/ { next }
fallback {
	if ($1 !~ /^[0-9]+$/) next
	cur = $1; P[++np] = cur; PP[cur] = $2
	if ($3 ~ /^[0-9]+$/) { UID_[cur] = $3; UN[$3] = $4; a = 5 } else { USR[cur] = $3; a = 4 }
	s = $0; for (i = 1; i < a; i++) sub(/^[ \t]*[^ \t]+/, "", s)
	CMD[cur] = trim(s); split(CMD[cur], w, " "); COMM[cur] = w[1]
	next
}
/^stat / {
	s = substr($0, 6); lp = index(s, "("); rp = 0
	for (i = length(s); i > 0; i--) if (substr(s, i, 1) == ")") { rp = i; break }
	COMM[cur] = substr(s, lp + 1, rp - lp - 1)
	split(substr(s, rp + 2), r, " ")
	ST[cur] = r[1]; PP[cur] = r[2]; STK[cur] = r[20]
	next
}
/^uid / { UID_[cur] = $2; next }
/^cmd / { CMD[cur] = trim(clean(substr($0, 5))); next }
/^exe / { EXE[cur] = substr($0, 5); next }

function isself(p) { return (p in SELF) }
END {
	# --- SELF roots
	if (trailpid != "") SELF[trailpid] = 1
	else if (selfsh != "") {
		p = selfsh; guard = 0
		while (p != "" && (p in PP) && guard++ < 64) {
			if (COMM[p] !~ /^(sh|dash|ash|bash|busybox|timeout|sshd|sshd-session|sshd-auth)$/) break
			if (PP[p] + 0 <= 1) break
			SELF[p] = 1; p = PP[p]
		}
	}
	do { ch = 0; for (i = 1; i <= np; i++) { p = P[i]; if (!(p in SELF) && (PP[p] in SELF)) { SELF[p] = 1; ch = 1 } } } while (ch)

	# --- numeric sort of pids (insertion sort; n is a few hundred)
	for (i = 2; i <= np; i++) { k = P[i]; j = i - 1; while (j > 0 && P[j] + 0 > k + 0) { P[j + 1] = P[j]; j-- } P[j + 1] = k }

	for (i = 1; i <= np; i++) {
		p = P[i]; if (p == prev) continue; prev = p
		sf = isself(p)
		if (sf && !fa) continue
		u = (USR[p] != "" ? USR[p] : ((UID_[p] in UN) ? UN[UID_[p]] : UID_[p]))
		if (fu != "" && u != fu && UID_[p] != fu) continue
		e = EXE[p]; del = 0
		if (e ~ / \(deleted\)$/) { del = 1; sub(/ \(deleted\)$/, "", e) }
		c = CMD[p]; shown = (c == "" ? "[" COMM[p] "]" : c)
		if (fre != "" && shown !~ fre && COMM[p] !~ fre && e !~ fre) continue
		start = (btime && STK[p] != "") ? iso(btime + STK[p] / clk) : ""
		line = "pid\tpid=" p "\tppid=" PP[p] "\tuid=" UID_[p] "\tuser=" u "\tstate=" ST[p]
		line = line "\tstart=" start "\tcomm=" clean(COMM[p]) "\texe=" clean(e)
		if (del) line = line "\tdeleted=1"
		if (sf) line = line "\tself=1"
		line = line "\tcmd=" c
		d = sprintf("%-7s %-7s %-9s %s %s%s%s", p, PP[p], substr(u, 1, 9), \
			(start == "" ? "-" : substr(start, 6, 11)), shown, (del ? "  (exe deleted)" : ""), (sf ? "  [SELF]" : ""))
		line = line "\t_d=" clean(d) "\t@pid=" p
		if (u != "") line = line "\t@user=" u
		if (e != "") line = line "\t@path=" clean(e)
		print line
	}
}
