extends Control

const META_KEY := "__parent__"

const Constants = preload("../constants.gd")
const Error = preload("../error.gd")

const Tag = preload("../parser/tag.gd")

# Persistent instances that will continue to exist after generation
var instances := {} # Instance name: String -> Object

###############################################################################
# Builtin functions                                                           #
###############################################################################

func _init() -> void:
	set_anchors_preset(Control.PRESET_WIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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

func find_instance(instance_name: String) -> Object:
	return instances.get(instance_name)

func find_variable(instance_name: String, thing: String):
	var instance = instances.get(instance_name)
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
	"""
	Finds the first instance that has the requested callback and uses that callback
	for the given signal
	
	Example:
	<gdml_script>
	func my_callback():
		print("hello")
	</gdml_script>
	<button pressed="my_callback">my button</button>
	
	The signal "pressed" for the Button node will be connected to the "my_callback"
	method on the script "my_script".
	
	NOTE: If there is another script defined with the same func, the script used
	is then based on definition order. Giving scripts a name and directly referring
	to them allows for duplicate method names in different files
	
	Params:
		signal_name: String - The signal name of the `node` param
		node: Object - The object to call `connect` on
		callback_name: String - The callback method to search for
		args: Array - Args to pass to the `connect` method
	
	Return:
		int - The error code
	"""
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
	"""
	Finds an instance that matches `instance_name` and uses the `callback_name` method
	defined on that instance as the callback for a signal connection on `node`
	
	Example:
	<gdml_script name="my_script">
	func my_callback():
		print("hello")
	</gdml_script>
	<gdml_script>
	func my_callback():
		print("not called")
	</gdml_script>
	<button pressed="my_script.my_callback">my button</button>
	
	The signal "pressed" for the Button node will be connected to the "my_callback"
	method on the script "my_script".
	
	Params:
		instance_name: String - The instance to look for
		signal_name: String - The signal name of the `node` param
		node: Object - The object to call `connect` on
		callback_name: String - The callback method to search for
		args: Array - Args to pass to the `connect` method
	
	Return:
		int - The error code
	"""
	var instance = instances.get(instance_name)
	if instance != null:
		if instance.has_method(callback_name):
			if node.is_connected(signal_name, instance, callback_name):
				return Error.Code.ALREADY_CONNECTED
			return node.connect(signal_name, instance, callback_name, args)

	return Error.Code.NO_VALID_CALLBACK

func find_and_disconnect(signal_name: String, node: Object, callback_name: String) -> int:
	"""
	Finds the first instance that has a method called `callback_name` and tries to disconnect
	the `node`'s `signal_name` from that method
	
	Params:
		signal_name: String - The signal name defined on `node`
		node: Object - The node to disconnect
		callback_name: String - The callback to search for and disconnect
	
	Return:
		int - The error code
	"""
	for i in instances.values():
		if i.has_method(callback_name):
			if not node.is_connected(signal_name, i, callback_name):
				push_warning("Signal %s is not connected to %s - %s" %
					[signal_name, node if node.get("name") else str(node), callback_name])
				return OK
			node.disconnect(signal_name, i, callback_name)
	
	return Error.Code.NO_VALID_CALLBACK

#endregion
