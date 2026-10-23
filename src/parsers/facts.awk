# facts.awk - "key value..." lines -> fact items
/^#@/ { next }
{
	k = $1; v = $0; sub(/^[^ ]+ ?/, "", v); v = clean(v)
	print "fact\tkey=" k "\tvalue=" v "\t_d=" sprintf("%-15s %s", k, v)
}
