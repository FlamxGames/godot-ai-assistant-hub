extends AITool

var _scene_path: String
var _node_path: String
var _max_depth: int = -1  # -1 means scan to leaf nodes
var _scene_root: Node

func execute() -> bool:
	# Retrieve parameters
	_scene_path = _parameter_values.get("scene_path", "")
	_node_path = _parameter_values.get("node_path", "")
	_max_depth = _parameter_values.get("max_depth", -1)
	
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
	
	_scene_root = root

	# Get the starting node
	var target_node: Node
	if not _node_path.is_empty():
		if not root.has_node(_node_path):
			_errors.append("Node '%s' not found in scene." % _node_path)
			return false
		target_node = root.get_node(_node_path)
	else:
		target_node = root
	
	var hierarchy := { text = "---\nRoot: %s   (%s)" % [ root.name, root.get_class() ] } # pass a string in a dictionary in order to pass it by reference
	if not _node_path.is_empty():
		hierarchy.text += "\nFrom: %s" % _node_path
	if _max_depth != -1:
		hierarchy.text += "\nSublevels scanned: %s" % _max_depth
	hierarchy.text += "\n---"
	var details_json:= {}
	_scan_node(target_node, 0, hierarchy, details_json)

	# Set success message with both hierarchy and details
	_success_message = hierarchy.text + "\n\nDetails:\n```\n%s\n```" % JSON.stringify(details_json, "\t")

	return true


func _scan_node(node: Node, current_depth: int, hierarchy: Dictionary, parent_json: Dictionary) -> void:
	var node_data = {
		"name": node.name,
		"type": node.get_class(),
		"path": _scene_root.get_path_to(node)
	}

	# Get script info
	if node.get_script():
		node_data["script"] = node.get_script().resource_path

	var is_root := node == _scene_root
	if not is_root:
		hierarchy.text += "\n%s   (%s)" % [ _scene_root.get_path_to(node), node.get_class() ]

	if not node.scene_file_path.is_empty() and not is_root:
		node_data["scene_file_path"] = node.scene_file_path
	else:
		# Get children
		var children := node.get_children()
		if children.size() > 0:
			node_data["subnodes_count"] = children.size()
			if _max_depth == -1 or current_depth < _max_depth:
				node_data["subnodes"] = []
		# Recursively scan children
		if _max_depth == -1 or current_depth < _max_depth:
			for child in children:
				_scan_node(child, current_depth + 1, hierarchy, node_data)

	if current_depth == 0:
		parent_json.merge(node_data) # Starting node
	else:
		parent_json["subnodes"].append(node_data)
