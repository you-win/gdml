extends Reference

signal layout_created(layout)

const Error = preload("res://addons/gdml/error.gd")
const Constants = preload("res://addons/gdml/constants.gd")

const Parser = preload("res://addons/gdml/parser/parser.gd")
const Generator = preload("res://addons/gdml/generator/generator.gd")

const CssProcessor = preload("res://addons/gdml/godot-css-theme/css_processer.gd")

const TEXT_CONTROLS := ["Label", "Button", "LineEdit", "TextEdit"]
const CONTROL_ROOT_PATH := "res://addons/gdml/control_root.gd"

var registered_scenes := {} # Scene name: String -> path (rel/abs) : String | PackedScene

var context_path := ""

func _init(p_context_path: String) -> void:
	context_path = ProjectSettings.globalize_path(p_context_path)

func generate(input: String) -> Control:
	var output := Control.new()

	var is_path := true
	if input.is_abs_path():
		input = ProjectSettings.globalize_path(input)
	elif input.is_rel_path():
		if context_path.empty():
			push_error("A context_path is required when using a relative path")
			return output
		input = "%s/%s" % [context_path, input]
	else: # The result of File.get_as_text()
		is_path = false
	
	var layout := Parser.Layout.new()
	var parser := Parser.new()
	var err := parser.parse(input, layout)
	if err != OK:
		push_error("Error occurred during parsing: %s" % Error.to_error_name(err))
		return output

	var generator := Generator.new(context_path, registered_scenes)
	err = generator.generate(output, layout)
	if err != OK:
		push_error("Error occurred during generation: %s" % Error.to_error_name(err))
		return output
		
	return output

func register_scene(thing_name: String, thing) -> int:
	"""
	Registers a scene to be used during generation
	
	Params:
		thing_name: String - The name to be used, tags will be matched against this name
		thing: Variant - Can be either a String path (rel/abs) or a PackedScene
	
	Return:
		int - The error code
	"""
	if typeof(thing) != TYPE_STRING and not thing is PackedScene:
		return Error.Code.INVALID_REGISTERED_SCENE
	
	if registered_scenes.has(thing_name):
		push_warning("registered_scenes already contains %s, overwriting" % thing_name)
	
	registered_scenes[thing_name] = thing
	
	return OK
