@tool
## Base class for all assistant tools.
class_name AITool

var _resource:AIToolResource
var _options_by_key:= {}
var _option_values:Dictionary ## For definition see AIToolAccess
var _errors:= PackedStringArray()
var _parameter_values:= {}
var _success_message:= "Success"
var _tool_undo_queue:AIToolUndoQueue


func _init(resource:AIToolResource, option_values:Dictionary, tool_undo_queue:AIToolUndoQueue) -> void:
	_resource = resource
	_tool_undo_queue = tool_undo_queue
	for o in _resource.options:
		_options_by_key[o.id] = o
	_option_values = option_values


func get_function_name() -> String:
	return _resource.id


func get_title() -> String:
	return _resource.title


func get_description() -> String:
	return _resource.description


## Override this in the tool class if based on options the parameters can change, this can be used to hide parameters to the assistants
func get_parameters() -> Array[AIToolParameter]:
	return _resource.parameters


func get_errors() -> PackedStringArray:
	return _errors


func read_parameters(call_parameters:Dictionary) -> Array[String]:
	var parameter_errors:Array[String] = []
	for exp_param in _resource.parameters:
		var received_param = call_parameters.get(exp_param.name)
		AIHubPlugin.print_msg("Reading parameter '%s'" % exp_param.name)
		if exp_param.required and received_param == null:
			AIHubPlugin.print_msg("Detected an error on this parameter")
			parameter_errors.append("Parameter %s is required but was not provided." % exp_param.name)
			continue
		AIHubPlugin.print_msg("Value received '%s' of type '%s'" % [ str(received_param), type_string(typeof(received_param)) ])
		if received_param:
			var valid_type:= false
			match exp_param.type:
				AIToolParameter.ParameterType.Int:
					if received_param is int:
						valid_type = true
					if received_param is float:
						received_param = int(received_param)
						valid_type = true
					elif received_param is String and received_param.is_valid_int():
						received_param = received_param.to_int()
						valid_type = true
				AIToolParameter.ParameterType.Float:
					if received_param is float or received_param is int:
						valid_type = true
					elif received_param is String and received_param.is_valid_float():
						received_param = received_param.to_float()
						valid_type = true
				AIToolParameter.ParameterType.Boolean:
					if received_param is bool:
						valid_type = true
					elif received_param is String:
						if received_param.to_lower() == "true":
							received_param = true
							valid_type = true
						if received_param.to_lower() == "false":
							received_param = false
							valid_type = true
				AIToolParameter.ParameterType.String, AIToolParameter.ParameterType.Code: #Can we validate Code in advance?
					if received_param is String:
						valid_type = true
				AIToolParameter.ParameterType.StringEnum:
					if received_param is String and exp_param.string_enum_valid_values.has(received_param):
						valid_type = true
				AIToolParameter.ParameterType.Array:
					if received_param is Array:
						valid_type = true
			if valid_type:
				_parameter_values[exp_param.name] = received_param
			else:
				parameter_errors.append("Parameter %s value does not match the expected type %s." % [exp_param.name, AIToolParameter.ParameterType.find_key(exp_param.type)])
	return parameter_errors


func _read_option(option_id:String) -> Variant:
	if _options_by_key.has(option_id):
		#The value in the dictionary is #AIToolOption
		return _option_values.get(option_id, _options_by_key[option_id].get_default_value())
	else:
		AIHubPlugin.print_err("Option with ID %s not found in tool %s " % [option_id, _resource.id])
		return null


func get_success_message() -> Variant:
	return _success_message


# All functions below must be overriden by child classes
func execute() -> bool:
	return false


func undo() -> bool:
	_errors.append("Undo not implemented for this tool.")
	return false


func _register_undo() -> String:
	var execution_id: = str(Time.get_ticks_msec())
	_tool_undo_queue.add_entry(execution_id, self)
	return execution_id
