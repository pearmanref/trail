# report.awk - all reports from the case dir, in one pass, deterministically.
# Inputs (in this order): session.tsv steps.tsv marks.log notes.log
#                         entities.idx steps/NNNN.items...
# -v D=<reports dir> -v SJ=<session.json path>
# Never iterate with `for (k in A)` when output order matters (awk hash order
# is unspecified); everything is walked by insertion index.
BEGIN { FS = "\t"; W = 78; HR = sprintf("%78s", ""); gsub(/ /, "-", HR); HE = HR; gsub(/-/, "=", HE) }

FILENAME ~ /session\.tsv$/ { SE[$1] = $2; SK[++nsk] = $1; next }
FILENAME ~ /steps\.tsv$/ {
	ns++; SN[ns] = $1; s = $1
	SPAR[s] = $2; STS[s] = $3; SVERB[s] = $4; SARGS[s] = $5; SCOL[s] = $6; SBIN[s] = $7
	SMD5[s] = $8; SSHA[s] = $9; SRC[s] = $10; SNI[s] = $11; SDUR[s] = $12; SSTAT[s] = $13
	STEPVERB[s] = $4; next
}
FILENAME ~ /marks\.log$/ {
	nm++; MTS[nm] = $1; MACT[nm] = $2; MREF[nm] = $3; MV[nm] = toupper($4); MATT[nm] = $5; MRS[nm] = $6; MENT[nm] = $7
	if ($2 == "mark") { EFF[$3] = nm; MARKV[$3] = toupper($4) } else { delete EFF[$3]; delete MARKV[$3] }
	next
}
FILENAME ~ /notes\.log$/ { nn++; NTS[nn] = $1; NST[nn] = $2; NREF[nn] = $3; NTX[nn] = $4; next }
FILENAME ~ /entities\.idx$/ {
	idx_add($1, $2, $3, $4); kv = $1 SUBSEP $2; t = STS[$4]
	if (!(kv in FSEEN) || t < FSEEN[kv]) FSEEN[kv] = t
	if (!(kv in LSEEN) || t > LSEEN[kv]) LSEEN[kv] = t
	next
}
{ s = $1; sub(/\..*/, "", s); IT[$1] = $0; ITN[s]++; ITL[s, ITN[s]] = $1; nitems++; next }

# ---------------------------------------------------------------- helpers
function out(f, s) { print s > (D "/" f) }
function stepname(s) { return "[" s "] " SVERB[s] (SARGS[s] != "" ? " " SARGS[s] : "") }
function refstep(r,    s) { s = r; sub(/^s/, "", s); sub(/\..*/, "", s); return s }

# chain(REF): sets CH_TXT (human path), CH_N / CH[i] (refs root->leaf, for
# JSON path[]), CH_SN / CH_S[i] (steps on the path); marks KEEP[step].
function chain(ref,    s, cur, txt, n, tmp, i) {
	n = 0; s = refstep(ref); cur = (ref ~ /^s/ ? "" : ref)
	txt = cur; if (cur != "") tmp[++n] = cur
	CH_SN = 0
	while (s != "") {
		KEEP[s] = 1; CH_S[++CH_SN] = s
		txt = stepname(s) (txt != "" ? " > " txt : "")
		tmp[++n] = "s" s
		if (SPAR[s] == "root" || SPAR[s] == "") break
		txt = SPAR[s] " > " txt; tmp[++n] = SPAR[s]; s = refstep(SPAR[s])
	}
	CH_TXT = "root > " txt; CH_N = n
	for (i = 1; i <= n; i++) CH[i] = tmp[n - i + 1]
}

