extends Reference

enum Code {
	NONE = 0,
	
	MISSING_CONTEXT_PATH,
	FILE_OPEN_FAILURE,
	
	#region Reader
	
	READER_READ_FAILURE,
	OPEN_PATH_FAILURE,
	OPEN_BUFFER_FAILURE,
	
	#endregion
	
	#region Layout

	ALREADY_FINISHED,
	NOT_FINISHED_PROCESSING_TAG,
	ALREADY_AT_ROOT_TAG,
	NO_CURRENT_TAG,
	NO_PARENT_FOR_CURRENT_TAG,

	#endregion
	
	#region Generator
	
	BAD_SCRIPT_TAG,
	BAD_SCRIPT_TEXT,
	UNKNOWN_SCRIPT,
	SCRIPT_HOIST_ERROR,
	
	NO_SIGNAL_FOUND,
	
	NO_THEMES_PARSED,
	
	HANDLE_ELEMENT_FAILURE,
	
	#endregion
}

static func to_error_name(error_code: int) -> String:
	return Code.keys()[error_code]
