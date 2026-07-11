extends AITool


func execute() -> bool:
	var execution_id:String = _parameter_values.get("execution_id", "")
	
	var success := false
	var tool_to_revert := _tool_undo_queue.pop_entry(execution_id)
	if tool_to_revert != null:
		if tool_to_revert.undo():
			_success_message = tool_to_revert.get_success_message()
			return true
		else:
			_errors.append("The undo operation failed.")
			_errors.append_array(tool_to_revert.get_errors())
	else:
		_errors.append("The execution_id is invalid or does not match the last tool executed. Undo queue: %s " % _tool_undo_queue.get_queue_string() )
	return false
