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

	HANGING_OPEN_TAG,
	HANGING_CLOSE_TAG,

	#endregion
	
	#region Generator
	
	BAD_SCRIPT_TAG,
	BAD_SCRIPT_TEXT,
	UNKNOWN_SCRIPT,
	SCRIPT_HOIST_ERROR,
	
	NO_SIGNAL_FOUND,
	SIGNAL_ALREADY_CONNECTED,
	
	NO_THEMES_PARSED,
	
	HANDLE_ELEMENT_FAILURE,
	
	BAD_STACK,
	MISSING_ON_STACK
	
	#endregion
}

static func to_error_name(error_code: int) -> String:
	return Code.keys()[error_code]
