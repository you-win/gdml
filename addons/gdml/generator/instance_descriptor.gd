extends Reference

var name := ""
var src := ""

func get_name() -> String:
	var r := ""
	
	if not name.empty():
		r = name
	elif not src.empty():
		# basename is used to differentiate files with the same name but in different paths
		r = src.get_basename()
	
	return r
