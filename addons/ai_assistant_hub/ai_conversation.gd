@tool
class_name AIConversation

signal chat_appended(new_entry:Dictionary)
signal chat_edited(chat_history:Array)

var _chat_history:= []
var _system_msg: String
var _system_role_name:String
var _user_role_name:String
var _assistant_role_name:String
var _tool_role_name:String
var _estimated_token_size:int


func _init(system_role_name:String, user_role_name:String, assistant_role_name:String, tool_role_name:String):
	_system_role_name = system_role_name
	_user_role_name = user_role_name
	_assistant_role_name = assistant_role_name
	_tool_role_name = tool_role_name


func get_system_role_name() -> String:
	return _system_role_name


func get_user_role_name() -> String:
	return _user_role_name


func get_assistant_role_name() -> String:
	return _assistant_role_name


func set_system_message(message:String) -> void:
	_system_msg = message


func get_system_message() -> String:
	return _system_msg


func add_user_prompt(prompt:String) -> void:
	var entry := {
		"role": _user_role_name,
		"content": prompt
	}
	_chat_history.append(entry)
	chat_appended.emit(entry)


func add_tool_feedback(feedback:String) -> void:
	var entry := {
		"role": _tool_role_name,
		"content": feedback
	}
	_chat_history.append(entry)
	chat_appended.emit(entry)


func add_assistant_response(response:AIAssistantResponse) -> void:
	var entry := {
		"role": _assistant_role_name
	}
	if not response.text_content.is_empty():
		entry["content"] = response.text_content
	if response.tool_calls and not response.tool_calls.is_empty() and response.tool_calls_raw:
		entry["tool_calls"] = clean_json_types(response.tool_calls_raw)
	_chat_history.append(entry)
	chat_appended.emit(entry)


## Recursive function to fix whole numbers in JSON
## JSON spec dpes not have concept of integer or float, so Godot converts ints
## to floats when the JSON is parsed, and this causes issues when including this
## information in the chat history.
func clean_json_types(data):
	if data is Dictionary:
		var new_dict = {}
		for key in data:
			new_dict[key] = clean_json_types(data[key])
		return new_dict
	elif data is Array:
		return data.map(clean_json_types)
	elif data is float and fmod(data, 1.0) == 0.0:
		# If the float has no decimal remainder, make it an int
		return int(data)
	return data


func build() -> Array:
	var messages := []
	messages.append(
		{
			"role": _system_role_name,
			"content": _system_msg
		}
	)
	messages.append_array(_chat_history)
	_estimated_token_size = JSON.stringify(messages).length() / 4 # basic heuristic
	return messages


#func forget_last_prompt() -> void: #This needs more polishing
	#_chat_history.pop_back()
	#chat_edited.emit(_chat_history)


func clone_chat() -> Array:
	return _chat_history.duplicate(true)


func overwrite_chat(new_chat:Array) -> void:
	_chat_history = new_chat
	chat_edited.emit(_chat_history)


func get_estimated_token_size() -> int:
	return _estimated_token_size
