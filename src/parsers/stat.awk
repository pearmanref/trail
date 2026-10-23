# stat.awk - stat() output -> one path item (epoch times -> ISO Z)
/^#@/ { next }
/^mode /  { mode_o = $2; mode = $3; next }
/^uid /   { uid = $2; uname = $3; next }
/^gid /   { gid = $2; gname = $3; next }
/^size /  { size = $2; next }
/^mtime / { mt = $2; next }
/^ctime / { ct = $2; next }
/^atime / { at = $2; next }
/^ftype / { ftype = substr($0, 7); next }
/^link /  { link = substr($0, 6); next }
/^lsline /{ ls = substr($0, 8); next }
/^md5 /   { md5 = $2; next }
/^sha256 /{ sha = $2; next }
END {
	path = link; sub(/^'/, "", path); sub(/'.*/, "", path)   # %N quotes the name
	if (path == "") path = ls
	mts = (mt != "" ? iso(mt) : "")
	line = "path\tpath=" clean(path)
	if (mode != "") line = line "\tmode=" mode "\tmode_oct=" mode_o
	if (uname != "") line = line "\towner=" uname ":" gname
	if (size != "") line = line "\tsize=" size
	if (mts != "")  line = line "\tmtime=" mts
	if (ct != "")   line = line "\tctime=" iso(ct)
	if (ftype != "")line = line "\tftype=" clean(ftype)
	if (md5 != "")  line = line "\tmd5=" md5 "\tsha256=" sha
	d = (ls != "" ? ls : sprintf("%s %-10s %10s %s  %s", mode, uname ":" gname, size, mts, path) (ftype != "" ? "  (" ftype ")" : "") (md5 != "" ? "  md5=" md5 : ""))
	line = line "\t_d=" clean(d) "\t@path=" clean(path)
	if (md5 != "") line = line "\t@md5=" md5
	if (sha != "") line = line "\t@sha256=" sha
	print line
}
