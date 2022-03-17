extends Reference

const Error = preload("res://addons/gdml/error.gd")

var _super_root: Control = null
var _super_stack: Reference = null
var _stack := []

var _depth: int = 0

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _init(super_root: Control, gdml_root: Control = null, super_stack: Reference = null) -> void:
	_super_root = super_root
	_super_stack = super_stack
	_stack.append(gdml_root)

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

func _add_child(depth: int, object: Object) -> void:
	_stack[-1].add_child(object)
	_depth = depth

###############################################################################
# Public functions                                                            #
###############################################################################

func push(object: Object) -> void:
	_stack.push_back(object)

func pop() -> Object:
	if _stack.size() <= 1:
		push_error("Tried to pop root object from the stack")
		return null
	return _stack.pop_back()

func get_stack_root() -> Control:
	return _stack[0]

func get_stack_top() -> Object:
	return _stack[-1]

func get_super_stack() -> Reference:
	return _super_stack

func is_root_stack() -> bool:
	return _super_stack == null

func add_child(depth: int, object: Object, param = null) -> int:
	"""
	Params:
		depth: int - The precalculated depth of the object's tag. Helps determine
					 where the object should be placed in the tree
		object: Object - The instance to be added
		param - Duck-typed value for scripts. Could be an InstanceDescriptor or a String name
	"""
	if object.is_class("Node"):
		if _depth == depth:
			if pop() == null:
				return Error.Code.BAD_STACK
			_add_child(depth, object)
			push(object)
		elif _depth > depth:
			if pop() == null:
				return Error.Code.BAD_STACK
			if pop() == null:
				return Error.Code.BAD_STACK
			_add_child(depth, object)
		
		_add_child(depth, object)
		push(object)
	else:
		if _stack.size() == 1:
			return get_stack_root().add_instance(object, param)
		else:
			var stack_top: Object = get_stack_top()
			
			if stack_top.is_class("Node"):
				stack_top.set_script(object)
			else:
				stack_top.set_meta(param, object)
	
	return OK
