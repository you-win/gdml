extends Reference

const OUTPUT_NAME := "GDML"
const TEXT_CONTROLS := ["Label", "Button", "LineEdit", "TextEdit"]

const ScriptHandler = preload("res://addons/gdml/generator/handlers/script_handler.gd")
const StyleHandler = preload("res://addons/gdml/generator/handlers/style_handler.gd")

const Constants = preload("res://addons/gdml/constants.gd")
const Error = preload("res://addons/gdml/error.gd")

const Layout = preload("res://addons/gdml/parser/layout.gd")
const Tag = preload("res://addons/gdml/parser/tag.gd")

const ControlRoot = preload("res://addons/gdml/generator/control_root.gd")
const InstanceDescriptor = preload("res://addons/gdml/generator/instance_descriptor.gd")

var _context_path := ""

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

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

static func _cache_scripts(sh: ScriptHandler, tags: Array) -> int:
	for tag in tags:
		if tag.name == Constants.SCRIPT or tag.attributes.has(Constants.SRC):
			sh.handle_script_tag(tag)
		_cache_scripts(sh, tag.children)

	return OK

# TODO gdml stack should be searched in reverse order?
func _generate(tag: Tag, super_root: Control, gdml_stack: Array, parent: Object = null) -> int:
	"""
	Params:
		tag: Tag - The current tag being processed
		super_root: Control - The root node containing all GDML elements
		gdml_stack: Array - The stack of GDML tags that are being processed
		parent: Object - The parent object (generated from the parent tag) of the current tag

	Return:
		int - Error code
	"""
	var err := OK
	
	match tag.name:
		Constants.GDML:
			var gdml := Control.new()
			gdml.set_anchors_preset(Control.PRESET_WIDE)
			gdml.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gdml.set_script(load("res://addons/gdml/generator/control_root.gd"))
			
			_handle_attributes(tag, gdml, super_root, gdml_stack)

			gdml_stack.append(gdml)

			# Hoist scripts
			var visited_tags := [] # Tag
			for child_tag in tag.children:
				if child_tag.name != Constants.SCRIPT:
					continue
				visited_tags.append(child_tag)
				err = _generate(child_tag, super_root, gdml_stack, gdml)
				if err != OK:
					push_error("Error occurred while generating script for tag %s" % tag.to_string())
			
			# Process the rest of the tags
			for child_tag in tag.children:
				if child_tag in visited_tags:
					continue
				err = _generate(child_tag, super_root, gdml_stack, gdml)
				if err != OK:
					push_error("Error occurred while generating resource for tag %s" % tag.to_string())

			gdml_stack.pop_back()
			
			parent.add_child(gdml) if parent != null else super_root.add_child(gdml)
		Constants.SCRIPT:
			var script_name: String = (
				tag.attributes.get(Constants.SRC) if tag.attributes.has(Constants.SRC) else (
					tag.attributes.get(Constants.NAME) if tag.attributes.has(Constants.NAME) else (
						ScriptHandler.SCRIPT_NAME_TEMPLATE % tag.location
					)
				)
			)
			
			var script: GDScript = _script_handler.find_script(tag, script_name)

			if script == null:
				push_error("Script is not known for tag %s" % tag.to_string())
				return Error.Code.UNKNOWN_SCRIPT

			if parent != null and tag.parent.name != Constants.GDML:
				if parent.is_class("Node"):
					parent.set_script(script.new())
				else: # References and objects cannot have their script replaced, so just add it as a meta var
					parent.set_meta(script_name, script.new())
			elif gdml_stack.size() > 0:
				gdml_stack[-1].add_instance(script, _create_instance_descriptor(tag))
			else:
				super_root.add_instance(script, _create_instance_descriptor(tag))
			
			for tag_child in tag.children:
				_generate(tag_child, super_root, gdml_stack, null)
		Constants.STYLE:
			# TODO cache themes first like with scripts
			var themes: Dictionary = _style_handler.handle_style(tag)
			if themes.empty():
				return Error.Code.NO_THEMES_PARSED
			
			# TODO this always uses the default theme
			if parent.is_class("Control"):
				parent.theme = themes["default"]
			elif gdml_stack.size() > 0:
				gdml_stack[-1].theme = themes["default"]
			else:
				super_root.theme = themes["default"]
			
			for tag_child in tag.children:
				_generate(tag_child, super_root, gdml_stack, null)
		_:
			var object: Object = _handle_element(tag, super_root, gdml_stack, parent)
			if object == null:
				push_error("Unable to handle element for tag %s" % tag.to_string())
				return Error.Code.HANDLE_ELEMENT_FAILURE
			
			gdml_stack.append(object)
			
			for tag_child in tag.children:
				_generate(tag_child, super_root, gdml_stack, object)
			
			gdml_stack.pop_back()
	
	return err

