extends "res://addons/gut/test.gd"

###############################################################################
# Builtin functions                                                           #
###############################################################################

func before_all():
	pass

func before_each():
	pass

func after_each():
	pass

func after_all():
	pass

###############################################################################
# Utils                                                                       #
###############################################################################

func assert_ok(value: int) -> bool:
	assert_eq(value, OK)
	return value == OK

func assert_eq(a, b, _text = "") -> bool:
	.assert_eq(a, b)
	return a == b

func assert_true(value: bool, _text = "") -> bool:
	.assert_true(value)
	return value

###############################################################################
# Tests                                                                       #
###############################################################################
