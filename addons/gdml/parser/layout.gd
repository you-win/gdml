extends Reference

const Error = preload("res://addons/gdml/error.gd")

const NodeData = preload("res://addons/gdml/parser/node_data.gd")
const Tag = preload("res://addons/gdml/parser/tag.gd")

var tags := []

var current_root: Tag
var current_tag: Tag
var finished := true

var depth: int = -1

func add_root_tag(data: NodeData) -> int:
	"""
	Follows a pseudo builder pattern. Must be finished processing before adding
	a new root tag
	"""
	if not finished:
		return Error.Code.NOT_FINISHED_PROCESSING_TAG

	finished = false
	depth = 0

	var tag := Tag.new(data, depth)
	
	current_root = tag
	current_tag = current_root

	return OK

func down(data: NodeData) -> int:
	"""
	Adds a new tag and continues processing as the new tag
	"""
	if current_tag == null:
		return Error.Code.NO_CURRENT_TAG

	depth += 1

	var tag := Tag.new(data, depth)
	current_tag.children.append(tag)
	tag.parent = current_tag

	current_tag = tag

	return OK

func up() -> int:
	"""
	Steps up into the parent tag
	"""
	depth -= 1

	if current_tag == current_root or depth < 0:
		return Error.Code.ALREADY_AT_ROOT_TAG

	current_tag = current_tag.parent

	return OK

func finish() -> int:
	"""
	Finalizes the current tag chain and appends it to the list of known tags
	"""
	if finished:
		return Error.Code.ALREADY_FINISHED

	finished = true
	depth = -1 # We don't zero this out so it's obvious when there's an error

	tags.append(current_root)

	current_root = null
	current_tag = null

	return OK
