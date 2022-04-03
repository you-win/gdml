extends "./abstract_handler.gd"

const CONTROL_DIRECTIONS := ["top", "bottom", "left", "right"]

const CssProcessor = preload("../../godot-css-theme/css_processer.gd")

func _init(p_context_path: String).(p_context_path) -> void:
	pass

func handle_style(data) -> Dictionary:
	var css_processor = CssProcessor.new()

	var input := ""

	if data.attributes.has("src"):
		var file := File.new()
		if file.open("%s/%s" % [context_path, data.attributes["src"]], File.READ) != OK:
			push_error("Failed to open %s" % "%s/%s" % [context_path, data.attributes["src"]])
			return {}

		input = file.get_as_text()
	else:
		input = data.text

	var stylesheet_name: String = data.attributes.get("name", "")
	if stylesheet_name.empty() and data.attributes.has("src"):
		stylesheet_name = data.attributes["src"].get_file()

	css_processor.generate(input, stylesheet_name)

	if css_processor.output == null:
		push_error("Failed to parse node %s" % data.node_name)
		return {}

	return css_processor.output

func handle_inline_style(node: Object, raw_style: String) -> void:
	raw_style = raw_style.replace(" ", "").strip_escapes()
	var styles := raw_style.split(";", false)

	for style in styles:
		var split_style: PoolStringArray = style.rsplit(":", false, 1)

		if split_style.size() != 2:
			push_error("Unexpected style attribute %s for %s" % [style, node.name])
			continue

		var key: String = split_style[0].strip_edges()
		var val: String = split_style[1].replace(" ", "").strip_edges()

		match key:
			"anchor":
				if val == "full_rect" and node.is_class("Control"):
					node.set_anchors_preset(Control.PRESET_WIDE)
				else:
					for i in CONTROL_DIRECTIONS:
						node.set("anchor_%s" % i, float(val))
			"margin":
				for i in CONTROL_DIRECTIONS:
					node.set("margin_%s" % i, float(val))
			_:
				var split_val := val.split(")")
				if split_val.size() == 2:
					val = split_val[1].replace(" ", "")
					match split_val[0].replace(" ", "").lstrip("("):
						"float":
							node.set_indexed(key, float(val))
						"int", "integer":
							node.set_indexed(key, int(val))
						"bool", "boolean":
							node.set_indexed(key, bool(val))
						"string":
							node.set_indexed(key, val)
						"color", "Color":
							node.set_indexed(key, Color(val))
						"colorN", "ColorN":
							node.set_indexed(key, ColorN(val))
				else:
					# Try and figure out the type
					var node_var = node.get_indexed(key)
					if node_var == null:
						push_error("Key %s does not exist for style %s" % [key, raw_style])
						continue
					match typeof(node_var):
						TYPE_REAL:
							node.set_indexed(key, float(val))
						TYPE_INT:
							node.set_indexed(key, int(val))
						TYPE_BOOL:
							node.set_indexed(key, bool(val))
						TYPE_STRING:
							node.set_indexed(key, val)
						_:
							push_error("Unsupported variable type for key - val: %s - %s" % [
								key, val
							])
