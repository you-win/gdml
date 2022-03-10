extends Reference

var Tags = preload("res://addons/gdml/tags.gd").new()

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

class PointerData:
	var a: int = -1
	var b: int = -1

	func _init(p_a: int, p_b: int) -> void:
		a = p_a
		b = p_b

var current_depth: int = 0
var tags := []

var gdml_pointers := [] # PointerData
var script_pointers := [] # int
var orphan_pointers := [] # int

func add_tag(name: String, attributes: Dictionary, text: String, is_open: bool) -> void:
	if is_open:
		current_depth += 1
	tags.append(Tag.new(name, attributes, text, is_open, current_depth))
	if not is_open:
		current_depth -= 1

func identify_tags() -> void:
	"""
	Identify all tag indices where there is no corresponding open/close tag
	pait at the same depth
	"""

	var matched_pointers := []

	for tag_pointer in range(tags.size() - 1, -1, -1):
		if tag_pointer in matched_pointers:
			continue

		var gdml_a: int = -1
		var gdml_b: int = -1

		var script_a: int = -1
		var script_b: int = -1
		
		var close_tag: Tag = tags[tag_pointer]
		if close_tag.is_open:
			orphan_pointers.append(tag_pointer)

			if close_tag.name == Tags.SCRIPT:
				script_pointers.append(tag_pointer)
			continue

		if close_tag.name == Tags.GDML:
			gdml_b = tag_pointer
		elif close_tag.name == Tags.SCRIPT:
			script_b = tag_pointer
		
		var has_match := false
		for i in range(tag_pointer - 1, -1, -1):
			if i in matched_pointers:
				continue
		
			var open_tag: Tag = tags[i]
			if not open_tag.is_open:
				continue
			
			if open_tag.name == Tags.GDML:
				gdml_a = i
			elif open_tag.name == Tags.SCRIPT:
				script_a = i

			if close_tag.name == open_tag.name:
				matched_pointers.append(tag_pointer)
				matched_pointers.append(i)
				has_match = true
				break

		if not has_match:
			orphan_pointers.append(tag_pointer)

		if gdml_a != -1 and gdml_b != -1:
			gdml_pointers.append(PointerData.new(gdml_a, gdml_b))
		elif script_a != -1 and script_b != -1:
			script_pointers.append(script_a)

func normalize_depth(orphan_pointer: int) -> void:
	for i in range(orphan_pointer + 1, tags.size()):
		var tag: Tag = tags[i]
		tag.depth -= 1

func hoist_scripts() -> void:
	for gdml_pointer in gdml_pointers:
		var start: int = gdml_pointer.a
		var end: int = gdml_pointer.b

		var pointers_to_hoist := []

		for script_pointer in script_pointers:
			if script_pointer < start or script_pointer > end:
				continue
			
			pointers_to_hoist.append(script_pointer)

		# Hoist tags in reverse order so that scripts defined earlier in the file take precedence
		pointers_to_hoist.invert()

		for i in pointers_to_hoist:
			var tag: Tag = tags.pop_at(i)
			tags.insert(start + 1, tag)
