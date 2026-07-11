extends AITool

var _scene_path: String
var _signal_name: String
var _target_method: String
var _mode: String
var _emitter:Node
var _target_node:Node


func execute() -> bool:
	# Retrieve parameters
	_scene_path = _parameter_values.get("scene_path", "")
	var emitter_path = _parameter_values.get("emitter_node", "")
	_signal_name = _parameter_values.get("signal_name", "")
	var target_path = _parameter_values.get("target_node", emitter_path)
	_target_method = _parameter_values.get("target_method", "")
	_mode = _parameter_values.get("mode", "Connect")
	
	# Validate paths
	if not AIToolFileUtils.validate_allowed_paths(_scene_path, _read_option("allowed_paths"), _errors, false):
		return false

	if not AIToolFileUtils.validate_prohibited_paths(_scene_path, _read_option("prohibited_paths"), _errors, false):
		return false
	
	for f in _read_option("prohibited_files"):
		if _scene_path == f:
			_errors.append("The file is protected, you cannot edit it.")
			return false
	
	# Validate required parameters
	if _scene_path.is_empty():
		_errors.append("scene_path is required.")
		return false
	
	if emitter_path.is_empty():
		_errors.append("emitter_path is required.")
		return false
		
	if _signal_name.is_empty():
		_errors.append("signal_name is required.")
		return false
		
	if _target_method.is_empty():
		_errors.append("target_method is required.")
		return false
	
	if not ResourceLoader.exists(_scene_path):
		_errors.append("Scene file does not exist: %s" % _scene_path)
		return false
	
	# Load and open the scene in the editor
	EditorInterface.open_scene_from_path(_scene_path)
	var scene_root = EditorInterface.get_edited_scene_root()
	
	if not is_instance_valid(scene_root) or scene_root.scene_file_path != _scene_path:
		_errors.append("Scene failed to open. Verify the path: %s" % _scene_path)
		return false
	
	# Find emitter node
	if not scene_root.has_node(emitter_path):
		_errors.append("Emitter node '%s' not found in scene." % emitter_path)
		return false
	_emitter = scene_root.get_node(emitter_path)
	
	# Find target node
	if not scene_root.has_node(target_path):
		_errors.append("Target node '%s' not found in scene." % target_path)
		return false
	_target_node = scene_root.get_node(target_path)
	
	# Validate signal exists on emitter
	if not _emitter.has_signal(_signal_name):
		_errors.append("Signal '%s' does not exist on emitter node '%s'." % [_signal_name, emitter_path])
		return false
	
	# Validate target method exists
	if not _target_node.has_method(_target_method):
		_errors.append("Method '%s' does not exist on target node '%s'." % [_target_method, target_path])
		return false
	
	var success = _connect_disconnect_signal(_mode == "Connect")
	if not success:
		return false
	
	var callable = Callable(_target_node, _target_method)
	var execution_id := _register_undo()
	_success_message = "Tool executed.\nExecution Id:%s\nStatus of signal '%s' from emitter '%s' to method '%s' on target '%s': %s" % [
		execution_id, _signal_name, emitter_path, _target_method, target_path, "CONNECTED" if _emitter.is_connected(_signal_name, callable) else "DISCONNECTED"
	]
	
	return true


func _connect_disconnect_signal(connect:bool) -> bool:
	# Prepare undo 
	var undo_redo: EditorUndoRedoManager = AIHubPlugin.instance.get_undo_redo()
	undo_redo.create_action("Node signal changes (by AI assistant)")
	
	# Connect/disconnect signal persistently
	var callable = Callable(_target_node, _target_method)
	if connect:
		if _emitter.is_connected(_signal_name, callable):
			_errors.append("Signal '%s' is already connected to method '%s' on target node '%s'." % [_signal_name, _target_method, _target_node.name])
			return false
		# CONNECT_PERSIST forces Godot to write this connection into the .tscn file
		#emitter.connect(_signal_name, callable, CONNECT_PERSIST)
		undo_redo.add_do_method(_emitter, "connect", _signal_name, callable, CONNECT_PERSIST)
		undo_redo.add_undo_method(_emitter, "disconnect", _signal_name, callable)
	else:
		if _emitter.is_connected(_signal_name, callable):
			#emitter.disconnect(_signal_name, callable)
			undo_redo.add_do_method(_emitter, "disconnect", _signal_name, callable)
			undo_redo.add_undo_method(_emitter, "connect", _signal_name, callable, CONNECT_PERSIST)
		else:
			_errors.append("Signal '%s' is not connected to method '%s' on target node '%s'." % [_signal_name, _target_method, _target_node.name])
			return false
	
	# We create a dummy node to force refreshing the scene dock for the signal icon - couldn't find a better way!
	# Unfortunately, editor undo does not do this, so when you undo manually it's not reflected in the UI
	var new_node = Node.new()
	_emitter.add_child(new_node) 
	new_node.owner = _emitter
	
	#EditorInterface.mark_scene_as_unsaved()
	undo_redo.commit_action()
	
	var selection := EditorInterface.get_selection()
	if selection:
		selection.clear()
		selection.add_node(_emitter)
	
	new_node.queue_free() # Delete the dummy node
	return true


func undo() -> bool:
	var success = _connect_disconnect_signal(_mode != "Connect")
	if not success:
		return false
	var callable = Callable(_target_node, _target_method)
	_success_message = "Undo completed.\nStatus of signal '%s' from emitter '%s' to method '%s' on target '%s': %s" % [
		_signal_name, _emitter.name, _target_method, _target_node.name, "CONNECTED" if _emitter.is_connected(_signal_name, callable) else "DISCONNECTED"
	]
	return true
