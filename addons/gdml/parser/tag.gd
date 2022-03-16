extends Reference

const NodeData = preload("res://addons/gdml/parser/node_data.gd")

#region Layout metadata

var parent: Reference = null
var children := []

#endregion

#region Parser metadata

var location: int = -1
var depth: int = -1

#endregion

var name := ""
var attributes := {}
var text := ""

func _init(node_data: NodeData, depth: int) -> void:
	name = node_data.node_name
	attributes = node_data.attributes
	text = node_data.text
	
	location = node_data.location

func _to_string() -> String:
	return JSON.print(get_as_dict(), "\t")

func get_as_dict() -> Dictionary:
	return {
		"name": name,
		"attributes": attributes,
		"text": text
	}
