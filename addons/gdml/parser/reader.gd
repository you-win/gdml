extends XMLParser

const Error = preload("res://addons/gdml/error.gd")
const Constants = preload("res://addons/gdml/constants.gd")

const NodeData = preload("res://addons/gdml/parser/node_data.gd")

# Needed since the xml reader will sometimes run out of things to parse but still return values
var was_complete := false

func read_path(path: String) -> int:
	"""
	Wrapper around XMLParser.open(...) so that I can remember the API
	"""
	if open(path) != OK:
		return Error.Code.OPEN_PATH_FAILURE
	return OK

func read_buffer(buffer: PoolByteArray) -> int:
	"""
	Wrapper around XMLParser.read_buffer(...) so that I can remember the API
	"""
	if open_buffer(buffer) != OK:
		return Error.Code.OPEN_BUFFER_FAILURE
	return OK

func read_node() -> NodeData:
	"""
	Read extents of xml element
	"""
	var nd := NodeData.new()
	
	if was_complete:
		nd.is_complete = true
		return nd
	
	var is_finished := false
	while not is_finished:
		match get_node_type():
			XMLParser.NODE_ELEMENT:
				if not nd.node_name.empty():
					return nd
				nd.is_open = true
				nd.node_name = get_node_name()
				for i in get_attribute_count():
					nd.attributes[get_attribute_name(i)] = get_attribute_value(i)
			XMLParser.NODE_TEXT:
				nd.text += get_node_data() if nd.node_name == Constants.SCRIPT else get_node_data().strip_edges()
				if OS.get_name().to_lower() == "linux":
					nd.text = nd.text.replace("\r", "")
				is_finished = true
			XMLParser.NODE_ELEMENT_END:
				if not nd.node_name.empty():
					return nd
				nd.node_name = get_node_name()
				nd.is_open = false
				is_finished = true
			XMLParser.NODE_COMMENT:
				# Intentionally do nothing
				pass
			_:
				is_finished = true
		
		if read() != OK:
			is_finished = true
			nd.is_complete = true
			was_complete = true
	
	return nd