function ents_json(line,    n, a, i, p, k, v, ks, nk, o, j, x) {
	n = split(line, a, "\t"); nk = 0
	for (i = 3; i <= n; i++) if (substr(a[i], 1, 1) == "@") {
		p = index(a[i], "="); k = substr(a[i], 2, p - 2); v = substr(a[i], p + 1)
		if (!(k in ks)) { ks[k] = ++nk; KO[nk] = k; KV[nk] = "" }
		j = ks[k]; KV[j] = KV[j] (KV[j] == "" ? "" : ",") js(v)
	}
	o = "{"; for (x = 1; x <= nk; x++) o = o (x > 1 ? "," : "") js(KO[x]) ":[" KV[x] "]"
	return o "}"
}
function fields_json(line,    n, a, i, p, o, c) {
	n = split(line, a, "\t"); o = "{"; c = 0
	for (i = 3; i <= n; i++) if (substr(a[i], 1, 1) != "@" && substr(a[i], 1, 1) != "_") {
		p = index(a[i], "="); o = o (c++ ? "," : "") js(substr(a[i], 1, p - 1)) ":" js(substr(a[i], p + 1))
	}
	return o "}"
}
function arr_json(csv,    n, a, i, o) {
	if (csv == "") return "[]"
	n = split(csv, a, ","); o = "["; for (i = 1; i <= n; i++) o = o (i > 1 ? "," : "") js(a[i]); return o "]"
}
# flags for one item (G = glyph) -> lines joined by \n, or ""
function flags(id, G,    s, n, a, i, p, k, v, c, o) {
	s = refstep(id); n = split(IT[id], a, "\t"); o = ""
	for (i = 3; i <= n; i++) if (substr(a[i], 1, 1) == "@") {
		p = index(a[i], "="); k = substr(a[i], 2, p - 2); v = substr(a[i], p + 1)
		c = conv(k, v, id, s, STEPVERB[s])
		if (c != "") o = o (o == "" ? "" : "\n") G " " k "=" v " seen: " c
	}
	return o
}
function header(f, title,    priv) {
	priv = (SE["target_uid"] == "0" ? "root" : "NON-ROOT (uid " SE["target_uid"] ") - visibility limited")
	out(f, title); out(f, HE)
	out(f, wrap("Case:      " SE["case_id"], 11, W))
	out(f, wrap("Target:    " SE["target_host"] " (" SE["target_spec"] (SE["jump"] != "" ? " via " SE["jump"] : "") ")", 11, W))
	out(f, wrap("OS:        " SE["target_os"] " / " SE["target_kernel"], 11, W))
	out(f, wrap("Tool:      " SE["tool_version"] "   schema " SE["schema"], 11, W))
	out(f, wrap("Mode:      " SE["mode"] "   Privilege: " priv, 11, W))
	out(f, wrap("Self:      console pid " SE["console_pid"] (SE["self_src"] != "" ? "   ssh peer " SE["self_src"] : "") (SE["bin_dir"] != "" ? "   --bin " SE["bin_dir"] : ""), 11, W))
	out(f, wrap("Window:    " SE["start"] " - " (SE["end"] != "" ? SE["end"] : "(in progress)") " UTC", 11, W))
	out(f, wrap("Totals:    steps " ns ", items " nitems ", marks MAL " CNT["MAL"] + 0 " SUS " CNT["SUS"] + 0 " BEN " CNT["BEN"] + 0 ", notes " nn + 0, 11, W))
	out(f, HE)
}
function footer(f) {
	out(f, ""); out(f, HR)
	out(f, wrap("ATT&CK(R) (c) The MITRE Corporation. Technique IDs are analyst-assigned and validated by format only. Defensive / authorized use only.", 0, W))
}

