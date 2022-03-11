class_name GDML
extends Reference

const TEXT_CONTROLS := ["Label", "Button", "LineEdit", "TextEdit"]
const CONTROL_ROOT_PATH := "res://addons/gdml/control_root.gd"

var registered_scenes := {
	"test_scene": ""
}

var context_path := ""

var script_handler: GDML_ScriptHandler
var style_handler: GDML_StyleHandler

func _init(p_context_path: String) -> void:
	context_path = ProjectSettings.globalize_path(p_context_path)

	script_handler = GDML_ScriptHandler.new(context_path)
	style_handler = GDML_StyleHandler.new(context_path)

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
	
	var reader = GDML_Reader.new()
	var err = reader.read_path(input) if is_path else reader.read_buffer(input.to_utf8())
	if err != OK:
		push_error("Error %d occurred while opening %s" % [err, input if is_path else "buffer"])
		return output

	var layout := _prepass(reader)
	
	var script_handler = GDML_ScriptHandler.new(context_path)
	var style_handler = GDML_StyleHandler.new(context_path)

	# var previous_depth: int = 0
	# var stack := [output]
	
	# var current_root: Control

	var handled_pointer_pairs := []

	for i in layout.gdml_pointers.size():
		var gdml: Control = _handle_gdml(layout, i, handled_pointer_pairs)
		if gdml != null:
			output.add_child(gdml)
		# output.add_child(_handle_gdml(layout, i))

	# for pointer_pair in layout.gdml_pointers:
	# 	output.add_child(_handle_gdml(layout.tags, pointer_pair))

	# for tag in layout.tags:
	# 	if not tag.is_open:
	# 		continue
	# 	var node_name: String = tag.name
	# 	match node_name:
	# 		GDML_Tags.SCRIPT:
	# 			var script: GDScript = script_handler.handle_script(tag)
	# 			if script == null:
	# 				continue

	# 			# TODO stub
	# 			var desc := GDML_InstanceDescriptor.new()
	# 			for key in tag.attributes.keys():
	# 				desc.set(key, tag.attributes[key])

	# 			current_root.add_instance(script, desc)
	# 		GDML_Tags.STYLE:
	# 			var themes: Dictionary = style_handler.handle_style(tag)
	# 			if themes.empty():
	# 				continue

	# 			# TODO test
	# 			current_root.theme = themes["default"]

	# 			# TODO stub
	# 		_:
	# 			# Everything else is a node
	# 			# Technically they should all be Controls, but I'm not the boss of you
	# 			var node: Node
	# 			if node_name == GDML_Tags.GDML:
	# 				node = Control.new()
	# 				node.set_anchors_preset(Control.PRESET_WIDE)
	# 				node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 				current_root = node
	# 				current_root.set_script(load(CONTROL_ROOT_PATH))

	# 				# Reset stack
	# 				previous_depth = 0
	# 				while stack.size() > 1:
	# 					stack.pop_back()
	# 			else:
	# 				var godot_class_name := (node_name as String).capitalize().replace(" ", "")
	# 				if not ClassDB.class_exists(godot_class_name):
	# 					push_error("Class does not exist %s" % godot_class_name)
	# 					continue
					
	# 				node = ClassDB.instance(godot_class_name)

	# 				if godot_class_name in TEXT_CONTROLS:
	# 					node.text = tag.text
				
	# 			# Stack management
	# 			if previous_depth < tag.depth:
	# 				stack[-1].add_child(node)
	# 				stack.append(node)
	# 				previous_depth = tag.depth
	# 			elif previous_depth == tag.depth:
	# 				stack.pop_back()
	# 				stack[-1].add_child(node)
	# 				stack.push_back(node)
	# 			else:
	# 				stack.pop_back()
	# 				stack.pop_back()
	# 				stack[-1].add_child(node)
	# 				previous_depth = tag.depth

	# 			for key in tag.attributes.keys():
	# 				var val = tag.attributes[key]

	# 				match key:
	# 					"name":
	# 						node.name = val
	# 					"style":
	# 						style_handler.handle_inline_style(node, val)
	# 					"src":
	# 						# TODO stub
	# 						pass
	# 					_:
	# 						if node.has_signal(key) or node.has_user_signal(key):
	# 							var split_val: PoolStringArray = val.split(".", false, 1)

	# 							match split_val.size():
	# 								1:
	# 									err = current_root.find_and_connect(key, node, val)
	# 									if err != OK:
	# 										push_error("Error occurred when connecting %d" % err)
	# 										continue
	# 								2:
	# 									var args = _generate_connect_args(current_root, node, split_val[1])
	# 									var callback_name := split_val[1].split("[")[0] if args.size() > 0 else split_val[1]

	# 									err = current_root.direct_connect(split_val[0], key, node, callback_name, args)
	# 									if err != OK:
	# 										push_error("Error occurred when connecting %d" % err)
	# 										continue
	# 								_:
	# 									push_error("Invalid callback for %s: %s - %s" %
	# 										[node_name, key, val])

	output.set_anchors_preset(Control.PRESET_WIDE)
	output.name = "GDML"

	return output

func _prepass(reader: GDML_Reader) -> GDML_Layout:
	var layout := GDML_Layout.new()

	while true:
		var data = reader.read_node()

		if data.is_complete:
			break

		if not data.node_name.empty():
			layout.add_tag(data.node_name, data.attributes, data.text, data.is_open)

	layout.identify_tags()
	for i in layout.orphan_pointers:
		layout.normalize_depth(i)

	layout.reidentify_gdml_pointers()
	layout.hoist_scripts()
	layout.identify_tags()
	layout.reidentify_gdml_pointers()

	return layout

