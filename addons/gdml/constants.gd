class_name GDML_Constants
extends Reference

#region Tags

# Creates a new root Control under the main output Control
const GDML := "gdml"
# Contains either a src attribute that contains a relative path to a script
# file or an entire script in the text node
const SCRIPT := "script"
# Contains either a src attribute that contains a relative path to a css
# file or an entire stylesheet in the text node
const STYLE := "style"

#endregion

#region Attributes

const NAME := "name"
# const STYLE := "style" # We already have a style attribute :D
const SRC := "src"
const CLASS := "class"
const ID := "id"

#endregion
