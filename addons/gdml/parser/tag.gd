class_name GDML_Tag
extends Reference

var parent: GDML_Tag = null
var children := []

var name := ""
var attributes := {}
var text := ""

func _init(node_data: GDML_NodeData) -> void:
	name = node_data.node_name
	attributes = node_data.attributes
	text = node_data.text

func _to_string() -> String:
	return JSON.print(get_as_dict(), "\t")

func get_as_dict() -> Dictionary:
	return {
		"name": name,
		"attributes": attributes,
		"text": text
	}
