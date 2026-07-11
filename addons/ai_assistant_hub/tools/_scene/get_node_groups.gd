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
	
	_success_message = str(target_node.get_groups())
	
	return true
