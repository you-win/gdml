class_name GDML_Parser
extends Reference

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

func _process_nodes(reader: GDML_Reader) -> Array:
	"""
	Processes nodes for a given file in 3 steps

	1. Reads all nodes in the reader. Hanging close nodes are dropped.
	2. Identify hanging open nodes
	3. Insert appropriate close nodes for each hanging open node

	Params:
		reader: GDML_Reader - The reader for the given data. Should come preloaded with the data

	Returns:
		Array - An Array containing GDML_NodeData objects
	"""
	var node_stack := []

	var open_close_stack := {} # Tag name: String -> Stack: Array
	var node_location: int = -1

	while true:
		var data: GDML_NodeData = reader.read_node()

		if data.is_complete:
			break

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
			var open_node: GDML_NodeData = stack.pop_back()
			if open_node == null:
				push_warning("No matching open node found for %s at location %d" % [node_name, node_location])
				# Decrement here because we discard the tag
				node_location -= 1
				continue

			node_stack.append(data)

	var hanging_open_node_indices := []

	for tag_name in open_close_stack.keys():
		var stack: Array = open_close_stack[tag_name]

		if stack.size() > 0:
			for i in stack: # GDML_NodeData
				hanging_open_node_indices.append(i.location)

	# TODO this could be done with an offset so we can just find and insert instead of iterating over
	# every node again
	var fixed_node_stack := []

	for node_data in node_stack:
		fixed_node_stack.append(node_data)
		if node_data.location in hanging_open_node_indices:
			var close_node := GDML_NodeData.new()
			close_node.copy_as_close(node_data)
			fixed_node_stack.append(close_node)

	return fixed_node_stack

func _generate_layout(node_data: Array, layout: GDML_Layout) -> int:
	var err := OK

	for i in node_data: # GDML_NodeData
		if layout.finished:
			err = layout.add_root_tag(i)
		else:
			if i.is_open:
				err = layout.down(i)
			else:
				err = layout.up()
				if err == GDML_Error.Code.ALREADY_AT_ROOT_TAG:
					err = layout.finish()

		if err != OK:
			push_error("Encountered %s while generating layout. Bailing out" % GDML_Error.to_error_name(err))
			return err

	return err

###############################################################################
# Public functions                                                            #
###############################################################################

func parse(input: String, layout: GDML_Layout) -> int:
	var is_path := true
	if input.is_abs_path():
		input = ProjectSettings.globalize_path(input)
	elif input.is_rel_path():
		if context_path.empty():
			push_error("A context path is required when using a relative path")
			return GDML_Error.Code.MISSING_CONTEXT_PATH
	else:
		is_path = false
	
	var reader := GDML_Reader.new()
	var err := reader.read_path(input) if is_path else reader.read_buffer(input.to_utf8())
	if err != OK:
		push_error("Error %s occurred while reading %s" %
			[GDML_Error.to_error_name(err), input if is_path else "buffer"])
	
	var element_nodes: Array = _process_nodes(reader)
	_generate_layout(element_nodes, layout)
	
	return OK
