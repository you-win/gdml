extends Control

const META_KEY := "__parent__"

const Constants = preload("res://addons/gdml/constants.gd")
const Error = preload("res://addons/gdml/error.gd")

const Tag = preload("res://addons/gdml/parser/tag.gd")

# Persistent instances that will continue to exist after generation
var instances := {} # Instance name: String -> Object
# Ephemeral instances that are cleared after generation
var temp_instances := {} # Temp instance name: String -> Object

var __data__ := {} # Data name: String -> Variant

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _init() -> void:
	set_anchors_preset(Control.PRESET_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _ready() -> void:
	temp_instances.clear()

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################

#region Instances

func add_instance(thing, instance_name: String) -> int:
	var instance: Object
	if thing is Script:
		instance = thing.new()
		if instance.is_class("Node"):
			add_child(instance)
	elif thing is PackedScene:
		instance = thing.instance()
	elif typeof(thing) == TYPE_OBJECT:
		instance = thing
	else: # Primitives are not valid instances
		return Error.Code.INVALID_INSTANCE
	
	instance.set_meta(META_KEY, self)
	
	instances[instance_name] = instance
	
	return OK

func add_temp_instance(thing, instance_name: String) -> int:
	if typeof(thing) != TYPE_OBJECT:
		return Error.Code.INVALID_INSTANCE

	temp_instances[instance_name] = thing

	return OK

func find_instance(instance_name: String) -> Object:
	return instances.get(instance_name, temp_instances.get(instance_name))

func find_variable(instance_name: String, thing: String):
	var instance = instances.get(instance_name, temp_instances.get(instance_name))
	if instance == null:
		return null

	return instance.get(thing)

#endregion

#region Connections

# Only regular instances can be connected, temp instances do not live long enough

func find_instance_for_method(method_name: String) -> Object:
	for i in instances.values():
		if i.has_method(method_name):
			return i
	
	return null

func find_and_connect(
	signal_name: String,
	node: Object,
	callback_name: String,
	args: Array = []
) -> int:
	for i in instances.values():
		if i.has_method(callback_name):
			if node.is_connected(signal_name, i, callback_name):
				return Error.Code.ALREADY_CONNECTED
			return node.connect(signal_name, i, callback_name, args)
	
	return Error.Code.NO_VALID_CALLBACK

func direct_connect(
	instance_name: String,
	signal_name: String,
	node: Object,
	callback_name: String,
	args: Array = []
) -> int:
	var instance = instances.get(instance_name)
	if instance != null:
		if instance.has_method(callback_name):
			if node.is_connected(signal_name, instance, callback_name):
				return Error.Code.ALREADY_CONNECTED
			return node.connect(signal_name, instance, callback_name, args)

	return Error.Code.NO_VALID_CALLBACK

func find_and_disconnect(signal_name: String, node: Object, callback_name: String) -> int:
	for i in instances.values():
		if i.has_method(callback_name):
			if not node.is_connected(signal_name, i, callback_name):
				push_warning("Signal %s is not connected to %s - %s" %
					[signal_name, node if node.get("name") else str(node), callback_name])
				return OK
			node.disconnect(signal_name, i, callback_name)
	
	return Error.Code.NO_VALID_CALLBACK

#endregion
