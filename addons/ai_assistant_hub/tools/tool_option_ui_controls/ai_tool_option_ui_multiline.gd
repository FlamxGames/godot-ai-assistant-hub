@tool
class_name AIToolOptionUIMultiline
extends AIToolOptionUIAbstract

@onready var invalid_mark: TextureRect = %InvalidMark
@onready var label: Label = %Label
@onready var text_edit: TextEdit = %TextEdit


var _valid:bool


func initialize(option:AIToolOption, value) -> void:
	if not is_node_ready():
		await ready
	if value == null:
		value = ""
	_option = option
	label.text = option.name
	label.tooltip_text = option.description
	if not option.allow_null:
		text_edit.tooltip_text += " (mandatory)"
	text_edit.text = value
	_on_line_edit_text_changed(value)


func get_value() -> Variant:
	return text_edit.text


func is_valid() -> bool:
	return _valid


func _on_line_edit_text_changed(new_text: String) -> void:
	if _option.type == AIToolOption.OptionType.Int and not new_text.is_empty() and not new_text.is_valid_int():
		_valid = false
	elif _option.type == AIToolOption.OptionType.Float and not new_text.is_empty() and not new_text.is_valid_float():
		_valid = false
	else:
		_valid = true
	


func _on_text_edit_text_changed() -> void:
	_valid = true
	if not _option.allow_null and text_edit.text.is_empty():
		_valid = false
	invalid_mark.visible = not _valid
