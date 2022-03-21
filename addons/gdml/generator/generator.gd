extends Reference

const OUTPUT_NAME := "GDML"

const ScriptHandler = preload("res://addons/gdml/generator/handlers/script_handler.gd")
const StyleHandler = preload("res://addons/gdml/generator/handlers/style_handler.gd")

const Constants = preload("res://addons/gdml/constants.gd")
const Error = preload("res://addons/gdml/error.gd")

const Layout = preload("res://addons/gdml/parser/layout.gd")
const Tag = preload("res://addons/gdml/parser/tag.gd")

const ControlRoot = preload("res://addons/gdml/generator/control_root.gd")
const Stack = preload("res://addons/gdml/generator/stack.gd")

var _context_path := ""

# Needed for parsing tags with 2d/3d in the name and generating a valid godot classname
var _regex_2d3d: RegEx

var _script_handler: ScriptHandler
var _style_handler: StyleHandler

var _registered_scenes := {}

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _init(context_path: String, registered_scenes: Dictionary) -> void:
	_context_path = context_path
	
	_script_handler = ScriptHandler.new(_context_path)
	_style_handler = StyleHandler.new(_context_path)

	_registered_scenes = registered_scenes

	_regex_2d3d = RegEx.new()
	_regex_2d3d.compile("\\b\\d(\\w{1})\\b")

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

func _generate(stack: Stack, layout: Layout, visited_locations: Array, idx: int) -> int:
	var err := OK

	var tag: Tag = layout.tags[idx]
	
	if tag.location in visited_locations:
		return err
	visited_locations.append(tag.location)

	match tag.name:
		Constants.GDML:
			var gdml := ControlRoot.new()

			_handle_attributes(tag, gdml, stack)

			# Hoist scripts
			var gdml_script_tags: Array = layout.gdml_script_tags.get(tag.location, [])
			for script_tag in gdml_script_tags:
				if script_tag.location in visited_locations:
					push_warning("Tried to visit location %d again" % script_tag.location)
					continue
				visited_locations.append(script_tag.location)
				
				var script_name := _create_script_name_from_tag(script_tag)
				var script := GDScript.new()
				
				err = _script_handler.handle_tag(script_tag, script_name, script)
				if err != OK:
					push_error("Failure when handling script for tag: %s" % tag.to_string())
					continue
				
				# TODO refactor in stack as well
				gdml.add_instance(script, script_name)
				gdml.add_temp_instance(script, script_name)

			stack.add_gdml(tag.depth, gdml)
		Constants.SCRIPT:
			var script_name := _create_script_name_from_tag(tag)
			var script := GDScript.new()
			err = _script_handler.handle_tag(tag, script_name, script)
			if err != OK:
				push_error("Failure when handling script for tag: %s" % tag.to_string())

			stack.add_child(tag.depth, script, script_name)
		Constants.STYLE:
			var themes: Dictionary = _style_handler.handle_style(tag)
			if themes.empty():
				push_warning("No themes parsed for tag %s" % tag.to_string())
				continue

			# TODO this always uses the default theme
			# TODO maybe don't immediately apply the theme?
			var stack_top: Object = stack.top()
			if stack_top.is_class("Control"):
				stack_top.theme = themes["default"]
			else:
				stack.root().theme = themes["default"]
		_:
			var obj: Object = _handle_element(tag, stack)
			if obj == null:
				push_error("Unable to handle element for tag %s" % tag.to_string())
				return Error.Code.HANDLE_ELEMENT_FAILURE

			stack.add_child(tag.depth, obj, _create_script_name_from_tag(tag))

	return err

static func _create_script_name_from_tag(tag: Tag) -> String:
	"""
	Looks through tag data and tries to generate a sensible script name. An explicit 'name' is
	given priority.

	Params:
		tag: Tag - The tag to create a script name for
	
	Return:
		String - The script name
	"""
	var script_name := ""
