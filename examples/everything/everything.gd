extends CanvasLayer

var gui

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	var gdml = load("res://addons/gdml/gdml.gd").new("res://examples/everything/gui/")
	
	gdml.register_scene("CountUp", "res://examples/everything/count_up.tscn")
	gdml.register_scene("CountBackwards", "count_backwards.gd")
	gdml.register_scene("TextXml", "text.xml")
	
	gui = gdml.generate("everything.xml")
	
	add_child(gui)

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################
