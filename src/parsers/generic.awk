# generic.awk - fallback parser: every non-metadata line becomes a `line` item
/^#@/ { next }
/^[ \t]*$/ { next }
{ t = clean($0); print "line\ttext=" t "\t_d=" t }
