extends Reference

const Constants = preload("res://addons/gdml/constants.gd")
const Error = preload("res://addons/gdml/error.gd")

const NodeData = preload("res://addons/gdml/parser/node_data.gd")
const Tag = preload("res://addons/gdml/parser/tag.gd")

const UNNESTABLE_TAGS := [Constants.SCRIPT, Constants.STYLE]

var tags := [] # Tag

#region Script hoist tracking

class Hoister:
	var gdml_location: int
	var gdml_depth: int

	var scripts := [] # Tag index in tags array

	func _init(p_gdml_location: int, p_gdml_depth: int) -> void:
		gdml_location = p_gdml_location
		gdml_depth = p_gdml_depth

	func apply(ref_dict: Dictionary) -> void:
		ref_dict[gdml_location] = scripts.duplicate()

var gdml_script_tags := {} # GDML location: int -> Script tags: Array[int]
var _hoist_stack := [] # Hoister

#endregion

var _depth: int = 0

func down(data: NodeData) -> int:
	"""
	Adds a new tag and continues processing as the new tag
	"""
	_depth += 1

	var tag := Tag.new(data.node_name, data.attributes, data.text, data.location, _depth)
	tag.depth = _depth

	# Some tags cannot be nested so they are unnested before processing
	# This is because there's no logical way to handle nesting in some cases
	#
	# Example:
	# <script>
	# 	<script>
	# 	</script>
	# </script>
	# The inner script tag could be applied to the outer script tag but what if
	# the out script tag is never created? Thus pretend like the tags are at the
	# same depth
	#
	# NOTE The Layout._depth is not modified, since the open/close tags
	# should still be properly tracked
	if tags.size() > 0 and tag in UNNESTABLE_TAGS:
		var last_tag: Tag = tags.back()
		if last_tag in UNNESTABLE_TAGS and last_tag.depth < tag.depth:
			tag.depth = last_tag.depth

	match tag.name:
		Constants.GDML:
			_hoist_stack.append(Hoister.new(tag.location, tag.depth))
		Constants.SCRIPT:
			# Pre-hoist scripts
			if _hoist_stack.empty():
				continue
			if _hoist_stack[-1].gdml_depth + 1 == tag.depth:
				_hoist_stack[-1].scripts.append(tag)

	tags.append(tag)

	return OK

func up(data: NodeData) -> int:
	"""
	Steps up into the parent tag
	"""
	_depth -= 1

	if _depth < -1:
		_depth = 0
		return Error.Code.HANGING_CLOSE_TAG

	match data.node_name:
		Constants.GDML:
			_hoist_stack.pop_back().apply(gdml_script_tags)

	return OK

func verify() -> int:
	if _depth != -1:
		return Error.Code.HANGING_OPEN_TAG
	
	if _hoist_stack.size() > 0:
		return Error.Code.HANGING_OPEN_TAG

	return OK
