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
		for file in files:
			match file.get_extension().to_lower():
				_:
					pass
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

static func _load_zip(path: String) -> Control:
	var gdunzip := GdUnzip.new()
	
	if not gdunzip.load(path):
		printerr("Failed to load zip: %s" % path)
		return null
	
	# Files can refer to other files, so we need to discover all files first
	var vfs := {} # File path: String -> File data: String
	for f in gdunzip.files.values():
		var data = gdunzip.uncompress(f["file_name"])
		
		if not data:
			printerr("Failed to uncompress, skipping: %s" % f["file_name"])
			continue
		
		if not typeof(data) == TYPE_RAW_ARRAY:
			printerr("Unexpected uncompressed data, skipping")
			continue
		
		vfs[f["file_name"]] = (data as PoolByteArray).get_string_from_utf8()
	
	# TODO stub
	return Control.new()

static func _load_folder(path: String) -> Control:
	var control: Control
	
	var dir_utils := DirUtils.new()
	var files := dir_utils.get_files_recursive(path)
	
	dir_utils.remove_dir_recursive(RUNNER_DIR, false)
	
	dir_utils.copy_dir_recursive(path, RUNNER_DIR, files)
	
	var gdml := Gdml.new(RUNNER_DIR)
	
	var entrypoint := DEFAULT_MAIN
	
	var file := File.new()
	if file.open("%s/%s" % [RUNNER_DIR, CONFIG_JSON], File.READ) == OK:
		var data = parse_json(file.get_as_text())
		
		if data is Dictionary:
			entrypoint = data.get(CONFIG_ENTRYPOINT_KEY, DEFAULT_MAIN)
	
	return gdml.generate(entrypoint)

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
