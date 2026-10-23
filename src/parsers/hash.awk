# hash.awk - md5+sha256 of one file
/^#@/ { next }
/^file /  { f = substr($0, 6); next }
/^md5 /   { md5 = $2; next }
/^sha256 /{ sha = $2; next }
END {
	if (f == "") exit
	line = "path\tpath=" clean(f) "\tmd5=" md5 "\tsha256=" sha
	line = line "\t_d=" clean("md5=" md5 "  sha256=" sha "  " f)
	line = line "\t@path=" clean(f) "\t@md5=" md5 "\t@sha256=" sha
	print line
}
