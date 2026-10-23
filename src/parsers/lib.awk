# lib.awk - shared POSIX awk helpers (mawk / busybox awk compatible).
# Prepended to every parser and report program. No gawk extensions.

# iso(EPOCH) -> YYYY-MM-DDTHH:MM:SSZ (UTC) without strftime (not POSIX)
function iso(t,    d, s, z, era, doe, yoe, y, doy, mp, m, dd, h, mi, se) {
	t = int(t); d = int(t / 86400); s = t - d * 86400
	h = int(s / 3600); mi = int((s % 3600) / 60); se = s % 60
	z = d + 719468; era = int((z >= 0 ? z : z - 146096) / 146097)
	doe = z - era * 146097
	yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
	y = yoe + era * 400; doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100))
	mp = int((5 * doy + 2) / 153); dd = doy - int((153 * mp + 2) / 5) + 1
	m = mp + (mp < 10 ? 3 : -9); if (m <= 2) y++
	return sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", y, m, dd, h, mi, se)
}

function _ordinit(    i) { for (i = 1; i < 256; i++) _ORD[sprintf("%c", i)] = i; _ordok = 1 }

# js(S) -> JSON string literal. Control chars and bytes >= 0x80 are emitted
# as \u00XX (byte-preserving: decode the string as Latin-1 to get raw bytes).
function js(s,    o, i, c, n, b) {
	if (!_ordok) _ordinit()
	if (s !~ /[^ -~]/ && s !~ /["\\]/) return "\"" s "\""
	o = ""; n = length(s)
	for (i = 1; i <= n; i++) {
		c = substr(s, i, 1); b = _ORD[c]
		if (c == "\"") o = o "\\\""
		else if (c == "\\") o = o "\\\\"
		else if (b < 32 || b >= 127) o = o sprintf("\\u%04x", b)
		else o = o c
	}
	return "\"" o "\""
}

# ascii(S) -> printable ASCII only (report files are ASCII)
function ascii(s) { gsub(/\t/, " ", s); gsub(/[^ -~]/, "?", s); return s }

function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

# clean(S) -> safe for a TSV field (no tabs / CR / NL)
function clean(s) { gsub(/[\t\r\n]/, " ", s); return s }

# Item TSV line: id \t type \t k=v ... \t @entity=v ...
# fld(LINE, KEY) -> first value of KEY (use "@path" for entities)
function fld(line, key,    n, a, i, p) {
	n = split(line, a, "\t")
	for (i = 3; i <= n; i++) {
		p = index(a[i], "=")
		if (p && substr(a[i], 1, p - 1) == key) return substr(a[i], p + 1)
	}
	return ""
}

# wrap(TEXT, INDENT, WIDTH) -> lines joined by \n, each <= WIDTH. Breaks at
# the last space that fits (internal spacing/alignment is preserved);
# continuation lines get INDENT spaces; unbreakable runs are hard-split.
function wrap(text, ind, width,    out, pad, room, cut, i) {
	text = ascii(text); pad = sprintf("%" ind "s", ""); out = ""
	sub(/ +$/, "", text)
	while (length(text) > width) {
		cut = 0
		for (i = width + 1; i > ind + 1; i--) if (substr(text, i, 1) == " ") { cut = i; break }
		if (cut) { out = out substr(text, 1, cut - 1) "\n"; text = substr(text, cut + 1) }
		else { out = out substr(text, 1, width) "\n"; text = substr(text, width + 1) }
		sub(/^ +/, "", text); text = pad text
	}
	return out text
}

# ---- convergence (shared by console display and reports) -----------------
# idx_add(KIND, VAL, ID, STEP): record a sighting. Call in step order.
function idx_add(k, v, id, st) { _IDX[k SUBSEP v] = _IDX[k SUBSEP v] " " id; _IDXST[id] = st }

# conv(KIND, VAL, ID, STEP, VERB) -> "1.6 MAL, 3.1" of earlier sightings, or "".
# Noise rules: ignore sightings from earlier runs of the same verb (re-running
# ps would flag every pid), and ignore `user` entities unless an earlier
# sighting is marked MAL/SUS (root is everywhere).
# Needs: STEPVERB[step], MARKV[ref] (MAL/SUS/BEN).
function conv(k, v, id, st, verb,    n, a, i, o, cnt, hot, s2, m) {
	n = split(_IDX[k SUBSEP v], a, " "); o = ""; cnt = 0; hot = 0
	for (i = 1; i <= n; i++) {
		if (a[i] == id) continue
		s2 = _IDXST[a[i]]
		if (s2 + 0 >= st + 0) continue
		if (STEPVERB[s2] == verb) continue
		m = MARKV[a[i]]; if (m == "MAL" || m == "SUS") hot = 1
		cnt++
		if (cnt <= 4) o = o (o == "" ? "" : ", ") a[i] (m != "" ? " " m : "")
	}
	if (cnt == 0) return ""
	if (k == "user" && !hot) return ""
	if (cnt > 4) o = o ", +" (cnt - 4)
	return o
}
