extends Control

const META_KEY := "__parent__"

const InstanceDescriptor = preload("res://addons/gdml/instance_descriptor.gd")

var instances := {} # Instance name: String -> Instance
var auto_instance_count: int = 0 # Used for automatically generating unique instance keys

var __data__ := {} # Data name: String -> Variant

###############################################################################
# Builtin functions                                                           #
###############################################################################

###############################################################################
# Connections                                                                 #
###############################################################################

###############################################################################
# Private functions                                                           #
###############################################################################

###############################################################################
# Public functions                                                            #
###############################################################################

func add_instance(thing, descriptor: InstanceDescriptor) -> int:
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
		return ERR_INVALID_PARAMETER

	var desc_name := descriptor.get_name()

	if desc_name.empty():
		var clazz_name = instance.get_class()
		desc_name = ("%s_%d" % [clazz_name, auto_instance_count])
	
		while instances.has(desc_name):
			auto_instance_count += 1
			desc_name = ("%s_%d" % [clazz_name, auto_instance_count])
	
	instance.set_meta(META_KEY, self)
	
	instances[desc_name] = instance
	
	return OK

func find_instance(instance_name: String):
	return instances.get(instance_name)

func find_variable(clazz: String, thing: String):
	var instance = instances.get(clazz)
	if instance == null:
		return null

	return instance.get(thing)

#region Connections

func find_and_connect(
	signal_name: String,
	node: Object,
	callback_name: String,
	args: Array = []
) -> int:
	for i in instances.values():
		if i.has_method(callback_name):
			if node.is_connected(signal_name, i, callback_name):
				return ERR_CONNECTION_ERROR
			return node.connect(signal_name, i, callback_name, args)
	
	return ERR_CANT_RESOLVE

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
				return ERR_CONNECTION_ERROR
			return node.connect(signal_name, instance, callback_name, args)

	return ERR_CANT_RESOLVE

func find_and_disconnect(signal_name: String, node: Object, callback_name: String) -> int:
	for i in instances.values():
		if i.has_method(callback_name):
			if not node.is_connected(signal_name, i, callback_name):
				push_warning("Signal %s is not connected to %s - %s" %
					[signal_name, node if node.get("name") else str(node), callback_name])
				return OK
			node.disconnect(signal_name, i, callback_name)
	
	return ERR_CANT_RESOLVE

#endregion
