@tool
class_name AIToolCall


var tool_id: String:
	get: return tool_id


var parameters: Dictionary: # String (parameter name), Variant (parameter value)
	get: return parameters


var call_id: String:
	get: return call_id


func _init(tool_id: String, parameters: Dictionary = {}, call_id: String = "") -> void:
	self.tool_id = tool_id
	self.parameters = parameters
	self.call_id = call_id
