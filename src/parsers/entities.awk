# entities.awk - numbering + generic entity extraction, run after every parser.
# In:  parser output, one item per line: type \t k=v \t ... [\t @kind=v ...]
# Out: S.N \t type \t k=v ... \t @kind=v ...   (deduplicated entities)
# Entities: ip (IPv4/IPv6), path (absolute), pid ([1234], pid=1234), user
# (user=/USER=/uid_name= fields). Parsers may add their own @ entities.
BEGIN { FS = "\t"; st = ENVIRON["TRAIL_STEP"]; n = 0 }

function add(k, v) {
	if (v == "" || (k SUBSEP v) in have) return
	# wildcard bind addresses are not pivotable indicators
	if (k == "ip" && (v == "0.0.0.0" || v == "::" || v ~ /^(0000:){7}0000$/)) return
	have[k SUBSEP v] = 1; ents = ents "\t@" k "=" v
}
function okv4(s,    a, i) {
	if (split(s, a, ".") != 4) return 0
	for (i = 1; i <= 4; i++) if (a[i] + 0 > 255 || length(a[i]) > 3) return 0
	return 1
}
function scan(s,    t, m, p) {
	t = s
	while (match(t, /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/)) {
		m = substr(t, RSTART, RLENGTH); t = substr(t, RSTART + RLENGTH)
		if (okv4(m)) add("ip", m)
	}
	t = s
	while (match(t, /[0-9A-Fa-f]*:[0-9A-Fa-f]*:[0-9A-Fa-f:.]*/)) {
		m = substr(t, RSTART, RLENGTH); t = substr(t, RSTART + RLENGTH)
		# require hex letters or "::" (reject clock times), reject MACs
		if (m ~ /::/ || m ~ /[A-Fa-f]/) if (m !~ /^[0-9A-Fa-f][0-9A-Fa-f](:[0-9A-Fa-f][0-9A-Fa-f])+$/ && length(m) > 2) add("ip", m)
	}
	t = " " s
	while (match(t, /[ =:'"(\[]\/[^ '"),;\]]+/)) {
		m = substr(t, RSTART + 1, RLENGTH - 1); t = substr(t, RSTART + RLENGTH)
		if (m != "/" && m !~ /^\/\//) add("path", m)
	}
	t = s
	while (match(t, /\[[0-9]+\]|pid[= ][0-9]+/)) {
		m = substr(t, RSTART, RLENGTH); t = substr(t, RSTART + RLENGTH)
		gsub(/[^0-9]/, "", m); add("pid", m)
	}
}

/^[ \t]*$/ { next }
{
	n++; ents = ""; split("", have); out = ""
	# parser-supplied entities first: they are authoritative, so S.N.pid is
	# the item's own pid, not a pid mentioned in its command line
	for (i = 2; i <= NF; i++) if (substr($i, 1, 1) == "@") { p = index($i, "="); add(substr($i, 2, p - 2), substr($i, p + 1)) }
	for (i = 2; i <= NF; i++) {
		p = index($i, "=")
		if (substr($i, 1, 1) == "@") continue
		out = out "\t" $i
		k = substr($i, 1, p - 1); v = substr($i, p + 1)
		if (k ~ /^_/) continue
		if (k == "user" || k == "USER" || k == "owner" || k == "uid_name") add("user", v)
		scan(v)
	}
	print st "." n "\t" $1 out ents
}
