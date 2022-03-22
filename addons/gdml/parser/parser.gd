extends Reference

const Error = preload("res://addons/gdml/error.gd")

const Layout = preload("res://addons/gdml/parser/layout.gd")
const NodeData = preload("res://addons/gdml/parser/node_data.gd")
const Reader = preload("res://addons/gdml/parser/reader.gd")
const Tag = preload("res://addons/gdml/parser/tag.gd")

var context_path := ""

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _init(p_context_path: String = "") -> void:
	context_path = p_context_path

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

func _process_nodes(reader: Reader) -> Array:
	"""
	Processes nodes for a given file in 3 steps

	1. Reads all nodes in the reader. Hanging close nodes are dropped.
	2. Identify hanging open nodes
	3. Insert appropriate close nodes for each hanging open node
	
	NOTE: There are 2 `is_complete` checks at 2 different points. Occasionally, the reader
	will reach the end of the file but still return valid node data (aka the last tag).
	1. The reader returns valid node data for the first time and it's also the end of the file
	2. The reader returns bad node data and it's the end of the file
	
	For situation 2, this is caught in the reader and empty node data is manually returned

	Params:
		reader: GDML_Reader - The reader for the given data. Should come preloaded with the data

	Returns:
		Array - An Array containing GDML_NodeData objects
	"""
	var node_stack := []

	var open_close_stack := {} # Tag name: String -> Stack: Array
	var node_location: int = -1

	while true:
		var data: NodeData = reader.read_node()
		
		if data.node_name.empty():
			if not data.text.empty():
				# We ran into a comment, so just add the text body to the previous tag
				var node_name := ""
				var counter: int = -1
				while abs(counter) < node_stack.size():
					var previous_data: NodeData = node_stack[counter]
					if previous_data.is_open and node_name.empty():
						previous_data.text += data.text
						break
					elif not previous_data.is_open:
						node_name = previous_data.node_name
					elif previous_data.is_open and previous_data.node_name == node_name:
						node_name = ""
					# Count backwords through the node stack
					counter -= 1
			
			# Occasionally the parser will return bad data depending on the EOF newlines
			if data.is_complete:
				break
			# Always skip to the next tag since there's no way to process an empty tag anyways
			continue

		node_location += 1
		data.location = node_location

		var node_name := data.node_name

		if not open_close_stack.has(node_name):
			open_close_stack[node_name] = []

		var stack: Array = open_close_stack[node_name]

		if data.is_open:
			stack.append(data)
			node_stack.append(data)
		else:
			var open_node: NodeData = stack.pop_back()
			if open_node == null:
				push_warning("No matching open node found for %s at location %d" % [node_name, node_location])
				# Decrement here because we discard the tag
				node_location -= 1
				continue

			node_stack.append(data)
		
		if data.is_complete:
			break

	var hanging_open_node_indices := []

	for tag_name in open_close_stack.keys():
		var stack: Array = open_close_stack[tag_name]

		if stack.size() > 0:
			for i in stack: # NodeData
				hanging_open_node_indices.append(i.location)
	
	hanging_open_node_indices.sort()

	var insert_offset: int = 0
	for idx in hanging_open_node_indices:
		var adjusted_idx: int = idx + insert_offset
		insert_offset += 1
		
		var close_node := NodeData.new()
		close_node.copy_as_close(node_stack[adjusted_idx])
		node_stack.insert(adjusted_idx + 1, close_node)

	return node_stack

func _generate_layout(node_data: Array, layout: Layout) -> int:
	var err := OK

	for i in node_data: # NodeData
		if i.is_open:
			err = layout.down(i)
		else:
			err = layout.up(i)

		if err != OK:
			push_error("Encountered %s while generating layout. Bailing out" % Error.to_error_name(err))
			return err

	err = layout.verify()

	return err

###############################################################################
# Public functions                                                            #
###############################################################################

func parse(input: String, layout: Layout) -> int:
	var is_path := true
	if input.is_abs_path():
		input = ProjectSettings.globalize_path(input)
	elif input.is_rel_path():
		if context_path.empty():
			return Error.Code.MISSING_CONTEXT_PATH
	else:
		is_path = false
	
	var reader := Reader.new()
	var err := reader.read_path(input) if is_path else reader.read_buffer(input.to_utf8())
	if err != OK:
		return Error.READER_READ_FAILURE
	
	var element_nodes: Array = _process_nodes(reader)
	_generate_layout(element_nodes, layout)
	
	return OK
