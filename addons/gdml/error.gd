class_name GDML_Error
extends Reference

enum Code {
	NONE = 0,
	
	MISSING_CONTEXT_PATH,
	
	#region Reader
	
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
}

static func to_error_name(error_code: int) -> String:
	return Code.keys()[error_code]
