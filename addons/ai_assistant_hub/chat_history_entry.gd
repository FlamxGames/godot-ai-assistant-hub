@tool
class_name ChatHistoryEntry
extends HBoxContainer

signal modified(entry:ChatHistoryEntry)

@onready var role_option_list: OptionButton = %RoleOptionList
@onready var content_txt: TextEdit = %ContentTxt
@onready var forget_check_box: CheckBox = %ForgetCheckBox


func initialize(data:Dictionary, assistant_role_name:String) -> void:
	await ready
	if data["role"] == assistant_role_name:
		role_option_list.selected = 1
	content_txt.text = data["content"]


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