#	if tag.attributes.has(Constants.NAME):
#		script_name = tag.attributes[Constants.NAME]
#	elif tag.attributes.has(Constants.SRC):
#		script_name = tag.attributes[Constants.SRC]
#	elif tag.attributes.has(Constants.SOURCE):
#		script_name = tag.attributes[Constants.SOURCE]
#	else:
#		script_name = Constants.SCRIPT_NAME_TEMPLATE % tag.location
	
	if tag.name == Constants.SCRIPT:
		if tag.attributes.has(Constants.NAME):
			script_name = tag.attributes[Constants.NAME]
		elif tag.attributes.has(Constants.SRC):
			script_name = tag.attributes[Constants.SRC]
		elif tag.attributes.has(Constants.SOURCE):
			script_name = tag.attributes[Constants.SOURCE]
	else:
		if tag.attributes.has(Constants.SRC):
			script_name = tag.attributes[Constants.SRC]
		elif tag.attributes.has(Constants.SOURCE):
			script_name = tag.attributes[Constants.SOURCE]
	
	if script_name.empty():
		script_name = Constants.SCRIPT_NAME_TEMPLATE % tag.location

	return script_name

static func _create_godot_class_name_from_tag(regex: RegEx , text: String) -> String:
	"""
	Tags are snake-cased (or at least should be snake-cased). Try and convert them back to
	Godot class names

	Params:
		regex: RegEx - A precompiled regex search that looks for 2d/2D/3d/3D
		text: String - The tag name to be converted

	Return:
		String - The converted String
	"""
	var r := ""

	var split := text.split("_", false)
	if split.size() == 1:
		return text.capitalize()
	
	for i in split:
		if regex.search(i):
			r += i.to_upper()
		else:
			r += i.capitalize()

	return r

func _handle_element(tag: Tag, stack: Stack) -> Object:
	var object: Object
	var godot_class_name := _create_godot_class_name_from_tag(_regex_2d3d, tag.name)
	if ClassDB.class_exists(godot_class_name):
		object = ClassDB.instance(godot_class_name)
	elif _registered_scenes.has(tag.name):
		object = _registered_scenes[tag.name].instance()
	else:
		push_error("Unknown tag or scene %s" % tag.name)
		return null

	object.set("text", tag.text)

	var err: int = _handle_attributes(tag, object, stack)
	if err != OK:
		push_error("Error occurred while handling attributes: %s" % Error.to_error_name(err))

	return object

func _handle_attributes(tag: Tag, object: Object, stack: Stack) -> int:
	"""
	Process all attributes on a Tag. The function does not return early on errors.
	Instead, it will log the error and continue processing, storing the error and
	potentially overwriting the error with newer errors.

	The 'src' attribute is always processed first if it exists. This is because
	initial properties can be passed to the resulting script.

	Params:
		tag: Tag - The Tag to handle
		object: Object - The object to apply attributes to
		stack: Stack - The stack being used

	Return:
		int - The error code. Returns OK if everything was processed successfully
	"""
	var err := OK

	# Always process the src first
	if tag.attributes.has(Constants.SRC) or tag.attributes.has(Constants.SOURCE):
		err = _handle_src_attribute(tag, object, stack)
		if err != OK:
			push_error("Error %s occurred while handling src: %s" %
				[
					Error.to_error_name(err),
					tag.attributes.get(Constants.SRC, tag.attributes.get(Constants.SOURCE))
				])
	
	for key in tag.attributes.keys():
		var val = tag.attributes[key]
		match key:
			Constants.NAME:
				object.set("name", val)
			Constants.STYLE, Constants.PROPS:
				_style_handler.handle_inline_style(object, val)
			Constants.SRC, Constants.SOURCE:
				# Already handled
				pass
			_:
				var inner_err: int = _handle_connections(key, val, object, stack)
				if inner_err != OK:
					push_error("Error occurred while handling connection - callback: %s - %s" %
						[key, val])
					err = inner_err
	
	return err

