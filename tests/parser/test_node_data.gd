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

func test_get_as_dict():
	var nd := NodeData.new()
	nd.node_name = "test_name"
	nd.is_open = true
	nd.attributes["test_attribute"] = "woo"
	nd.attributes["other"] = "some_value"
	nd.text = "some_text"

	var nd_dict := nd.get_as_dict()
	
	assert_eq(nd_dict["node_name"], "test_name")
	assert_eq(nd_dict["is_open"], true)
	assert_eq(nd_dict["is_empty"], false)
	
	if assert_true(nd_dict["attributes"].has("test_attribute")):
		assert_eq(nd_dict["attributes"]["test_attribute"], "woo")
	
	if assert_true(nd_dict["attributes"].has("other")):
		assert_eq(nd_dict["attributes"]["other"], "some_value")

	assert_eq(nd_dict["text"], "some_text")
	assert_false(nd_dict["is_complete"])

func test_copy_as_close():
	var initial := NodeData.new()
	initial.node_name = "first"
	initial.is_open = true
	initial.attributes["something"] = "other"
	initial.text = "eh"

	var nd := NodeData.new()
	nd.copy_as_close(initial)

	assert_eq(nd.node_name, "first")
	assert_eq(nd.is_open, false)
	assert_false(nd.attributes.has("something"))
	assert_true(nd.text.empty())
