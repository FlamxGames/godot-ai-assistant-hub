extends AITool

var _scene_path: String
var _node_path: String


func execute() -> bool:
	# Retrieve parameters
	_scene_path = _parameter_values.get("scene_path", "")
	_node_path = _parameter_values.get("node_path", "")
	
	# Validate paths
	if not AIToolFileUtils.validate_allowed_paths(_scene_path, _read_option("allowed_paths"), _errors, false):
		return false

	if not AIToolFileUtils.validate_prohibited_paths(_scene_path, _read_option("prohibited_paths"), _errors, false):
		return false

	if _scene_path.is_empty():
		_errors.append("scene_path is required.")
		return false

	if not ResourceLoader.exists(_scene_path):
		_errors.append("Scene file does not exist: %s" % _scene_path)
		return false

	# Load and open the scene in the editor
	EditorInterface.open_scene_from_path(_scene_path)
	var root = EditorInterface.get_edited_scene_root()
	
	if not is_instance_valid(root) or root.scene_file_path != _scene_path:
		_errors.append("Scene failed to open. Verify the path: %s" % _scene_path)
		return false
	
	# Get the target node
	if not root.has_node(_node_path):
		_errors.append("Node '%s' not found in scene." % _node_path)
		return false
		
	var target_node = root.get_node(_node_path)
	
	_success_message = "# Signals and connections:"
	var signals := target_node.get_signal_list()
	for sig in signals:
		var args = _get_args_list(sig.args)
		var signal_text := "%s%s" % [sig.name, args]
		var connections := target_node.get_signal_connection_list(sig.name)
		for conn in connections:
			if conn["flags"] & ConnectFlags.CONNECT_PERSIST:
				var callable:Callable = conn["callable"]
				var called_node:Node = callable.get_object()
				
				signal_text += "\n\t—> {node} :: {method}(){binds}".format(
					{
						"node": target_node.get_path_to(called_node),
						"method": callable.get_method(),
						"binds": "" if callable.get_bound_arguments().is_empty() else " binds(%s)" % callable.get_bound_arguments()
					}
				)
		_success_message += "\n%s" % signal_text
	var incomming_conn := target_node.get_incoming_connections()
	if incomming_conn.size() > 0:
		_success_message += "\n\n%s" % "# Incoming method calls:"
		for conn in incomming_conn:
			var sig:Signal = conn["signal"]
			var node:Node = sig.get_object()
			if node != target_node:
				var callable:Callable = conn["callable"]
				_success_message += "\n{method}(){binds} <— {node} (from signal '{signal}') ".format(
						{
							"method": callable.get_method(),
							"binds": "" if callable.get_bound_arguments().is_empty() else " binds(%s)" % callable.get_bound_arguments(),
							"node": target_node.get_path_to(node),
							"signal": sig.get_name()
						}
					)
	
	return true


func _get_args_list(args_dict:Array[Dictionary]) -> String:
	var str := "("
	var first:= true
	for arg in args_dict:
		if first:
			first = false
		else:
			str += ", "
		var type:String = arg.class_name
		if type.is_empty():
			type = AIToolGodotUtils.get_variant_type_name(arg.type)
		str += "%s: %s" % [ arg.name, type ]
	str += ")"
	return str
