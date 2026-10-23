# ls.awk - `ls -ln` long listing -> path items (paths made absolute from #@dir)
BEGIN { dir = "" }
/^#@dir / { dir = substr($0, 7); next }
/^#@/ { next }
/^total / { next }
{
	# perms links uid gid size <date fields...> name
	if (NF < 7) next
	perms = $1; sz = $5
	# name begins after field 8 (date is 3 tokens: $6 $7 $8). Symlink: "a -> b".
	name = $0
	for (k = 1; k <= 8; k++) sub(/^[ \t]*[^ \t]+/, "", name)
	sub(/^[ \t]+/, "", name)
	tgt = ""
	if (index(name, " -> ")) { tgt = name; sub(/^.* -> /, "", tgt); sub(/ -> .*/, "", name) }
	if (name == "." || name == ".." || name == "") next
	if (substr(name, 1, 1) == "/") path = name
	else { base = dir; sub(/\/+$/, "", base); path = base "/" name }
	typ = substr(perms, 1, 1)
	line = "path\tname=" clean(name) "\tpath=" clean(path) "\tperms=" perms "\tsize=" sz
	if (tgt != "") line = line "\tsymlink=" clean(tgt)
	line = line "\t_d=" clean(sprintf("%s %10s  %s%s", perms, sz, name, (tgt != "" ? " -> " tgt : "")))
	line = line "\t@path=" clean(path)
	print line
}
