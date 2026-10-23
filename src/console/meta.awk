# meta.awk - extract verb metadata header blocks into the verb registry.
# Input: collector and console source files. A block starts at "# @verb" and
# ends at the first line that is not "# @tag value".
# Output TSV (one verb per line):
#   verb kind domain accepts emits opts usage summary example parser needs
# This is the ONLY verb list: help, `?`, type validation, dispatch and shell
# completion are all derived from it.
function flush() {
	if (v != "") {
		if (kind == "") kind = "collector"
		if (acc == "") acc = "none"
		if (emi == "") emi = "none"
		if (usage == "") usage = v
		if (par == "") par = "generic"
		printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", \
			v, kind, dom, acc, emi, opts, usage, summ, ex, par, needs
	}
	v = kind = dom = acc = emi = opts = usage = summ = ex = par = needs = ""
}
/^# @[a-z]+/ {
	tag = $2; sub(/^@/, "", tag)
	val = $0; sub(/^# @[a-z]+[ \t]*/, "", val); gsub(/\t/, " ", val)
	if (tag == "verb") { flush(); v = val; next }
	if (v == "") next
	if (tag == "kind") kind = val
	else if (tag == "domain") dom = val
	else if (tag == "accepts") acc = val
	else if (tag == "emits") emi = val
	else if (tag == "opts") opts = val
	else if (tag == "usage") usage = val
	else if (tag == "summary") summ = val
	else if (tag == "example") ex = (ex == "" ? val : ex " | " val)
	else if (tag == "parser") par = val
	else if (tag == "needs") needs = val
	next
}
{ flush() }
END { flush() }