END {
	# effective marks, in mark order
	for (i = 1; i <= nm; i++) if (MACT[i] == "mark" && EFF[MREF[i]] == i) { ne++; E[ne] = i; CNT[MV[i]]++ }

	# ------------------------------------------------------ session.json
	o = "{"; for (i = 1; i <= nsk; i++) o = o (i > 1 ? "," : "") js(SK[i]) ":" js(SE[SK[i]]); print o "}" > SJ

	# ------------------------------------------------- full-analysis-log
	F = "full-analysis-log.txt"
	header(F, "TRAIL FULL ANALYSIS LOG")
	for (i = 1; i <= ns; i++) {
		s = SN[i]; out(F, "")
		out(F, wrap(sprintf("[%04d] %s  %s", s, STS[s], SVERB[s] (SARGS[s] != "" ? " " SARGS[s] : "")), 7, W))
		out(F, wrap("  parent: " SPAR[s] "   collector: " SCOL[s] "   binary: " SBIN[s] "   status: " SSTAT[s] " rc=" SRC[s] " dur=" SDUR[s] "s", 4, W))
		out(F, "  raw md5:    " SMD5[s]); out(F, "  raw sha256: " SSHA[s])
		out(F, "  items (" ITN[s] + 0 "):")
		for (j = 1; j <= ITN[s]; j++) {
			id = ITL[s, j]; split(IT[id], a, "\t")
			m = (MARKV[id] != "" ? " [" MARKV[id] "]" : "")
			out(F, wrap(sprintf("    %-7s %-6s %s%s", id, a[2], fld(IT[id], "_d"), m), 19, W))
			fl = flags(id, "!"); if (fl != "") { nf = split(fl, fa, "\n"); for (k = 1; k <= nf; k++) out(F, wrap("            " fa[k], 14, W)) }
		}
		hm = 0
		for (k = 1; k <= nm; k++) if (refstep(MREF[k]) == s) {
			if (!hm++) out(F, "  marks:")
			out(F, wrap("    " MTS[k] " " MACT[k] " " MREF[k] (MV[k] != "" ? " " MV[k] : "") (MATT[k] != "" ? " [" MATT[k] "]" : "") (MENT[k] != "" ? " (" MENT[k] ")" : "") (MRS[k] != "" ? " - " MRS[k] : ""), 8, W))
		}
		hn = 0
		for (k = 1; k <= nn; k++) if ((NREF[k] != "" && refstep(NREF[k]) == s) || (NREF[k] == "" && NST[k] == s)) {
			if (!hn++) out(F, "  notes:")
			out(F, wrap("    " NTS[k] (NREF[k] != "" ? " " NREF[k] : "") " - " NTX[k], 8, W))
		}
		out(F, HR)
	}
	footer(F)

	# ------------------------------------------------------- steps.jsonl
	SJL = "steps.jsonl"; printf "" > (D "/" SJL)
	for (i = 1; i <= ns; i++) {
		s = SN[i]
		o = "{\"schema\":" js(SE["schema"]) ",\"case_id\":" js(SE["case_id"]) ",\"step\":" s + 0 ",\"parent\":" js(SPAR[s])
		o = o ",\"ts\":" js(STS[s]) ",\"verb\":" js(SVERB[s]) ",\"args\":" js(SARGS[s]) ",\"collector\":" js(SCOL[s])
		o = o ",\"binary\":" js(SBIN[s]) ",\"raw_md5\":" js(SMD5[s]) ",\"raw_sha256\":" js(SSHA[s])
		o = o ",\"status\":" js(SSTAT[s]) ",\"rc\":" SRC[s] + 0 ",\"items\":["
		fl_all = ""
		for (j = 1; j <= ITN[s]; j++) {
			id = ITL[s, j]; split(IT[id], a, "\t")
			o = o (j > 1 ? "," : "") "{\"id\":" js(id) ",\"type\":" js(a[2]) ",\"fields\":" fields_json(IT[id]) ",\"entities\":" ents_json(IT[id]) "}"
			fl = flags(id, id); if (fl != "") { nf = split(fl, fa, "\n"); for (k = 1; k <= nf; k++) fl_all = fl_all (fl_all == "" ? "" : ",") js(fa[k]) }
		}
		print o "],\"flags\":[" fl_all "]}" > (D "/" SJL)
	}

	# ---------------------------------------------- findings (txt + jsonl)
	FR = "findings-report.txt"; FJ = "findings.jsonl"; printf "" > (D "/" FJ)
	nfind = 0; nmal = 0; nsus = 0
	for (x = 1; x <= ne; x++) { i = E[x]; if (MV[i] == "MAL") nmal++; else if (MV[i] == "SUS") nsus++ }
	verdict = (nmal ? "MALICIOUS" : (nsus ? "SUSPICIOUS" : "NO FINDINGS"))
	header(FR, "TRAIL FINDINGS REPORT")
	out(FR, "Verdict:   " verdict " (" nmal " MAL, " nsus " SUS)")
	# first pass: chains -> KEEP, so the summary can count pruned steps
	for (x = 1; x <= ne; x++) { i = E[x]; if (MV[i] == "MAL" || MV[i] == "SUS") chain(MREF[i]) }
	kept = 0; for (i = 1; i <= ns; i++) if (KEEP[SN[i]]) kept++
	out(FR, wrap("Summary:   " (nmal + nsus) " finding(s); " kept " of " ns " steps lie on finding paths. Benign and unmarked branches are pruned (see full-analysis-log.txt).", 11, W))
	out(FR, HE); out(FR, ""); out(FR, "FINDINGS"); out(FR, HR)
	if (nmal + nsus == 0) out(FR, "  (none)")
	for (x = 1; x <= ne; x++) {
		i = E[x]; if (MV[i] != "MAL" && MV[i] != "SUS") continue
		nfind++; fid = sprintf("F%03d", nfind); r = MREF[i]
		chain(r)
		isitem = (r !~ /^s/)
		what = isitem ? (fld(IT[r], "_d")) : stepname(refstep(r))
		out(FR, fid "  " MV[i] "  " r (MENT[i] != "" ? "  (" MENT[i] ")" : ""))
		out(FR, wrap("  Path:     " CH_TXT, 12, W))
		split(IT[r], tt, "\t")
		out(FR, wrap("  What:     " (isitem ? (tt[2] " " fld(IT[r], "_d")) : what), 12, W))
		out(FR, wrap("  Why:      " (MRS[i] != "" ? MRS[i] : "(no reason given)"), 12, W))
		ev = ""; evj = ""
		for (k = CH_SN; k >= 1; k--) {
			s = CH_S[k]
			out(FR, wrap((k == CH_SN ? "  Evidence: " : "            ") "step " s " " SVERB[s] " raw sha256 " SSHA[s], 12, W))
			evj = evj (evj == "" ? "" : ",") "{\"step\":" s + 0 ",\"raw_sha256\":" js(SSHA[s]) "}"
		}
		out(FR, "  ATT&CK:   " (MATT[i] != "" ? MATT[i] : "-"))
		out(FR, "  Marked:   " MTS[i])
		out(FR, "")
		# entities (+ the marked entity) and evidence timestamps
		ej = isitem ? ents_json(IT[r]) : "{}"
		tse = ""
		if (isitem) {
			n = split(IT[r], a, "\t")
			for (k = 3; k <= n; k++) {
				p = index(a[k], "="); fk = substr(a[k], 1, p - 1); fv = substr(a[k], p + 1)
				if (fv ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/) {
					tse = tse (tse == "" ? "" : ",") js(fv)
					ntl++; TLT[ntl] = fv; TLR[ntl] = r; TLF[ntl] = fk; TLD[ntl] = fid " " tt[2] " " fld(IT[r], "_d")
				}
				if (substr(fk, 1, 1) == "@") {
					# a mark on an entity ref (1.6.path) narrows IOCs to that entity
					ek = substr(fk, 2)
					if (MENT[i] == "" && (ek == "ip" || ek == "path" || ek == "domain")) ioc(ek, fv, fid, FSEEN[ek SUBSEP fv], LSEEN[ek SUBSEP fv])
				} else if (fk == "md5" || fk == "sha256") ioc(fk, fv, fid, STS[refstep(r)], STS[refstep(r)])
				else if (fk == "key" && a[2] == "directive") ioc("key", fv, fid, STS[refstep(r)], STS[refstep(r)])
			}
		}
		if (MENT[i] != "") { p = index(MENT[i], "="); ek = substr(MENT[i], 1, p - 1); fv = substr(MENT[i], p + 1)
			if (ek == "ip" || ek == "path" || ek == "domain") ioc(ek, fv, fid, FSEEN[ek SUBSEP fv], LSEEN[ek SUBSEP fv]) }
		pj = ""; for (k = 1; k <= CH_N; k++) pj = pj (k > 1 ? "," : "") js(CH[k])
		o = "{\"schema\":" js(SE["schema"]) ",\"case_id\":" js(SE["case_id"]) ",\"finding_id\":" js(fid)
		o = o ",\"verdict\":" js(tolower(MV[i])) ",\"ref\":" js(r) ",\"entities\":" ej ",\"reason\":" js(MRS[i])
		o = o ",\"attack\":" arr_json(MATT[i]) ",\"path\":[" pj "],\"evidence\":[" evj "]"
		o = o ",\"ts_marked\":" js(MTS[i]) ",\"ts_evidence\":[" tse "]}"
		print o > (D "/" FJ)
	}

	# timeline (sorted by ts, stable)
	out(FR, "TIMELINE (UTC, from timestamps on marked items)"); out(FR, HR)
	for (i = 2; i <= ntl; i++) { j = i; while (j > 1 && TLT[j - 1] > TLT[j]) { sw(j); j-- } }
	if (!ntl) out(FR, "  (none)")
	for (i = 1; i <= ntl; i++) out(FR, substr(ascii("  " TLT[i] "  " TLR[i] " " TLF[i] "  " TLD[i]), 1, W))
	out(FR, "")

	# IOCs (sorted kind, value)
	out(FR, "IOCS"); out(FR, HR)
	for (i = 2; i <= nioc; i++) { j = i; while (j > 1 && (IK[j - 1] SUBSEP IV[j - 1]) > (IK[j] SUBSEP IV[j])) { swi(j); j-- } }
	if (!nioc) out(FR, "  (none)")
	IJ = "iocs.jsonl"; printf "" > (D "/" IJ)
	for (i = 1; i <= nioc; i++) {
		out(FR, wrap(sprintf("  %-7s %s  [%s]", IK[i], IV[i], IF[i]), 10, W))
		print "{\"schema\":" js(SE["schema"]) ",\"case_id\":" js(SE["case_id"]) ",\"kind\":" js(IK[i]) ",\"value\":" js(IV[i]) \
			",\"finding_ids\":" arr_json(IF[i]) ",\"first_seen\":" js(IFS_[i]) ",\"last_seen\":" js(ILS[i]) "}" > (D "/" IJ)
	}
	out(FR, "")

	# notes on kept steps / finding refs / case-level
	out(FR, "ANALYST NOTES"); out(FR, HR); hn = 0
	for (k = 1; k <= nn; k++) {
		s = (NREF[k] != "" ? refstep(NREF[k]) : NST[k])
		if (KEEP[s] || s == "0" || s == "") { hn++; out(FR, wrap("  " NTS[k] " [" s "]" (NREF[k] != "" ? " " NREF[k] : "") " " NTX[k], 6, W)) }
	}
	if (!hn) out(FR, "  (none)")
	footer(FR)
}

