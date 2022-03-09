extends Reference

const FILE_OPEN_FAILURE_TEMPLATE := "Failed to open %s"
const PARSE_FAILURE_TEMPLATE := "Failed to parse element %s"

const CSS_PROCESSOR_PATH := "res://addons/gdml/css_processer.gd"

const CONTROL_DIRECTIONS := ["top", "bottom", "left", "right"]
const TEXT_CONTROLS := ["Label", "Button", "LineEdit", "TextEdit"]

const Element := {
	# Creates a new root Control under the main output Control
	"GDML": "gdml",
	# Contains either a src attribute that contains a relative path to a script
	# file or an entire script in the text node
	"SCRIPT": "script",
	# Contains either a src attribute that contains a relative path to a css
	# file or an entire stylesheet in the text node
	"STYLE": "style"
}

class Layout:
	class Tag:
		var name := ""
		var attributes := {}
		var text := ""

		var is_open := false
		var depth: int = -1

		func _init(p_name: String, p_attributes: Dictionary, p_text: String, p_is_open: bool, p_depth: int) -> void:
			name = p_name
			attributes = p_attributes
			text = p_text
			is_open = p_is_open
			depth = p_depth
		
		func _to_string() -> String:
			return JSON.print(get_as_dict(), "\t")

		func get_as_dict() -> Dictionary:
			return {
				"name": name,
				"attributes": attributes,
				"text": text,
				"is_open": is_open,
				"depth": depth
			}

	var current_depth: int = 0
	var tags := []

	func add_tag(name: String, attributes: Dictionary, text: String, is_open: bool) -> void:
		if is_open:
			current_depth += 1
		tags.append(Tag.new(name, attributes, text, is_open, current_depth))
		if not is_open:
			current_depth -= 1

	func identify_orphans() -> Array:
		"""
		Identify all tag indices where there is no corresponding open/close tag
		pait at the same depth
		"""
		var orphan_pointers := []

		var matched_pointers := []

		for tag_pointer in range(tags.size() - 1, -1, -1):
			if tag_pointer in matched_pointers:
				continue
			
			var close_tag: Tag = tags[tag_pointer]
			if close_tag.is_open:
				orphan_pointers.append(tag_pointer)
				continue
			
			var has_match := false
			for i in range(tag_pointer - 1, -1, -1):
				if i in matched_pointers:
					continue
			
				var open_tag: Tag = tags[i]
				if not open_tag.is_open:
					continue

				if close_tag.name == open_tag.name:
					matched_pointers.append(tag_pointer)
					matched_pointers.append(i)
					has_match = true
					break

			if not has_match:
				orphan_pointers.append(tag_pointer)

		return orphan_pointers

	func normalize_depth(orphan_pointer: int) -> void:
		for i in range(orphan_pointer + 1, tags.size()):
			var tag: Tag = tags[i]
			tag.depth -= 1

class Stack:
	var _stack := []

	func push(node_name: String) -> void:
		_stack.push_back(node_name)

	func remove(node_name: String) -> void:
		var pop_count: int = 1
		for i in range(_stack.size() - 1, 1, -1):
			if _stack[i] != node_name:
				pop_count += 1
			break

		for i in pop_count:
			_stack.pop_back()

	func depth() -> int:
		return _stack.size()

var context_path := ""

var output := Control.new()

