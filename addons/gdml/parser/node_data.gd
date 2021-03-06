extends Reference

var node_name := ""
var is_open := false
var is_empty := false
var attributes := {} # Attribute: String -> Attribute value: Variant
var text := ""
var is_complete := false # If we are done parsing the entire xml file

# Used for fixing hanging open tags
var location: int = -1

func _to_string() -> String:
	return JSON.print(get_as_dict(), "\t")

func get_as_dict() -> Dictionary:
	return {
		"node_name": node_name,
		"is_open": is_open,
		"is_empty": is_empty,
		"attributes": attributes,
		"text": text,
		"is_complete": is_complete
	}

func copy_as_close(nd) -> void:
	"""
	Helper for generating a dummy close tag for a hanging open tag
	"""
	node_name = nd.node_name
	is_open = false
