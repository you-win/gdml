extends "res://addons/gdml/generator/handlers/abstract_handler.gd"

const SCRIPT_NAME_TEMPLATE := "Script_%d"

const Error = preload("res://addons/gdml/error.gd")

const Tag = preload("res://addons/gdml/parser/tag.gd")

var known_scripts := {} # Script name: String -> GDScript (not initialized)

func _init(p_context_path: String).(p_context_path) -> void:
	pass

func handle_script_tag(tag: Tag) -> int:
	var input := ""

	var script_name := ""

	if tag.attributes.has("src"):
		var file_name: String = tag.attributes["src"]

		var file := File.new()
		if file.open("%s/%s" % [context_path, file_name], File.READ) != OK:
			push_error("Failed to open file at path %s" % "%s/%s" % [context_path, file_name])
			return Error.Code.FILE_OPEN_FAILURE

		input = file.get_as_text()
		script_name = file_name.get_basename()
	else:
		input = tag.text
		script_name = SCRIPT_NAME_TEMPLATE % tag.location

	var script := GDScript.new()

	var err := _populate_script(script, input)
	if err != OK:
		return err

	known_scripts[script_name] = script

	return OK

func _populate_script(script: GDScript, text: String) -> int:
	script.source_code = text
	if script.reload() != OK:
		return Error.Code.BAD_SCRIPT_TEXT

	return OK

func find_script(tag: Tag, text: String) -> GDScript:
	var script: GDScript = known_scripts.get(text)
	if script != null:
		return script

	script = known_scripts.get(text.get_basename())
	if script != null:
		return script

	return known_scripts.get(SCRIPT_NAME_TEMPLATE % tag.location)