func _handle_src_attribute(tag: Tag, object: Object, stack: Stack) -> int:
	"""
	Try three different methods of finding the src script:
	1. Find a temp instance of the script on the stack
	2. Find a persistent instance of the script on the stack
	3. Try to load the script from the context_path + src
	"""
	var err := OK
	var script := GDScript.new()

	var script_name := _create_script_name_from_tag(tag)
	var instance: Object = stack.find_temp_instance(script_name)
	if instance != null:
		if instance.is_class("GDScript"):
			object.set_script(instance)
			return err
		else:
			script = object.get_script()
			if script != null:
				object.set_script(script.duplicate())
				return err

	instance = stack.find_instance(script_name)
	if instance != null:
		if instance.is_class("GDScript"):
			object.set_script(instance)
			return err
		else:
			script = object.get_script()
			if script != null:
				object.set_script(script.duplicate())
				return err

	err = _script_handler.handle_tag(tag, script_name, script)
	if err == OK:
		object.set_script(script)
	
	return err

func _handle_connections(
	signal_name: String,
	callback: String,
	object: Object,
	stack: Stack
) -> int:
	if not object.has_signal(signal_name) and not object.has_user_signal(signal_name):
		return Error.Code.NO_SIGNAL_FOUND
	if object.is_connected(signal_name, object, callback):
		return Error.Code.SIGNAL_ALREADY_CONNECTED
	
	var args := []

	var dot_split: PoolStringArray = callback.split(".", false, 1)
	callback = dot_split[0]
	if dot_split.size() == 2:
		var func_arg_split := dot_split[1].split("(", false, 1)
		callback = func_arg_split[0]
		if func_arg_split.size() == 2:
			args.append_array(_generate_connect_args(func_arg_split[1], object, stack))
		
	if object.has_method(callback):
		return object.connect(signal_name, object, callback, args)
	
	# var stack_instance: Object = stack.find_object_for_signal_in_stack(signal_name)
	var stack_instance: Object = stack.find_object_for_method_in_stack(callback)
	if stack_instance == null:
		return Error.Code.MISSING_ON_STACK
	
	return object.connect(signal_name, stack_instance, callback, args)

func _generate_connect_args(args_text: String, object: Object, stack: Stack) -> Array:
	var r := []

	var args := args_text.rstrip(")").replace(" ", "").split(",", false)

	for arg in args:
		var val = _handle_cast(arg)

		if typeof(val) == TYPE_STRING:
			if val == "self":
				r.append(object)
			elif val[0] == "'" or val[0] == '"':
				r.append(val)
			else:
				var result = _handle_nested_arg(val, stack)
				if result != null:
					r.append(result)
		else:
			r.append(val)

	return r

func _handle_cast(arg: String):
	var split := arg.split(")")
	if split.size() != 2:
		return arg

	var val: String = split[1]

	match split[0].lstrip("("):
		"float":
			return float(val)
		"int":
			return int(val)
		"color":
			return Color(val)
		"colorN":
			return ColorN(val)
		_:
			return val

func _handle_nested_arg(query: String, stack: Stack):
	var class_split: PoolStringArray = query.split(".", false)
	
	var instance: Object = stack.find_instance(class_split[0])
	if instance == null:
		push_error("Unable to find arg %s" % query)
		return null

	# Dig into the instance to find the nested value
	var failed := false
	for i in class_split.size():
		if i == 0:
			continue

		var tmp = instance.get(class_split[i])
		if tmp == null:
			push_error("Unable to completely process arg %s at %s" % [query, class_split[i]])
			failed = true
			break
		
		instance = tmp

	if failed:
		return null

	return instance

###############################################################################
# Public functions                                                            #
###############################################################################

func generate(output: Control, layout: Layout) -> int:
	var err := OK
	
	output.set_anchors_preset(Control.PRESET_WIDE)
	output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output.set_script(ControlRoot)
	output.name = OUTPUT_NAME

	var stack := Stack.new(output)
	var visited_locations := []
	for i in layout.tags.size(): # Tag
		var inner_err = _generate(stack, layout, visited_locations, i)
		if inner_err != OK:
			push_error("Error occurred while generating: %s" % Error.to_error_name(err))
			err = inner_err

	return err
