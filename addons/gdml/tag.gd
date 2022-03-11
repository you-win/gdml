class_name GDML_Tag
extends Reference

var name := ""
var attributes := {}
var text := ""

var is_open := false
var depth: int = -1

func _init(p_name: String, p_attributes: Dictionary, p_text: String, p_is_open: bool, p_depth: int) -> void:
	name = p_name
	attributes = p_attributes
	text = p_text
	is_open = p_is_open
	depth = p_depth

func _to_string() -> String:
	return JSON.print(get_as_dict(), "\t")

func get_as_dict() -> Dictionary:
	return {
		"name": name,
		"attributes": attributes,
		"text": text,
		"is_open": is_open,
		"depth": depth
	}
