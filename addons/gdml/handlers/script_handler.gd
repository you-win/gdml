class_name GDML_ScriptHandler
extends GDML_AbstractHandler

func _init(p_context_path: String).(p_context_path) -> void:
	pass

func handle_script_tag(tag: GDML_Tag) -> GDScript:
	var input := ""

	if tag.attributes.has("src"):
		var file := File.new()
		if file.open("%s/%s" % [context_path, tag.attributes["src"]], File.READ) != OK:
			push_error("Failed to open file at path %s" % "%s/%s" % [context_path, tag.attributes["src"]])
			return null

		input = file.get_as_text()
	else:
		input = tag.text

	var script := _generate_script(input)
	if script == null:
		push_error("Failed to parse script from node %s" % tag.node_name)
		return null

	return script

func handle_script_path(path: String) -> GDScript:
	var file := File.new()
	if file.open("%s/%s" % [context_path, path], File.READ) != OK:
		push_error("%s/%s" % [context_path, path])
		return null

	var script := _generate_script(file.get_as_text())
	if script == null:
		push_error("Failed to parse script from path %s" % path)
		return null

	return script

func _generate_script(text: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = text
	if script.reload() != OK:
		return null

	return script
