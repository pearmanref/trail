# tree.awk - full proc dump + #@target -> ancestors and descendants, indented.
BEGIN { FS = "\t" }
/^#@target/ { t = $1; sub(/#@target /, "", t); tgt = t; next }
/^#@/ { next }
{ ord[++n] = $1; PP[$1] = $2; COMM[$1] = $3; CMD[$1] = $4 }
function indepth(p,  d) { d = 0; while ((p in PP) && (PP[p] in INC) && PP[p] != p && PP[p] + 0 > 0) { d++; p = PP[p] } return d }
END {
	# ancestors
	p = tgt; g = 0; while (p != "" && (p in PP) && g++ < 256) { INC[p] = 1; if (PP[p] + 0 <= 0) break; p = PP[p] }
	INC[tgt] = 1
	# descendants (fixpoint)
	do { ch = 0; for (i = 1; i <= n; i++) { q = ord[i]; if (!(q in INC) && (PP[q] in INC)) { INC[q] = 1; ch = 1 } } } while (ch)
	for (i = 1; i <= n; i++) {
		p = ord[i]; if (!(p in INC)) continue
		dep = indepth(p)
		ind = sprintf("%" (dep * 2) "s", "")
		star = (p == tgt ? "* " : "")
		cmd = (CMD[p] == "" ? "[" COMM[p] "]" : CMD[p])
		d = ind star p " " COMM[p] "  " cmd
		line = "pid\tpid=" p "\tppid=" PP[p] "\tcomm=" clean(COMM[p]) "\tdepth=" dep "\tcmd=" clean(CMD[p])
		line = line "\t_d=" clean(d) "\t@pid=" p
		print line
	}
}