func _generate_connect_args(current_root: Control, node, text: String) -> Array:
	var r := []

	var split := text.split("[", false)
	if split.size() != 2:
		return r

	var args := split[1].rstrip("]").replace(" ", "")

	var split_args := args.split(",")
	for i in split_args:
		var val

		var cast_split: PoolStringArray = i.split(")")
		if cast_split.size() == 2:
			var j = cast_split[1]
			match cast_split[0].lstrip("("):
				"float":
					val = float(j)
				"int":
					val = int(j)
				"string":
					val = j
				"color":
					val = Color(j)
				"colorN":
					val = ColorN(j)
		else:
			val = i
		
		if typeof(val) == TYPE_STRING:
			if val == "self":
				r.append(node)
			elif val[0] == "'" or val[0] == '"':
				r.append(val)
			else:
				var class_split: PoolStringArray = val.split(".", false)
				# TODO allow for multiple ".", probably needs to be recursive
				match class_split.size():
					1:
						r.append(current_root.find_instance(val))
					2:
						r.append(current_root.find_variable(class_split[0], class_split[1]))
		else:
			r.append(val)

	return r

func _handle_gdml(
	layout: GDML_Layout,
	pointer_pair_index: int,
	handled_pointer_pairs: Array,
	super_stack: GDML_Stack = null
) -> Control:
	if pointer_pair_index in handled_pointer_pairs:
		return null
	handled_pointer_pairs.append(pointer_pair_index)
	
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_WIDE)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_script(load(CONTROL_ROOT_PATH))

	var stack := GDML_Stack.new(root, super_stack)

	var pointer_pair: GDML_PointerData = layout.gdml_pointers[pointer_pair_index]
	
	var ignored_pointers := []

	# Skip the beginning and end pointers since those are the gdml open/close tags
	for i in range(pointer_pair.a + 1, pointer_pair.b):
		if i in ignored_pointers:
			continue
		var tag: GDML_Tag = layout.tags[i]
		if not tag.is_open and tag.name != GDML_Constants.GDML:
			continue

		var err := OK
		
		match tag.name:
			GDML_Constants.GDML:
				var inner_gdml_pointer_pair: GDML_PointerData = layout.gdml_pointers[
					pointer_pair_index + 1]
				ignored_pointers.append_array(
					range(inner_gdml_pointer_pair.a, inner_gdml_pointer_pair.b + 1))
				var gdml := _handle_gdml(layout, pointer_pair_index + 1, handled_pointer_pairs, stack)
				if gdml == null:
					err = ERR_PARSE_ERROR
				else:
					root.add_child(gdml)
			GDML_Constants.SCRIPT:
				err = _handle_script(root, tag)
			GDML_Constants.STYLE:
				err = _handle_style(root, tag)
			_:
				err = _handle_element(stack, tag)

		if err != OK:
			push_error("Error occurred when handling %s tag\n%s" % [tag.name, str(tag)])
			continue

	return root

func _handle_element(stack: GDML_Stack, tag: GDML_Tag) -> int:
	var object: Object

	var godot_class_name := tag.name.capitalize().replace(" ", "")
	if not ClassDB.class_exists(godot_class_name):
		push_error("Class does not exist %s" % godot_class_name)
		return ERR_INVALID_DATA

	object = ClassDB.instance(godot_class_name)

	if godot_class_name in TEXT_CONTROLS:
		object.text = tag.text

	stack.add_child(tag.depth, object)

	for key in tag.attributes.keys():
		var val = tag.attributes[key]

		var err := _handle_attribute(stack, object, key, val)
		if err != OK:
			push_error("Error occurred while handling attribute %s:%s - %d" % [key, val, err])
			continue

	return OK

func _handle_attribute(stack: GDML_Stack, object: Object, key: String, val: String) -> int:
	match key:
		GDML_Constants.NAME:
			object.set("name", val)
		GDML_Constants.SRC:
			var script: GDScript
			
			var root: Control = stack.get_root()
			while root != null:
				var instance: Object = root.find_instance(val)
				if instance == null:
					# TODO this causes an infinite loop because the superstack is a cyclic reference
					root = stack.get_super_root()
					continue
				
				var instance_script: GDScript = instance.get_script()
				if instance_script == null:
					root = stack.get_super_root()
					continue

				script = instance_script.duplicate()
				script.reload()
				if script == null:
					push_error("Failed to reload script from instance %s" % val)
					return ERR_INVALID_PARAMETER
				break
			
			if script == null:
				script = script_handler.handle_script_path(val)

			if script == null:
				push_error("Failed to find valid script for %s" % val)
				return ERR_INVALID_PARAMETER

			object.set_script(script)
		GDML_Constants.STYLE:
			if not object.is_class("Control"):
				push_warning("Tried to set style on a non-Control element: %s - %s" % [key, val])
				continue
			style_handler.handle_inline_style(object, val)
		GDML_Constants.CLASS:
			# TODO stub
			pass
		GDML_Constants.ID:
			# TODO stub
			pass

	return OK

func _handle_script(object: Object, tag: GDML_Tag) -> int:
	var script := script_handler.handle_script_tag(tag)
	if script == null:
		return ERR_INVALID_PARAMETER

	var desc := GDML_InstanceDescriptor.new()
	for key in tag.attributes.keys():
		desc.set(key, tag.attributes[key])

	return object.add_instance(script, desc)

func _handle_style(root: Control, tag: GDML_Tag) -> int:
	var themes := style_handler.handle_style(tag)
	if themes.empty():
		return ERR_PARSE_ERROR

	root.theme = themes["default"]

	return OK
