@tool
class_name AIToolOptionUISimpleValue
extends AIToolOptionUIAbstract

@onready var invalid_mark: TextureRect = %InvalidMark
@onready var label: Label = %Label
@onready var line_edit: LineEdit = %LineEdit

var _valid:bool


func initialize(option:AIToolOption, value) -> void:
	if not is_node_ready():
		await ready
	if value == null:
		value = ""
	_option = option
	label.text = option.name
	label.tooltip_text = option.description
	match option.type:
		AIToolOption.OptionType.Int:
			line_edit.tooltip_text = "Enter an integer value"
		AIToolOption.OptionType.Float:
			line_edit.tooltip_text = "Enter a numeric value"
		AIToolOption.OptionType.StringLine:
			line_edit.tooltip_text = "Enter a value"
	if not option.allow_null:
		line_edit.tooltip_text += " (mandatory)"
	line_edit.text = value
	_on_line_edit_text_changed(value)


func get_value() -> Variant:
	if line_edit.text.is_empty():
		return ""
	if _option.type == AIToolOption.OptionType.Int:
		return int(line_edit.text)
	if _option.type == AIToolOption.OptionType.Float:
		return float(line_edit.text)
	return line_edit.text


func is_valid() -> bool:
	return _valid


func _on_line_edit_text_changed(new_text: String) -> void:
	if _option.type == AIToolOption.OptionType.Int and not new_text.is_empty() and not new_text.is_valid_int():
		_valid = false
	elif _option.type == AIToolOption.OptionType.Float and not new_text.is_empty() and not new_text.is_valid_float():
		_valid = false
	else:
		_valid = true
	if not _option.allow_null and new_text.is_empty():
		_valid = false
	invalid_mark.visible = not _valid
