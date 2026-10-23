# exe.awk - /proc/<pid>/exe resolution -> one path item
/^#@/ { next }
/^pid /    { pid = $2; next }
/^target / { tgt = substr($0, 8); next }
/^deleted /{ del = $2; next }
/^md5 /    { md5 = $2; next }
/^sha256 / { sha = $2; next }
/^filetype /{ ft = substr($0, 10); next }
END {
	if (tgt == "") exit
	real = tgt; sub(/ \(deleted\)$/, "", real)
	line = "path\tpath=" clean(real) "\tpid=" pid
	if (del == "1") line = line "\tdeleted=1"
	if (md5 != "") line = line "\tmd5=" md5 "\tsha256=" sha
	if (ft != "")  line = line "\tfiletype=" clean(ft)
	d = real (del == "1" ? "  (deleted)" : "") (ft != "" ? "  " ft : "") (md5 != "" ? "  md5=" md5 : "")
	line = line "\t_d=" clean(d) "\t@path=" clean(real) "\t@pid=" pid
	if (md5 != "") line = line "\t@md5=" md5
	if (sha != "") line = line "\t@sha256=" sha
	print line
}
