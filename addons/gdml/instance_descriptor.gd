extends Reference

var name := ""
var src := ""

func get_name() -> String:
	var r := ""

	if not name.empty():
		r = name
	elif not src.empty():
		r = src.get_file().replace(".gd", "")

	return r