func _init(input: String, p_context_path: String) -> void:
	context_path = ProjectSettings.globalize_path(p_context_path)

	var is_path := true
	if input.is_abs_path():
		input = ProjectSettings.globalize_path(input)
	elif input.is_rel_path():
		if context_path.empty():
			push_error("A context_path is required when using a relative path")
			return
		input = "%s/%s" % [input, context_path]
	else: # The result of File.get_as_text()
		is_path = false
	
	var reader = load("res://addons/gdml/reader.gd").new()
	var err = reader.read_path(input) if is_path else reader.read_buffer(input.to_utf8())
	if err != OK:
		push_error("Error %d occurred while opening %s" % [err, input if is_path else "buffer"])
		return
	
	var layout := Layout.new()

	var current_root: Control

	while true:
		var data = reader.read_node()

		if data.is_complete:
			break

		if not data.node_name.empty():
			layout.add_tag(data.node_name, data.attributes, data.text, data.is_open)

	var orphan_pointers := layout.identify_orphans()
	for i in orphan_pointers:
		layout.normalize_depth(i)

	var previous_depth: int = 0
	var stack := [output]

	for tag in layout.tags:
		if not tag.is_open:
			continue
		var node_name: String = tag.name
		match node_name:
			Element.SCRIPT:
				var script := _handle_script(tag)
				if script == null:
					continue

				# TODO test
				if tag.attributes.has("name"):
					var test = script.new()
					print(test.add_one(2))
				else:
					var test = script.new()
					print(test.give_test())
				# TODO stub
			Element.STYLE:
				var themes := _handle_style(tag)
				if themes.empty():
					continue

				# TODO test
				current_root.theme = themes["default"]

				# TODO stub
			_:
				var node: Node
				if node_name == Element.GDML:
					node = Control.new()
					node.set_anchors_preset(Control.PRESET_WIDE)

					current_root = node
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

				# current_root.add_child(node)

				for key in tag.attributes.keys():
					var attr = tag.attributes[key]

					match key:
						"name":
							node.name = attr
						"style":
							_handle_inline_style(node, attr)

	# output.add_child(current_root)
	output.set_anchors_preset(Control.PRESET_WIDE)
	output.name = "GDML"

func _handle_script(data) -> GDScript:
	var input := ""

	if data.attributes.has("src"):
		var file := File.new()
		if file.open("%s/%s" % [context_path, data.attributes["src"]], File.READ) != OK:
			push_error(FILE_OPEN_FAILURE_TEMPLATE % "%s/%s" % [context_path, data.attributes["src"]])
			return null

		input = file.get_as_text()
	else:
		input = data.text

	var script := GDScript.new()
	script.source_code = input
	if script.reload() != OK:
		push_error(PARSE_FAILURE_TEMPLATE % data.node_name)
		return null

	return script

func _handle_style(data) -> Dictionary:
	var css_processor = load(CSS_PROCESSOR_PATH).new()

	var input := ""

	if data.attributes.has("src"):
		var file := File.new()
		if file.open("%s/%s" % [context_path, data.attributes["src"]], File.READ) != OK:
			push_error(FILE_OPEN_FAILURE_TEMPLATE % "%s/%s" % [context_path, data.attributes["src"]])
			return {}

		input = file.get_as_text()
	else:
		input = data.text

	var stylesheet_name: String = data.attributes.get("name", "")
	if stylesheet_name.empty() and data.attributes.has("src"):
		stylesheet_name = data.attributes["src"].get_file()

	css_processor.generate(input, stylesheet_name)

	if css_processor.output == null:
		push_error(PARSE_FAILURE_TEMPLATE % data.node_name)
		return {}

	return css_processor.output

func _handle_inline_style(node: Control, raw_style: String) -> void:
	raw_style = raw_style.replace(" ", "")
	var styles := raw_style.split(";", false)

	for style in styles:
		var split_style: PoolStringArray = style.split(":", false)

		if split_style.size() != 2:
			push_error("Unexpected style attribute %s" % style)
			continue

		var key: String = split_style[0].strip_edges()
		var val: String = split_style[1].strip_edges()

		match key:
			"anchor":
				if val == "full_rect":
					node.set_anchors_preset(Control.PRESET_WIDE)
				else:
					for i in CONTROL_DIRECTIONS:
						node.set("anchor_%s" % i, float(val))
			"margin":
				for i in CONTROL_DIRECTIONS:
					node.set("margin_%s" % i, float(val))
			_:
				var split_val := val.split("=")
				if split_val.size() == 2:
					val = split_val[1]
					match split_val[0]:
						"float":
							node.set_indexed(key, float(val))
						"int":
							node.set_indexed(key, int(val))
						"string":
							node.set_indexed(key, val)
						"color":
							node.set_indexed(key, Color(val))
						"colorN":
							node.set_indexed(key, ColorN(val))
				else:
					node.set_indexed(key, float(val))
