class_name GDML_Layout
extends Reference

var tags := []

var current_root: GDML_Tag
var current_tag: GDML_Tag
var finished := true

func add_root_tag(data: GDML_NodeData) -> int:
	"""
	Follows a pseudo builder pattern. Must be finished processing before adding
	a new root tag
	"""
	if not finished:
		return GDML_Error.Code.NOT_FINISHED_PROCESSING_TAG

	finished = false

	var tag := GDML_Tag.new(data)
	
	current_root = tag
	current_tag = current_root

	return OK

func down(data: GDML_NodeData) -> int:
	"""
	Adds a new tag and continues processing as the new tag
	"""
	if current_tag == null:
		return GDML_Error.Code.NO_CURRENT_TAG

	var tag := GDML_Tag.new(data)
	current_tag.children.append(tag)
	tag.parent = current_tag

	current_tag = tag

	return OK

func up() -> int:
	"""
	Steps up into the parent tag
	"""
	if current_tag == current_root:
		return GDML_Error.Code.ALREADY_AT_ROOT_TAG

	current_tag = current_tag.parent

	return OK

func finish() -> int:
	"""
	Finalizes the current tag chain and appends it to the list of known tags
	"""
	if finished:
		return GDML_Error.Code.ALREADY_FINISHED

	finished = true

	tags.append(current_root)

	current_root = null
	current_tag = null

	return OK
