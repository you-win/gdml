class_name GDML_Layout
extends Reference

var current_depth: int = 0
var tags := []

var gdml_pointers := [] # PointerData
var script_pointers := [] # int
var orphan_pointers := [] # int

func add_tag(name: String, attributes: Dictionary, text: String, is_open: bool) -> void:
	if is_open:
		current_depth += 1
	tags.append(GDML_Tag.new(name, attributes, text, is_open, current_depth))
	if not is_open:
		current_depth -= 1

func identify_tags() -> void:
	"""
	Identify all tag indices where there is no corresponding open/close tag
	pait at the same depth
	"""
	gdml_pointers.clear()
	script_pointers.clear()
	orphan_pointers.clear()

	var matched_pointers := []

	for tag_pointer in range(tags.size() - 1, -1, -1):
		if tag_pointer in matched_pointers:
			continue

		var gdml_a: int = -1
		var gdml_b: int = -1

		var script_a: int = -1
		var script_b: int = -1
		
		var close_tag: GDML_Tag = tags[tag_pointer]
		if close_tag.is_open:
			orphan_pointers.append(tag_pointer)

			if close_tag.name == GDML_Constants.SCRIPT:
				script_pointers.append(tag_pointer)
			continue

		if close_tag.name == GDML_Constants.GDML:
			gdml_b = tag_pointer
		elif close_tag.name == GDML_Constants.SCRIPT:
			script_b = tag_pointer
		
		var has_match := false
		for i in range(tag_pointer - 1, -1, -1):
			if i in matched_pointers:
				continue
		
			var open_tag: GDML_Tag = tags[i]
			if not open_tag.is_open:
				continue
			
			if open_tag.name == GDML_Constants.GDML:
				gdml_a = i
			elif open_tag.name == GDML_Constants.SCRIPT:
				script_a = i

			if close_tag.name == open_tag.name:
				matched_pointers.append(tag_pointer)
				matched_pointers.append(i)
				has_match = true
				break

		if not has_match:
			orphan_pointers.append(tag_pointer)

		if gdml_a != -1 and gdml_b != -1:
			gdml_pointers.append(GDML_PointerData.new(gdml_a, gdml_b))
		elif script_a != -1 and script_b != -1:
			script_pointers.append(script_a)
			# script_pointers.append(script_b)

func normalize_depth(orphan_pointer: int) -> void:
	for i in range(orphan_pointer + 1, tags.size()):
		var tag: GDML_Tag = tags[i]
		tag.depth -= 1

func reidentify_gdml_pointers() -> void:
	"""
	Initially, GDML tags will not match to the correct close tag because the
	depth is ignored on the first pass.

	After normalizing the depth, we need to compare every tag's depth again.
	"""
	var raw_gdml_pointers := []
	gdml_pointers.invert()
	for gdml_pointer in gdml_pointers:
		raw_gdml_pointers.append(gdml_pointer.a)
		raw_gdml_pointers.append(gdml_pointer.b)
	
	gdml_pointers.clear()
	raw_gdml_pointers.sort()

	var handled_pointers := []

	for idx in raw_gdml_pointers.size():
		var i: int = raw_gdml_pointers[idx]
		if i in handled_pointers:
			continue
		
		var open_gdml_pointer: GDML_Tag = tags[i]
		if not open_gdml_pointer.is_open:
			push_error("Unexpected gdml open tag %s" % str(open_gdml_pointer))
			continue

		for j in raw_gdml_pointers.slice(idx + 1, raw_gdml_pointers.size()):
			if j in handled_pointers:
				continue
			var close_gdml_pointer: GDML_Tag = tags[j]
			if close_gdml_pointer.is_open:
				continue

			if open_gdml_pointer.depth == close_gdml_pointer.depth:
				gdml_pointers.append(GDML_PointerData.new(i, j))
				handled_pointers.append(i)
				handled_pointers.append(j)
				break

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
			var tag: GDML_Tag = tags.pop_at(i)
			tags.insert(start + 1, tag)
