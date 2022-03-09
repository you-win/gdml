extends Reference

const FILE_OPEN_FAILURE_TEMPLATE := "Failed to open %s"
const PARSE_FAILURE_TEMPLATE := "Failed to parse element %s"

const CSS_PROCESSOR_PATH := "res://addons/gdml/css_processer.gd"

const ANCHOR_DIRECTIONS := ["top", "bottom", "left", "right"]

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

	var stack := Stack.new()

	var current_root: Control

	while true:
		var data = reader.read_node()
		
		if not data.node_name.empty():
			var node_name: String = data.node_name
			if data.is_open:
				stack.push(node_name)
				match node_name:
					Element.GDML:
						if current_root != null:
							output.add_child(current_root)
						current_root = Control.new()
						current_root.set_anchors_preset(Control.PRESET_WIDE)
					Element.SCRIPT:
						var script := _handle_script(data)
						if script == null:
							continue

						# TODO test
						if data.attributes.has("name"):
							var test = script.new()
							print(test.add_one(2))
						else:
							var test = script.new()
							print(test.give_test())
						# TODO stub
					Element.STYLE:
						var themes := _handle_style(data)
						if themes.empty():
							continue

						# TODO test
						current_root.theme = themes["default"]

						# TODO stub
					_:
						var godot_class_name := (node_name as String).capitalize().replace(" ", "")
						if not ClassDB.class_exists(godot_class_name):
							push_error("Class does not exist %s" % godot_class_name)
							continue
						
						var node = ClassDB.instance(godot_class_name)
						current_root.add_child(node)

						if godot_class_name == "Label":
							node.text = data.text

						for key in data.attributes.keys():
							var attr = data.attributes[key]

							match key:
								"name":
									node.name = attr
								"style":
									_handle_inline_style(node, attr)
			else:
				stack.remove(node_name)

		if data.is_complete:
			break

	output.add_child(current_root)
	output.set_anchors_preset(Control.PRESET_WIDE)

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

		var split_property: PoolStringArray = split_style[0].split("-", false)
		var value: String = split_style[1]

		match split_property[0]:
			"anchor":
				if split_property.size() > 1:
					var anchor_direction: String = split_property[1]
					
					if not anchor_direction in ANCHOR_DIRECTIONS:
						push_error("Invalid anchor direction %s" % anchor_direction)
						continue
					if not value.is_valid_float():
						push_error("Invalid value for %s" % style)
						continue
					
					node.set("anchor_%s" % anchor_direction, float(value))
				else:
					if value == "full-rect":
						node.set_anchors_preset(Control.PRESET_WIDE)
					else:
						if not value.is_valid_float():
							push_error("Invalid value for %s" % style)
							continue
						for i in ANCHOR_DIRECTIONS:
							node.set("anchor_%s" % i, float(value))
