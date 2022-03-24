extends Reference

const TSCN := "tscn"
const SCN := "scn"
const GDSCRIPT := "gd"
# const GDML := "gdml"
const XML := "xml"

#region Tags

# Creates a new root Control under the main output Control
const GDML := "gdml"
# Contains either a src attribute that contains a relative path to a script
# file or an entire script in the text node
const SCRIPT := "gdml_script"
# Contains either a src attribute that contains a relative path to a css
# file or an entire stylesheet in the text node
const STYLE := "gdml_style"
# Group tags together at the group tag's depth
# For organizational purposes
const GROUP := "gdml_group"

#endregion

#region Attributes

const NAME := "gdml_name"
# const STYLE := "style" # We already have a style attribute :D
const SRC := "gdml_src"
const SOURCE := "gdml_source"
# Alias of STYLE
const PROPS := "gdml_props"

# Whether to attach a script the the parent tag or not
# Assumed to be false by default
# If specified to be true, the script will be processed and then discarded
const TEMP := "gdml_temp"

const CAST := "gdml_cast"

const CLASS := "gdml_class"
const ID := "gdml_id"

#endregion

#region Handlers

const SCRIPT_NAME_TEMPLATE := "Script_%d"

#endregion
