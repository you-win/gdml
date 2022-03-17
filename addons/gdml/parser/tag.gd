extends Reference

#region Parser metadata

var location: int = -1
var depth: int = -1

#endregion

var name := ""
var attributes := {}
var text := ""

func _init(p_name: String, p_attr: Dictionary, p_text: String, p_loc: int, p_depth: int) -> void:
	name = p_name
	attributes = p_attr
	text = p_text
	
	location = p_loc
	depth = p_depth

func _to_string() -> String:
	return JSON.print(get_as_dict(), "\t")

func get_as_dict() -> Dictionary:
	return {
		"name": name,
		"attributes": attributes,
		"text": text
	}
