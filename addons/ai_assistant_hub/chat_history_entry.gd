@tool
class_name ChatHistoryEntry
extends HBoxContainer

signal modified(entry:ChatHistoryEntry)

const MAX_LINES := 5

@onready var role_option_list: OptionButton = %RoleOptionList
@onready var content_txt: TextEdit = %ContentTxt
@onready var forget_check_box: CheckBox = %ForgetCheckBox


func initialize(data:Dictionary, user_role_name:String, assistant_role_name:String) -> void:
	await ready
	match data["role"]:
		user_role_name: role_option_list.selected = 0
		assistant_role_name: role_option_list.selected = 1
		_: role_option_list.selected = 2
	
	if data.has("content"):
		content_txt.text = data["content"]
	if data.has("tool_calls"):
		if not content_txt.text.is_empty():
			content_txt.text += "\n\n"
		content_txt.text += JSON.stringify(data["tool_calls"],"\t")
		content_txt.editable = false
	await get_tree().process_frame
	if content_txt.get_visible_line_count() > MAX_LINES:
		content_txt.scroll_fit_content_height = false
		content_txt.custom_minimum_size.y = content_txt.get_line_height() * MAX_LINES


func get_role() -> String:
	return role_option_list.text


func get_content() -> String:
	return content_txt.text


func should_be_forgotten() -> bool:
	return forget_check_box.button_pressed


func _on_content_txt_text_changed() -> void:
	modified.emit(self)


func _on_role_option_list_item_selected(index: int) -> void:
	modified.emit(self)
