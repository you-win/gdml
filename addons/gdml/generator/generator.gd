class_name GDML_Generator
extends Reference

const OUTPUT_NAME := "GDML"

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _init() -> void:
	pass

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

func _generate(super, tag: GDML_Tag):
	match tag.name:
		GDML_Constants.GDML:
			pass
		GDML_Constants.SCRIPT:
			pass
		GDML_Constants.STYLE:
			pass
		_:
			pass

###############################################################################
# Public functions                                                            #
###############################################################################

func generate(layout: GDML_Layout) -> Control:
	var r := Control.new()
	r.set_anchors_preset(Control.PRESET_WIDE)
	r.name = OUTPUT_NAME

	for tag in layout.tags: # GDML_Tag
		pass

	return r
