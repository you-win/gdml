extends "./abstract_handler.gd"

const Error = preload("../../error.gd")
const Constants = preload("../../constants.gd")

const Tag = preload("../../parser/tag.gd")

# Needed for cleaning input
# Should match against tabs/spaces
var _whitespace_regex: RegEx

func _init(p_context_path: String).(p_context_path) -> void:
	_whitespace_regex = RegEx.new()
	_whitespace_regex.compile("\\B(\\s+)\\b")

func handle_tag(tag: Tag, script_name: String, empty_script: GDScript) -> int:
	var input := tag.text

	if tag.attributes.has(Constants.SRC):
		var file_name: String = tag.attributes[Constants.SRC]

		var file := File.new()
		if file.open("%s/%s" % [context_path, file_name], File.READ) != OK:
			return Error.Code.FILE_OPEN_FAILURE

		input = file.get_as_text()

	input = _clean_input(input)

	empty_script.source_code = input
	if empty_script.reload() != OK:
		return Error.Code.BAD_SCRIPT_TEXT
	
	return OK

func _clean_input(text: String) -> String:
	"""
	Text might be prepended with tabs in order to line up with xml. This will not
	parse correctly, so remove tabs based off of the first line.
	
	NOTE: This will break if spaces/tabs are mixed. It's also not my problem ;)
	"""
	var r := ""

	var split_text := text.split("\n")
	if split_text.empty():
		push_error("Unable to split text %s" % text)
		return text

	var first_line := ""
	for i in split_text:
		first_line = i
		if not first_line.strip_edges().empty():
			break
	# The first line should not have any tabs at all, so any tabs there can be assumed
	# to also be uniformly applied to the other lines
	# It's also possible spaces are used instead of tabs, so check for spaces as well
	var regex_match := _whitespace_regex.search(first_line)
	if regex_match == null:
		# Nothing needs to be cleaned
		return text

	var empty_prefix: String = regex_match.get_string()

	for i in split_text:
		# We can guarantee that the string will always be empty and, after the first iteration,
		# will always have a proper new line character
		r = "%s%s\n" % [r, i.trim_prefix(empty_prefix)]

	return r
