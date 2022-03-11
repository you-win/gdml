class_name GDML_NodeData
extends Reference

var node_name := ""
var is_open := false
var attributes := {} # Attribute: String -> Attribute value: Variant
var text := ""
var is_complete := false # If we are done parsing the entire xml file

func _to_string() -> String:
	return JSON.print(get_as_dict(), "\t")

func get_as_dict() -> Dictionary:
	return {
		"node_name": node_name,
		"is_open": is_open,
		"attributes": attributes,
		"text": text,
		"is_complete": is_complete
	}
