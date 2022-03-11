class_name GDML_Stack
extends Reference

var _super_stack: GDML_Stack

var _current_depth: int = -0
var _stack := []

func _init(root: Control, super_stack: GDML_Stack = null) -> void:
	_stack.append(root)
	_super_stack = super_stack

func push(object: Object) -> void:
	_stack.push_back(object)

func pop() -> Object:
	"""
	Remove one element off the end of the stack and return it
	
	The stack can never be empty, so nothing is returned if there is only 1 item on the stack
	"""
	if _stack.size() <= 1:
		push_error("Tried to pop root object from stack")
		return null
	return _stack.pop_back()

func get_root() -> Control:
	return _stack[0]

func get_super_root() -> Control:
	return _super_stack.get_root() if _super_stack != null else null

func _add_child(depth: int, object: Object) -> void:
	_stack[-1].add_child(object)
	_current_depth = depth

func add_child(depth: int, object: Object) -> int:
	"""
	Adds an object as a child to the last object on the stack while also adjusting
	the current node depth.

	Not all code paths push the object onto the stack.
	"""
	if object.is_class("Node"):
		if _current_depth < depth:
			_add_child(depth, object)
			push(object)
		elif _current_depth == depth:
			if pop() == null:
				return ERR_INVALID_DATA
			_add_child(depth, object)
			push(object)
		else:
			if pop() == null:
				return ERR_INVALID_DATA
			if pop() == null:
				return ERR_INVALID_DATA
			_add_child(depth, object)
	else:
		return _stack[0].add_instance(object, GDML_InstanceDescriptor.new())
	return OK

func get_super_stack() -> GDML_Stack:
	return _super_stack if _super_stack != null else null
