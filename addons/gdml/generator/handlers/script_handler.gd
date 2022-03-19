extends "res://addons/gdml/generator/handlers/abstract_handler.gd"

const Error = preload("res://addons/gdml/error.gd")
const Constants = preload("res://addons/gdml/constants.gd")

const Tag = preload("res://addons/gdml/parser/tag.gd")

var known_scripts := {} # Script name: String -> GDScript (not initialized)

func _init(p_context_path: String).(p_context_path) -> void:
	pass

func handle_tag(tag: Tag, script_name: String, empty_script: GDScript) -> int:
	var input := tag.text

	if tag.attributes.has(Constants.SRC):
		var file_name: String = tag.attributes[Constants.SRC]

		var file := File.new()
		if file.open("%s/%s" % [context_path, file_name], File.READ) != OK:
			return Error.Code.FILE_OPEN_FAILURE

		input = file.get_as_text()

	empty_script.source_code = input
	if empty_script.reload() != OK:
		return Error.Code.BAD_SCRIPT_TEXT
	
	return OK

func find_script(script_name: String) -> GDScript:
	return known_scripts.get(
		script_name,
		known_scripts.get(
			script_name.get_basename(),
			known_scripts.get(
				script_name.get_file())))
