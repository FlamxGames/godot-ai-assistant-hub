@tool
class_name AIConversation

signal chat_appended(new_entry:Dictionary)
signal chat_edited(chat_history:Array)

var _chat_history:= []
var _system_msg: String
var _system_role_name:String
var _user_role_name:String
var _assistant_role_name:String
var _estimated_token_size:int


func _init(system_role_name:String, user_role_name:String, assistant_role_name:String):
	_system_role_name = system_role_name
	_user_role_name = user_role_name
	_assistant_role_name = assistant_role_name


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


func add_assistant_response(response:String) -> void:
	var entry := {
		"role": _assistant_role_name,
		"content": response
	}
	_chat_history.append(entry)
	chat_appended.emit(entry)


func build() -> Array:
	var messages := []
	messages.append(
		{
			"role": _system_role_name,
			"content": _system_msg
		}
	)
	messages.append_array(_chat_history)
	_estimated_token_size = JSON.stringify(messages).length() / 4
	return messages


func forget_last_prompt() -> void:
	_chat_history.pop_back()
	chat_edited.emit(_chat_history)


func clone_chat() -> Array:
	return _chat_history.duplicate(true)


func overwrite_chat(new_chat:Array) -> void:
	_chat_history = new_chat
	chat_edited.emit(_chat_history)


func get_estimated_token_size() -> int:
	return _estimated_token_size
