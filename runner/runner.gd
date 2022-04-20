extends Node

const Gdml = preload("res://addons/gdml/gdml.gd")
const GdUnzip = preload("res://addons/gdunzip/gdunzip.gd")
const DirUtils = preload("res://runner/dir_utils.gd")

# Holds a copy of any dropped files. Always cleared before new files are dropped
const RUNNER_DIR := "user://runner/"

const CONFIG_JSON := "gdml.json"
const CONFIG_ENTRYPOINT_KEY := "entrypoint"

const DEFAULT_MAIN := "main.xml"

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _ready() -> void:
	OS.center_window()
	get_tree().connect("files_dropped", self, "_on_files_dropped")
	if ClassDB.class_exists("Redirect"):
		Engine.get_singleton("Redirect").connect("print_line", self, "_on_stderr")
	
	var dir := Directory.new()
	if not dir.dir_exists(RUNNER_DIR):
		dir.make_dir(RUNNER_DIR)

###############################################################################
# Connections                                                                 #
###############################################################################

func _on_console_output(stdout: String, is_error: bool) -> void:
	if is_error:
		print("stderr: %s" % stdout)

func _on_files_dropped(files: PoolStringArray, _screen: int) -> void:
	if files.size() == 1:
		var file_path: String = files[0]
		match file_path.get_extension().to_lower():
			"xml", "gdml":
				_clear_all_children()
				add_child(_load_xml(file_path))
			"zip":
				_clear_all_children()
				add_child(_load_zip(file_path))
			"":
				_clear_all_children()
				add_child(_load_folder(file_path))
			_:
				# Everything else is invalid
				printerr("Invalid file type dropped: %s" % file_path)
	elif files.size() > 1:
		if not OS.has_feature("web"):
			printerr("Load the entire folder instead when running locally")
			return
		printerr("Dragging multiple files will not work in the file structure is not flat")
		var dir_utils := DirUtils.new()
		if dir_utils.remove_dir_recursive(RUNNER_DIR, false) != OK:
			printerr("Error occurred while cleaning up %s" % RUNNER_DIR)
			return
		
		var file := File.new()
		for file_path in files:
			print_debug(file_path)
			if file.open(file_path, File.READ) != OK:
				printerr("Unable to open file at path %s" % file_path)
				return
			
			var text := file.get_as_text()
			
			file.close()
			
			if file.open("%s/%s" % [RUNNER_DIR, file_path.get_file()], File.WRITE) != OK:
				printerr("Unable to open path for writing %s" % "%s/%s" % [RUNNER_DIR, file_path.get_file()])
				return
			
			file.store_string(text)
			
			file.close()
		
		_clear_all_children()
		add_child(_load_from_runner_dir())
	else:
		printerr("Dropped 0 files somehow")

###############################################################################
# Private functions                                                           #
###############################################################################

func _clear_all_children() -> void:
	for c in get_children():
		c.queue_free()

static func _to_containing_dir(path: String) -> String:
	return path.replace(path.get_file(), "")

static func _load_xml(path: String) -> Control:
	var gdml := Gdml.new(_to_containing_dir(path))
	
	return gdml.generate(path)

# TODO this is broken, currently requires a containing folder
static func _load_zip(path: String) -> Control:
	"""
	{
		"path/including/zip/name": {
			"compression_method": -1,
			"file_name": "same/as/key",
			"compressed_size": 0,
			"uncompressed_size": 0,
			"file_header_offset": 0
		}
	}
	"""
	var dir_utils := DirUtils.new()
	dir_utils.remove_dir_recursive(RUNNER_DIR, false)
	
	var gdunzip := GdUnzip.new()
	
	if not gdunzip.load(path):
		printerr("Failed to load zip: %s" % path)
		return null
	
	for f in gdunzip.files.values():
		var split_file_name: PoolStringArray = f["file_name"].split("/", false, 1)
		if split_file_name.size() < 2:
			continue
		
		var stripped_file_path: String = split_file_name[1]
		
		# Skip empty files
		if f["uncompressed_size"] < 1:
			continue
		
		var data = gdunzip.uncompress(f["file_name"])
		
		if not data:
			continue
		
		if not typeof(data) == TYPE_RAW_ARRAY:
			printerr("Unexpected uncompressed data, skipping")
			continue
		
		var dir := Directory.new()
		var file_name_split := Array(stripped_file_path.rsplit("/", false, 1))
		var file_dir: String = "%s/%s" % [RUNNER_DIR, file_name_split.front() if file_name_split.size() > 1 else ""]
		if file_name_split.size() > 1:
			if not dir.dir_exists(file_dir):
				if dir.make_dir_recursive(file_dir) != OK:
					printerr("Unable to make dir %s, aborting" % file_dir)
					return null
		
		var file := File.new()
		if file.open("%s/%s" % [RUNNER_DIR, stripped_file_path], File.WRITE) != OK:
			printerr("Unable to open %s" % "%s/%s" % [RUNNER_DIR, stripped_file_path])
			return null
		
		var text: String = data.get_string_from_utf8()
		file.store_buffer(data)
		print(text)
	
	return _load_from_runner_dir()

static func _load_folder(path: String) -> Control:
	var control: Control
	
	var dir_utils := DirUtils.new()
	var files := dir_utils.get_files_recursive(path)
	
	dir_utils.remove_dir_recursive(RUNNER_DIR, false)
	
	dir_utils.copy_dir_recursive(path, RUNNER_DIR, files)
	
	return _load_from_runner_dir()

static func _load_from_runner_dir() -> Control:
	var gdml := Gdml.new(RUNNER_DIR)
	
	var entrypoint := DEFAULT_MAIN
	
	var file := File.new()
	if file.open("%s/%s" % [RUNNER_DIR, CONFIG_JSON], File.READ) == OK:
		var data = parse_json(file.get_as_text())
		
		if data is Dictionary:
			entrypoint = data.get(CONFIG_ENTRYPOINT_KEY, DEFAULT_MAIN)
	
	return gdml.generate(entrypoint)

###############################################################################
# Public functions                                                            #
###############################################################################
