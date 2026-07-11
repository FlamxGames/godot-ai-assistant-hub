class_name AIToolPropertiesUtils


static func read_property_values_input(property_values:Array, out_prop_value_map:Dictionary,
									   prohibited_props:PackedStringArray, errors:PackedStringArray) -> bool:
	for entry in property_values:
		var prop_val:String = str(entry)
		var equals_pos := prop_val.find("=")
		if equals_pos < 1:
			errors.append("Invalid property-value entry '%s'. Format is '<property> = <value>'." % entry)
			return false
		var prop_name := prop_val.left(equals_pos).strip_escapes().strip_edges()
		var value := prop_val.right(prop_val.length() - equals_pos - 1).strip_edges()
		if prop_name.is_empty():
			errors.append("Invalid property-value entry '%s'. Property name seems to be missing." % entry)
			return false
		if prohibited_props.has(prop_name):
			errors.append("Property '%s' is in the list of properties prohibited by the user." % prop_name)
			return false
		out_prop_value_map[prop_name] = value
	return true


static func get_resource_prop_values(start_object:Object, prop_value_map:Dictionary, res_prop_value_map:Dictionary, errors:PackedStringArray) -> bool:
	for prop_name in prop_value_map.keys():
		if prop_name.contains("."):
			# Property names like shape.size are for resources
			var key_parts:Array = Array(prop_name.split("."))
			if key_parts.size() < 2:
				errors.append("Invalid property %s. Misplaced '.' separator." % prop_name)
				return false
				
			# Get the actual property name (e.g. size)
			var res_prop_name:String = key_parts.pop_back()
			
			# Find the actual resource holding the property
			var curr_parent:Object = start_object
			for res_name in key_parts:
				curr_parent = curr_parent.get(res_name)
				if curr_parent == null or not curr_parent is Resource:
					errors.append("Embedded resource '%s' does not exist or has not been created yet." % res_name)
					return false
			var target_resource:Resource = curr_parent
			
			# res_prop_value_map has a key for each resource for which we are setting properties
			# each key corresponds to a dictionary of property names and string values
			var res_prop_dict:Dictionary = res_prop_value_map.get_or_add(target_resource, {})
			res_prop_dict[res_prop_name] = prop_value_map[prop_name]
	return true


static func apply_all_property_changes(new_obj_prop_values:Dictionary, old_obj_prop_values:Dictionary) -> void:
	for obj in new_obj_prop_values.keys():
		var new_values_dict:Dictionary = new_obj_prop_values[obj]
		var original_values_dict:Dictionary = old_obj_prop_values[obj]
		_apply_obj_values_to_properties(obj, new_values_dict, original_values_dict)


static func apply_changes_to_object(obj:Object, prop_value_map:Dictionary, scene_root:Node,
									do_obj_property_values:Dictionary, undo_obj_property_values:Dictionary,
									errors:PackedStringArray) -> bool:
	var obj_name:String
	if obj is Node:
		obj_name = "Node '%s'" % obj.name if not obj.name.is_empty() else str(obj.get_path())
	elif obj is Resource:
		obj_name = "Resource '%s'" % obj.resource_path if not obj.resource_path.is_empty() else obj.get_class()
	
	var do_values_map := {}
	var undo_values_map := {}
	var parser := AIToolValueParser.new(obj)
	var success := parser.parse_prop_value_map(scene_root, prop_value_map, do_values_map, undo_values_map)
	if not success:
		errors.append("Error while processing %s" % obj_name)
		errors.append_array(parser.get_errors())
		apply_all_property_changes(undo_obj_property_values, do_obj_property_values) #Undo what was done so far
		return false
	_apply_obj_values_to_properties(obj, do_values_map,undo_values_map)
	do_obj_property_values[obj] = do_values_map
	undo_obj_property_values[obj] = undo_values_map
	return true


static func _apply_obj_values_to_properties(obj:Object, new_values_dict:Dictionary, original_values_dict:Dictionary) -> void:
	var obj_name:String
	if obj is Node:
		obj_name = "Node '%s'" % obj.name if not obj.name.is_empty() else str(obj.get_path())
	elif obj is Resource:
		obj_name = "Resource '%s'" % obj.resource_path if not obj.resource_path.is_empty() else obj.get_class()
	
	var undo_redo: EditorUndoRedoManager = AIHubPlugin.instance.get_undo_redo()
	undo_redo.create_action("%s properties changes (by AI assistant)" % obj_name)
	for property in new_values_dict.keys():
		undo_redo.add_do_property(obj, property, new_values_dict[property])
		undo_redo.add_undo_property(obj, property, original_values_dict[property])
	undo_redo.commit_action(true)
