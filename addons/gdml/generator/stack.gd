extends Reference

const Constants = preload("res://addons/gdml/constants.gd")
const Error = preload("res://addons/gdml/error.gd")

const ControlRoot = preload("res://addons/gdml/generator/control_root.gd")
const Tag = preload("res://addons/gdml/parser/tag.gd")

# Stack containing all objects by depth
# This means that when the depth increases, objects are added to the stack
# When the depth decreases, objects are popped from the stack
var _stack := [] # Object
# The indices in the stack where a GDML object was inserted
var _gdml_locations := [] # int
# Matches up with each gdml node in the stack
# Allows for tracking of script scope
var _temp_instances := [] # Dictionary

var _depth: int = -1

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _init(super_root: Control) -> void:
	_stack.append(super_root)
	_gdml_locations.append(_stack.size() - 1)
	_temp_instances.append({})

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

func _normalize_stack(depth: int) -> int:
	if _depth > depth:
		while _stack.size() > depth:
			if pop() == null:
				return Error.Code.BAD_STACK
	elif _depth == depth:
		if pop() == null:
			return Error.Code.BAD_STACK

	return OK

func _finalize_stack(depth: int, object: Object) -> void:
	push(object)
	_depth = depth

func _add_child(depth: int, object: Object) -> void:
	_stack[-1].add_child(object)

func _add_instance(tag: Tag, stack_object: Object, object: Object, param) -> int:
	var err := OK
	var inner_err := OK

	# TODO refactor in generator as well
	if not bool(tag.attributes.get(Constants.TEMP, false)):
		inner_err = stack_object.add_instance(object, param)
		if inner_err != OK:
			err = inner_err
	# inner_err = stack_object.add_temp_instance(object, param)
	inner_err = add_temp_instance(object, param)
	if inner_err != OK:
		err = inner_err

	return err

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
		_temp_instances.pop_back()
	return _stack.pop_back()

func root() -> Control:
	return _stack[0]

func top() -> Object:
	return _stack[-1]

func add_gdml(tag: Tag, gdml: Control) -> int:
	return add_child(tag, gdml, true)

func add_child(tag: Tag, object: Object, param = null) -> int:
	"""
	Params:
		depth: int - The precalculated depth of the object's tag. Helps determine
					 where the object should be placed in the tree
		object: Object - The instance to be added
		param - Duck-typed value for scripts. Could be an InstanceDescriptor or a String name
	"""
	var err := OK
	var depth: int = tag.depth

	# if _depth > depth:
	# 	while _stack.size() > depth:
	# 		pop()
	# elif _depth == depth:
	# 	if pop() == null:
	# 		return Error.Code.BAD_STACK
	err = _normalize_stack(depth)
	if err != OK:
		return err
	
	if object.is_class("Node"):
		_add_child(depth, object)
		
		if typeof(param) == TYPE_BOOL and param == true:
			_gdml_locations.append(_stack.size())
			_temp_instances.append({})
	else:
		if _stack.size() == 1:
			err = _add_instance(tag, root(), object, param)
		else:
			var stack_top: Object = top()
			
			if stack_top.is_class("Node"):
				if not stack_top is ControlRoot:
					stack_top.set_script(object)
				else:
					err = _add_instance(tag, stack_top, object, param)
			else:
				stack_top.set_meta(param, object)
	
	# Push the object onto the stack no matter what
	# push(object)
	# _depth = depth
	_finalize_stack(depth, object)
	
	return err

func add_style(tag: Tag, theme: Theme) -> int:
	var err := OK
	var depth: int = tag.depth

	err = _normalize_stack(depth)
	if err != OK:
		return err

	var stack_top: Object = top()
	if stack_top.is_class("Control"):
		stack_top.theme = theme
	else:
		root().theme = theme

	_finalize_stack(depth, theme)

	return err

func add_temp_instance(thing, instance_name: String) -> int:
	if typeof(thing) != TYPE_OBJECT:
		return Error.Code.INVALID_INSTANCE

	_temp_instances[-1][instance_name] = thing

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

	for i in get_gdml_nodes():
		var instance: Object = i.find_instance_for_method(method_name)
		if instance != null:
			return instance
	return null

func find_instance(instance_name: String) -> Object:
	for i in get_gdml_nodes():
		var instance: Object = i.find_instance(instance_name)
		if instance != null:
			return instance

	return null

func find_temp_instance(instance_name: String) -> Object:
	for dict in _temp_instances:
		var instance: Object = dict.get(instance_name)
		if instance != null:
			return instance

	return null

func get_gdml_nodes() -> Array:
	var r := []

	for i in _gdml_locations:
		r.append(_stack[i])

	return r
