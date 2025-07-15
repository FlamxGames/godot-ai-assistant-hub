@tool
class_name AIConversation

var _chat_history:= []
var _system_msg: String
var _system_role_name:String
var _user_role_name:String
var _assistant_role_name:String


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
	# If your models don't mark the code with ```gdscript, the plugin won't wort well,
	# consider giving it an instruction like the one in the comment below, either in the
	# _system_msg or as part of the bot initial request.
	#
	#_system_msg = "%s. Any code you write you should identify with the programming language, for example for GDScript you must use prefix \"```gdscript\" and suffix \"```\"." % message
	#


func add_user_prompt(prompt:String) -> void:
	_chat_history.append(
		{
			"role": _user_role_name,
			"content": prompt
		}
	)


func add_assistant_response(response:String) -> void:
	_chat_history.append(
		{
			"role": _assistant_role_name,
			"content": response
		}
	)


func build() -> Array:
	var messages := []
	messages.append(
		{
			"role": _system_role_name,
			"content": _system_msg
		}
	)
	messages.append_array(_chat_history)
	return messages


func forget_last_prompt() -> void:
	_chat_history.pop_back()


func clone_chat() -> Array:
	return _chat_history.duplicate(true)


func overwrite_chat(new_chat:Array) -> void:
	_chat_history = new_chat
