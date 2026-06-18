@tool
class_name AIToolOptionUICheckbox
extends AIToolOptionUIAbstract

@onready var label: Label = %Label
@onready var check_box: CheckBox = %CheckBox


func initialize(option:AIToolOption, value) -> void:
	if not is_node_ready():
		await ready
	if value == null:
		value = false
	if not value is bool:
		AIHubPlugin.print_msg("AIToolOptionUICheckbox initialized with a value different to a boolean.")
		return
	_option = option
	label.text = option.name
	label.tooltip_text = option.description
	check_box.button_pressed = value


func get_value() -> bool:
	return check_box.button_pressed


func is_valid() -> bool:
	return true
