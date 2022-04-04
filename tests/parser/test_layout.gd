extends "res://tests/base_test.gd"

# https://github.com/bitwes/Gut/wiki/Quick-Start

###############################################################################
# Builtin functions                                                           #
###############################################################################

func before_all():
	.before_all()

func before_each():
	pass

func after_each():
	pass

func after_all():
	pass

###############################################################################
# Utils                                                                       #
###############################################################################

###############################################################################
# Tests                                                                       #
###############################################################################

const NodeData = preload("res://addons/gdml/parser/node_data.gd")
const Tag = preload("res://addons/gdml/parser/tag.gd")
const Layout = preload("res://addons/gdml/parser/layout.gd")

func test_hoister():
	var hoister := Layout.Hoister.new(1, 1)
	hoister.scripts.append(1)
	hoister.scripts.append(3)
	hoister.scripts.append(10)

	var ref_dict := {}

	hoister.apply(ref_dict)

	if assert_true(ref_dict.has(1)):
		assert_true(ref_dict[1].has(1))
		assert_true(ref_dict[1].has(3))
		assert_true(ref_dict[1].has(10))
		
		assert_false(ref_dict[1].has(2))

func test_down():
	var layout := Layout.new()

	var gdml_nd := NodeData.new()
	gdml_nd.node_name = "gdml"
	gdml_nd.attributes = {
		"style": "margin: full_rect"
	}
	gdml_nd.location = 1

	if not assert_ok(layout.down(gdml_nd)):
		return
	
	if not assert_eq(layout._hoist_stack.size(), 1):
		return

	var hoister: Layout.Hoister = layout._hoist_stack[0]
	assert_eq(hoister.gdml_location, 1)
	assert_eq(hoister.gdml_depth, 1)

	if not assert_eq(layout.tags.size(), 1):
		return
	
	var tag: Tag = layout.tags[0]
	assert_eq(tag.name, "gdml")
	if not assert_true(tag.attributes.has("style")):
		return
	assert_eq(tag.attributes["style"], "margin: full_rect")
	assert_eq(tag.location, 1)
