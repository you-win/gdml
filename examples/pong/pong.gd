extends Node

var gdml = load("res://addons/gdml/gdml.gd")

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	var generator = gdml.new("res://examples/pong/")
	
	add_child(generator.generate("pong.xml"))

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################
