extends AITool

var _action:String
var _group_name:String
var _group_description:String

const CREATE_OPTION := "Create"

func execute() -> bool:
	_action = _parameter_values.get("action", CREATE_OPTION)
	_group_name = _parameter_values.get("group_name", "")
	_group_description = _parameter_values.get("group_description", "")
	
	if _group_name.is_empty():
		_errors.append("group_name is required.")
		return false
	
	var success = _add_remove_global_group(_action == CREATE_OPTION)
	if success:
		var execution_id := _register_undo()
		_success_message = "The operation in global groups was successful.\nExecution Id:%s" % execution_id
	else:
		_errors.append("The operation in global groups was NOT successful. Is the group name correct?")
	return success


func _add_remove_global_group(add:bool) -> bool:
	var setting_path = "global_group/%s" % _group_name
	
	if add:
		ProjectSettings.set_setting(setting_path, _group_description)
	else:
		var value = ProjectSettings.get_setting(setting_path)
		if value == null:
			_errors.append("%s is not present in global groups." % _group_name)
			return false
		_group_description = value #We store it here if present, so the change can be undone
		ProjectSettings.set_setting(setting_path, null)
	
	ProjectSettings.save()
	
	var found := false
	var properties = ProjectSettings.get_property_list()
	for prop in properties:
		if prop.name.begins_with("global_group/") and prop.name.trim_prefix("global_group/") == _group_name:
			found = true
			break
	
	var success:= false
	if add:
		if found:
			success = true
	elif not found:
		success = true
	return success


func undo() -> bool:
	var success = _add_remove_global_group(_action != CREATE_OPTION)
	if success:
		_success_message = "The undo operation in global groups was successful."
	else:
		_errors.append("The undo operation in global groups was NOT successful.")
	return success
