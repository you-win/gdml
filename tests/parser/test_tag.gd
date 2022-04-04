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

const Tag = preload("res://addons/gdml/parser/tag.gd")

func test_get_as_dict():
	var tag := Tag.new(
		"test_tag",
		{
			"some": "thing"
		},
		"some_text",
		1,
		2
	)

	assert_eq(tag.name, "test_tag")
	assert_eq(tag.attributes["some"], "thing")
	assert_eq(tag.text, "some_text")
	assert_eq(tag.location, 1)
	assert_eq(tag.depth, 2)
