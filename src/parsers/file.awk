# file.awk - libmagic type -> one path item
/^#@/ { next }
/^path / { f = substr($0, 6); next }
/^type / { ty = substr($0, 6); next }
END {
	if (f == "") exit
	print "path\tpath=" clean(f) "\tftype=" clean(ty) "\t_d=" clean(f "  " ty) "\t@path=" clean(f)
}
