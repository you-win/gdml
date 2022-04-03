const Stylesheet = preload("./stylesheet.gd")

var _values = {}

func parse(file_path: String) -> Stylesheet:
	_values = {}
	var file = File.new()
	if not file.file_exists(file_path):
		print("File %s does not exist" % file_path)
		return null

	if not file_path.ends_with(".css"):
		print("File %s is not a css file" % file_path)
		return null

	if file.open(file_path, File.READ) != OK:
		print("Failed to open file %s" % file_path)
		return null

	var content: String = file.get_as_text()  # TODO: use buffer?
	file.close()
	return parse_text(content, file_path)


func parse_text(content: String, path: String):
	var current_classes := {}
	var processed_length := 0

	while processed_length < content.length():
		var start_block := content.find("{", processed_length)
		if start_block == -1:
			break

		var classes_line := content.substr(processed_length, start_block - processed_length)
		current_classes = _parse_classes(classes_line)
		processed_length += (classes_line + "{").length()

		var end_block = content.find("}", processed_length)
		if end_block == -1:
			print("Missing closing bracket after length %s" % processed_length)
			return null

		var block = content.substr(processed_length, end_block - processed_length)
		if _parse_block(current_classes, block):
			processed_length += (block + "}").length()
			current_classes = {}
		else:
			return null

	var result = {"": {}}
	for tag in _values.keys():
		if not tag:
			continue
		var value = _values[tag]
		if "." in tag:
			var split = tag.split(".")
			var actual_tag = split[0]
			var class_group = split[1]

			if not actual_tag:
				continue

			if not class_group in result:
				result[class_group] = {}

			result[class_group][actual_tag] = value
		else:
			result[""][tag] = value

	return Stylesheet.new(result, path)


func _parse_classes(line: String) -> Dictionary:
	var result = {}
	var classes = line.split(",")
	for cls in classes:
		var trimmed: String = cls.strip_edges()
		if trimmed.length() > 0:
			var split = trimmed.split(":")
			var state = split[1].strip_edges() if split.size() == 2 else Stylesheet.DEFAULT_STATE
			var key = split[0].strip_edges()
			if not result.has(key):
				result[key] = []
			result[key].append(state)
	return result


func _parse_block(classes: Dictionary, block: String) -> bool:
	var statements = block.split(";")
	for statement in statements:
		if statement.strip_edges() == "":
			continue

		var split: Array = statement.split(":", true, 1)  # limit is zero-based?
		if split.size() != 2:
			print("Invalid statement: %s" % statement)
			return false

		var property = split[0].strip_edges()
		var value = split[1].strip_edges()

		for cls in classes:
			if not _values.has(cls):
				_values[cls] = {}

			var states = classes[cls]
			for state in states:
				if not _values[cls].has(state):
					_values[cls][state] = {}
				_values[cls][state][property] = value
	return true
