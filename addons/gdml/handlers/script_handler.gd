extends "res://addons/gdml/handlers/abstract_handler.gd"

func _init(p_context_path: String).(p_context_path) -> void:
	pass

func handle_script(data) -> GDScript:
	var input := ""

	if data.attributes.has("src"):
		var file := File.new()
		if file.open("%s/%s" % [context_path, data.attributes["src"]], File.READ) != OK:
			push_error("Failed to open file at path %s" % "%s/%s" % [context_path, data.attributes["src"]])
			return null

		input = file.get_as_text()
	else:
		input = data.text

	var script := GDScript.new()
	script.source_code = input
	if script.reload() != OK:
		push_error("Failed to parse script from node %s" % data.node_name)
		return null

	return script