function ioc(k, v, fid, f, l,    key, i) {
	if (v == "") return
	key = k SUBSEP v
	if (!(key in IOCI)) { IOCI[key] = ++nioc; IK[nioc] = k; IV[nioc] = v; IF[nioc] = ""; IFS_[nioc] = f; ILS[nioc] = l }
	i = IOCI[key]
	if (("," IF[i] ",") !~ ("," fid ",")) IF[i] = IF[i] (IF[i] == "" ? "" : ",") fid
	if (f != "" && (IFS_[i] == "" || f < IFS_[i])) IFS_[i] = f
	if (l != "" && l > ILS[i]) ILS[i] = l
}
function sw(j,    t) { t = TLT[j]; TLT[j] = TLT[j - 1]; TLT[j - 1] = t; t = TLR[j]; TLR[j] = TLR[j - 1]; TLR[j - 1] = t
	t = TLF[j]; TLF[j] = TLF[j - 1]; TLF[j - 1] = t; t = TLD[j]; TLD[j] = TLD[j - 1]; TLD[j - 1] = t }
function swi(j,    t) { t = IK[j]; IK[j] = IK[j - 1]; IK[j - 1] = t; t = IV[j]; IV[j] = IV[j - 1]; IV[j - 1] = t
	t = IF[j]; IF[j] = IF[j - 1]; IF[j - 1] = t; t = IFS_[j]; IFS_[j] = IFS_[j - 1]; IFS_[j - 1] = t; t = ILS[j]; ILS[j] = ILS[j - 1]; ILS[j - 1] = t }
