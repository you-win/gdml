extends Reference

const TEXT_CONTROLS := ["Label", "Button", "LineEdit", "TextEdit"]
const CONTROL_ROOT_PATH := "res://addons/gdml/control_root.gd"

const Layout = preload("res://addons/gdml/layout.gd")
const Reader = preload("res://addons/gdml/reader.gd")

const InstanceDescriptor = preload("res://addons/gdml/instance_descriptor.gd")

const ScriptHandler = preload("res://addons/gdml/handlers/script_handler.gd")
const StyleHandler = preload("res://addons/gdml/handlers/style_handler.gd")

var Tags = preload("res://addons/gdml/tags.gd").new()

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
	
	var reader = Reader.new()
	var err = reader.read_path(input) if is_path else reader.read_buffer(input.to_utf8())
	if err != OK:
		push_error("Error %d occurred while opening %s" % [err, input if is_path else "buffer"])
		return output

	var layout := _prepass(reader)
	
	var script_handler = ScriptHandler.new(context_path)
	var style_handler = StyleHandler.new(context_path)

	var previous_depth: int = 0
	var stack := [output]
	
	var current_root: Control

	for tag in layout.tags:
		if not tag.is_open:
			continue
		var node_name: String = tag.name
		match node_name:
			Tags.SCRIPT:
				var script: GDScript = script_handler.handle_script(tag)
				if script == null:
					continue

				# TODO stub
				var desc := InstanceDescriptor.new()
				for key in tag.attributes.keys():
					desc.set(key, tag.attributes[key])

				current_root.add_instance(script, desc)
			Tags.STYLE:
				var themes: Dictionary = style_handler.handle_style(tag)
				if themes.empty():
					continue

				# TODO test
				current_root.theme = themes["default"]

				# TODO stub
			_:
				# Everything else is a node
				# Technically they should all be Controls, but I'm not the boss of you
				var node: Node
				if node_name == Tags.GDML:
					node = Control.new()
					node.set_anchors_preset(Control.PRESET_WIDE)
					node.mouse_filter = Control.MOUSE_FILTER_IGNORE

					current_root = node
					current_root.set_script(load(CONTROL_ROOT_PATH))

					# Reset stack
					previous_depth = 0
					while stack.size() > 1:
						stack.pop_back()
				else:
					var godot_class_name := (node_name as String).capitalize().replace(" ", "")
					if not ClassDB.class_exists(godot_class_name):
						push_error("Class does not exist %s" % godot_class_name)
						continue
					
					node = ClassDB.instance(godot_class_name)

					if godot_class_name in TEXT_CONTROLS:
						node.text = tag.text
				
				# Stack management
				if previous_depth < tag.depth:
					stack[-1].add_child(node)
					stack.append(node)
					previous_depth = tag.depth
				elif previous_depth == tag.depth:
					stack.pop_back()
					stack[-1].add_child(node)
					stack.push_back(node)
				else:
					stack.pop_back()
					stack.pop_back()
					stack[-1].add_child(node)
					previous_depth = tag.depth

				for key in tag.attributes.keys():
					var val = tag.attributes[key]

					match key:
						"name":
							node.name = val
						"style":
							style_handler.handle_inline_style(node, val)
						"src":
							# TODO stub
							pass
						_:
							if node.has_signal(key) or node.has_user_signal(key):
								var split_val: PoolStringArray = val.split(".", false, 1)

								match split_val.size():
									1:
										err = current_root.find_and_connect(key, node, val)
										if err != OK:
											push_error("Error occurred when connecting %d" % err)
											continue
									2:
										var args = _generate_connect_args(current_root, node, split_val[1])
										var callback_name := split_val[1].split("[")[0] if args.size() > 0 else split_val[1]

										err = current_root.direct_connect(split_val[0], key, node, callback_name, args)
										if err != OK:
											push_error("Error occurred when connecting %d" % err)
											continue
									_:
										push_error("Invalid callback for %s: %s - %s" %
											[node_name, key, val])
								

	output.set_anchors_preset(Control.PRESET_WIDE)
	output.name = "GDML"

	return output

func _prepass(reader: Reader) -> Layout:
	var layout := Layout.new() 

	while true:
		var data = reader.read_node()

		if data.is_complete:
			break

		if not data.node_name.empty():
			layout.add_tag(data.node_name, data.attributes, data.text, data.is_open)

	layout.identify_tags()
	for i in layout.orphan_pointers:
		layout.normalize_depth(i)

	layout.hoist_scripts()

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
						r.append(current_root.find_class(val))
					2:
						r.append(current_root.find_variable(class_split[0], class_split[1]))
		else:
			r.append(val)

	return r
