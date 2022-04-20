extends Reference

###############################################################################
# Builtin functions                                                           #
###############################################################################

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

static func _get_files_recursive(original_path: String, path: String) -> Dictionary:
	"""
	Recursively finds all files in a directory. Nested directories are represented by further dicts
	
	Params:
		original_path: String - The absoulte, root path of the directory. Used to strip out the full path
		path: String - The current, absoulute search path
	
	Return:
		Dictionary - The files + directories in the current `path`
	
	e.g.
	original_path: /my/path/to/
	{
		"nested": {
			"hello.gd": "/my/path/to/nested/hello.gd"
		},
		"file.gd": "/my/path/to/file.gd"
	}
	"""
	var r := {}
	
	var dir := Directory.new()
	if dir.open(path) != OK:
		printerr("Failed to open directory path: %s" % path)
		return r
	
	dir.list_dir_begin(true, true)
	
	var file_name := dir.get_next()
	
	while file_name != "":
		var full_path := dir.get_current_dir().plus_file(file_name)
		if dir.current_is_dir():
			r[path.replace(original_path, "").plus_file(file_name)] = _get_files_recursive(original_path, full_path)
		else:
			r[file_name] = full_path
		
		file_name = dir.get_next()
	
	return r

###############################################################################
# Public functions                                                            #
###############################################################################

static func get_files_recursive(path: String) -> Dictionary:
	"""
	Wrapper for _get_files_recursive(..., ...) omitting the `original_path` arg.
	
	Args:
		path: String - The path to search
	
	Returns:
		Dictionary - A recursive list of all files found at `path`
	"""
	return _get_files_recursive(path, path)

static func copy_dir_recursive(from: String, to: String, file_dict: Dictionary = {}) -> int:
	"""
	Copies a directory from a path to a given path. A pre-parsed dict of file paths can be passed in
	
	Args:
		from: String - Path to copy from
		to: String - Path to copy files to
	
	Returns:
		int - The return code
	"""
	var files := get_files_recursive(from) if file_dict.empty() else file_dict
	
	var dir := Directory.new()
	
	for key in files.keys():
		var file_path: String = from.plus_file(key)
		var val = files[key]
		
		if val is Dictionary:
			if dir.make_dir(to.plus_file(key)) != OK:
				printerr("Unable to make directory at path: %s" % to.plus_file(key))
				return ERR_BUG
			if copy_dir_recursive(file_path, to.plus_file(key), val) != OK:
				printerr("Unable to copy_dir_recursive")
				return ERR_BUG
			continue
		
		if dir.copy(file_path, to.plus_file(key)) != OK:
			printerr("Unable to copy file from %s to %s" % [file_path, to.plus_file(key)])
			return ERR_BUG
	
	return OK

static func remove_dir_recursive(path: String, delete_base_dir: bool = true, file_dict: Dictionary = {}) -> int:
	var files := get_files_recursive(path) if file_dict.empty() else file_dict
	
	var dir := Directory.new()
	
	for key in files.keys():
		var file_path: String = path.plus_file(key)
		var val = files[key]
		
		if val is Dictionary:
			if remove_dir_recursive(file_path, true, val) != OK:
				printerr("Unable to remove_dir_recursive")
				return ERR_BUG
			continue
		
		if dir.remove(file_path) != OK:
			printerr("Unable to remove file at path: %s" % file_path)
			return ERR_BUG
	
	if delete_base_dir and dir.remove(path) != OK:
		printerr("Unable to remove file at path: %s" % path)
		return ERR_BUG
	
	return OK