static func _create_instance_descriptor(tag: Tag) -> InstanceDescriptor:
	var r := InstanceDescriptor.new()
	for key in tag.attributes.keys():
		r.set(key, tag.attributes[key])

	return r

func _handle_element(
	tag: Tag,
	super_root: ControlRoot,
	gdml_stack: Array,
	parent: Object
) -> Object:
	var object: Object
	var godot_class_name := tag.name.capitalize().replace(" ", "")
	if ClassDB.class_exists(godot_class_name):
		object = ClassDB.instance(godot_class_name)
	elif _registered_scenes.has(tag.name):
		object = _registered_scenes[tag.name].instance()

	object.set("text", tag.text)

	if object.is_class("Node") and parent.is_class("Node"):
		parent.add_child(object)
	elif parent.has_method("add_instance"):
		parent.add_instance(object, _create_instance_descriptor(tag))
	else:
		parent.set_meta(tag.name, object)

	_handle_attributes(tag, object, super_root, gdml_stack)

	return object

func _handle_attributes(tag: Tag, object: Object, super_root: ControlRoot, gdml_stack: Array) -> int:
	for key in tag.attributes.keys():
		var val = tag.attributes[key]
		match key:
			Constants.NAME:
				object.set(Constants.NAME, val)
			Constants.SRC:
				var script: GDScript = _script_handler.find_script(tag, val)
				if script == null:
					push_warning("No script found for tag %s - %s" % [tag.to_string(), val])
					continue

				object.set_script(script.new())
			Constants.STYLE:
				if not object.is_class("Control"):
					push_warning("Tried to set style on a non-Control element: %s - %s" % [key, val])
					continue
				_style_handler.handle_inline_style(object, val)
			Constants.CLASS:
				pass
			Constants.ID:
				pass
			_:
				_handle_connections(key, val, object, super_root, gdml_stack)
	
	return OK

func _handle_connections(
	key: String,
	value: String,
	object: Object,
	super_root: ControlRoot,
	gdml_stack: Array
) -> int:
	if not object.has_signal(key) and not object.has_user_signal(key):
		return Error.Code.NO_SIGNAL_FOUND
	
	var args := []

	var dot_split: PoolStringArray = value.split(".", false, 1)
	value = dot_split[0]
	if dot_split.size() == 2:
		var func_arg_split := dot_split[1].split("(", false, 1)
		value = func_arg_split[0]
		if func_arg_split.size() == 2:
			args.append_array(_generate_connect_args(func_arg_split[1], object, super_root, gdml_stack))
		
	if object.has_method(value):
		object.connect(key, object, value, args)
	else:
		var err := OK
		for gdml in gdml_stack:
			err = gdml.find_and_connect(key, object, value, args)
			if err == OK:
				break
		
		if err != OK:
			err = super_root.find_and_connect(key, object, value, args)
		
		if err != OK:
			push_error("Unable to connect %s - %s for object %s" % [key, value, str(object)])
			return err
	
	return OK

func _generate_connect_args(args_text: String, object: Object, super_root: ControlRoot, gdml_stack: Array) -> Array:
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
				var result = _handle_nested_arg(val, super_root, gdml_stack)
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

func _handle_nested_arg(query: String, super_root: ControlRoot, gdml_stack: Array):
	var class_split: PoolStringArray = query.split(".", false)

	var instance
	
	# Find the actual instance first
	for gdml in gdml_stack:
		instance = gdml.find_instance(class_split[0])
		if instance != null:
			break
	
	if instance == null:
		instance = super_root.find_instance(class_split[0])

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

func generate(p_output: Control, layout: Layout) -> int:
	var err := OK
	
	_cache_scripts(_script_handler, layout.tags)

	var output: Control = p_output
	output.set_anchors_preset(Control.PRESET_WIDE)
	output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output.set_script(ControlRoot)
	output.name = OUTPUT_NAME

	for tag in layout.tags: # Tag
		var inner_err = _generate(tag, output, [], null)
		if inner_err != OK:
			push_error("Error occurred while generating: %s" % Error.to_error_name(err))
			err = inner_err

	return err
