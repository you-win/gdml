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
# Group tags together at the group tag's depth
# For organizational purposes
const GROUP := "group"

#endregion

#region Attributes

const NAME := "name"
# const STYLE := "style" # We already have a style attribute :D
const SRC := "src"

# Whether to attach a script the the parent tag or not
# Assumed to be true by default
# If specified to be false, the script will be processed and then discarded
const ATTACH := "attach"

const CLASS := "class"
const ID := "id"

#endregion

#region Handlers

const SCRIPT_NAME_TEMPLATE := "Script_%d"

#endregion
