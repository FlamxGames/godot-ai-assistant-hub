extends AITool


func execute() -> bool:
	var groups:PackedStringArray
	
	# Fetch all settings properties and filter for global groups
	var properties := ProjectSettings.get_property_list()
	for prop in properties:
		if prop.name.begins_with("global_group/"):
			# Extract the group name from the setting string
			var group_name = prop.name.trim_prefix("global_group/")
			var description:String = ProjectSettings.get_setting(prop.name)
			if description.is_empty():
				description = "(Empty description)"
			groups.append("%s %s" % [group_name, description])
	
	if groups.is_empty():
		_success_message = "No global groups found."
	else:
		_success_message = "\n".join(groups)
	return true
