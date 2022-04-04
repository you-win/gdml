extends CanvasLayer

const Gdml = preload("res://addons/gdml/gdml.gd")
const GdUnzip = preload("res://addons/gdunzip/gdunzip.gd")

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	get_tree().connect("files_dropped", self, "_on_files_dropped")
	Redirect.connect("print_line", self, "_on_console_output")
	printerr("hello")

###############################################################################
# Connections                                                                 #
###############################################################################

func _on_console_output(stdout: String, is_error: bool) -> void:
	if is_error:
		print("stderr: %s" % stdout)

func _on_files_dropped(files: PoolStringArray, _screen: int) -> void:
	if files.size() > 1:
		push_error("Pack files into a folder instead. Unable to handle many raw files.")
		return
	
	var file_path: String = files[0]
	match file_path.get_extension().to_lower():
		"xml", "gdml":
			pass
		"zip":
			pass
		"":
			pass
		_:
			# Everything else is invalid
			push_error("Invalid file type dropped: %s" % file_path)

###############################################################################
# Private functions                                                           #
###############################################################################

static func _to_containing_dir(path: String) -> String:
	return path.replace(path.get_file(), "")

static func _load_xml(path: String) -> Control:
	var control: Control
	
	var gdml := Gdml.new(_to_containing_dir(path))
	
	return gdml.generate(path)

static func _load_zip(path: String) -> Control:
	var gdunzip := GdUnzip.new()
	
	if not gdunzip.load(path):
		push_error("Failed to load zip: %s" % path)
		return null
	
	# Files can refer to other files, so we need to discover all files first
	var vfs := {} # File path: String -> File data: String
	for f in gdunzip.files.values():
		var data = gdunzip.uncompress(f["file_name"])
		
		if not data:
			push_error("Failed to uncompress, skipping: %s" % f["file_name"])
			continue
		
		if not typeof(data) == TYPE_RAW_ARRAY:
			push_error("Unexpected uncompressed data, skipping")
			continue
		
		vfs[f["file_name"]] = (data as PoolByteArray).get_string_from_utf8()
	
	return _load_from_vfs(path, vfs)

static func _load_folder(path: String) -> Control:
	var control: Control
	
	var vfs := {}
	_get_files_recursive(path, vfs)
	
	return _load_from_vfs(path, vfs)

static func _get_files_recursive(path: String, files: Dictionary) -> void:
	var dir := Directory.new()
	if dir.open(path) != OK:
		push_error("Failed to open directory path: %s" % path)
		return
	
	dir.list_dir_begin(true, true)
	
	var file_name := dir.get_next()
	
	while file_name != "":
		var full_path := dir.get_current_dir().plus_file(file_name)
		if dir.current_is_dir():
			_get_files_recursive(full_path, files)
		else:
			var file := File.new()
			if file.open(full_path, File.READ) != OK:
				push_error("Failed to open file: %s" % full_path)
				file_name = dir.get_next()
				continue
			
			files[full_path] = file.get_as_text()
		
		file_name = dir.get_next()

static func _load_from_vfs(base_path: String, vfs: Dictionary) -> Control:
	# TODO this won't work, gdml needs to be modified to accept a vfs
	var gdml := Gdml.new(_to_containing_dir(base_path))
	
	return gdml.generate(base_path)

###############################################################################
# Public functions                                                            #
###############################################################################
