extends Reference

const Error = preload("res://addons/gdml/error.gd")

# Stack containing all objects by depth
# This means that when the depth increases, objects are added to the stack
# When the depth decreases, objects are popped from the stack
var _stack := [] # Object
# The indices in the stack where a GDML object was inserted
var _gdml_locations := [] # int

var _depth: int = -1

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _init(super_root: Control) -> void:
	_stack.append(super_root)
	_gdml_locations.append(_stack.size() - 1)

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
	if _stack.size() - 1 in _gdml_locations:
		_gdml_locations.pop_back()
	return _stack.pop_back()

func root() -> Control:
	return _stack[0]

func top() -> Object:
	return _stack[-1]

func add_gdml(depth: int, gdml: Control) -> int:
	_gdml_locations.append(_stack.size())
	
	return add_child(depth, gdml)

func add_child(depth: int, object: Object, param = null) -> int:
	"""
	Params:
		depth: int - The precalculated depth of the object's tag. Helps determine
					 where the object should be placed in the tree
		object: Object - The instance to be added
		param - Duck-typed value for scripts. Could be an InstanceDescriptor or a String name
	"""
	if object.is_class("Node"):
		if _depth > depth:
			while _stack.size() > depth:
				pop()
		elif _depth == depth:
			if pop() == null:
				return Error.Code.BAD_STACK
		
		_add_child(depth, object)
		push(object)
	else:
		if _stack.size() == 1:
			return root().add_instance(object, param)
		else:
			var stack_top: Object = top()
			
			if stack_top.is_class("Node"):
				stack_top.set_script(object)
			else:
				stack_top.set_meta(param, object)
	
	return OK

func find_name_in_stack(node_name: String) -> Object:
	for i in _stack:
		if i.get("name") == node_name:
			return i
	return null

func find_object_for_method_in_stack(method_name: String) -> Object:
	for i in _stack:
		if i.has_method(method_name):
			return i

	for i in _gdml_locations:
		var instance: Object = _stack[i].find_instance_for_method(method_name)
		if instance != null:
			return instance
	return null

func find_instance(instance_name: String) -> Object:
	for i in _gdml_locations:
		var instance = _stack[i].find_instance(instance_name)
		if instance != null:
			return instance

	return null
