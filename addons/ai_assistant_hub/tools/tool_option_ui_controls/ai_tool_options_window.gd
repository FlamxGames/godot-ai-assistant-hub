@tool
class_name AIToolOptionsWindow
extends Window

signal saved(tool:AIToolResource, option_values:Dictionary)
signal saved_global(option_values:Dictionary)

const ARRAY_CONTROL = preload("res://addons/ai_assistant_hub/tools/tool_option_ui_controls/ai_tool_option_ui_array.tscn")
const CHECKBOX_CONTROL = preload("res://addons/ai_assistant_hub/tools/tool_option_ui_controls/ai_tool_option_ui_checkbox.tscn")
const SIMPLE_VALUE_CONTROL = preload("res://addons/ai_assistant_hub/tools/tool_option_ui_controls/ai_tool_option_ui_simple_value.tscn")
const MULTILINE_CONTROL = preload("res://addons/ai_assistant_hub/tools/tool_option_ui_controls/ai_tool_option_ui_multiline.tscn")

@onready var items_container: VBoxContainer = %ItemsContainer
@onready var invalid_alert_dialog: AcceptDialog = %InvalidAlertDialog
@onready var label_global: Label = %LabelGlobal
@onready var label_individual: Label = %LabelIndividual


var _tool:AIToolResource
var _option_controls:Array[AIToolOptionUIAbstract] = []


## option_values must match definition in AIToolAccess
func initialize(tool:AIToolResource, option_values:Dictionary) -> void:
	_tool = tool
	initialize_global(tool.options, option_values)


func initialize_global(options:Array[AIToolOption], option_values:Dictionary) -> void:
	for o in options:
		var option:AIToolOption = o
		var value = null
		if option_values and option_values.has(option.id):
			value = option_values[option.id]
		var control:AIToolOptionUIAbstract
		match option.type:
			AIToolOption.OptionType.Int, AIToolOption.OptionType.Float, AIToolOption.OptionType.StringLine:
				control = SIMPLE_VALUE_CONTROL.instantiate()
			AIToolOption.OptionType.StringMultiLine:
				control = MULTILINE_CONTROL.instantiate()
			AIToolOption.OptionType.Boolean:
				control = CHECKBOX_CONTROL.instantiate()
			AIToolOption.OptionType.ArrayOfProjectDir, AIToolOption.OptionType.ArrayOfProjectFiles:
				control = ARRAY_CONTROL.instantiate()
		control.initialize(option, value)
		_option_controls.append(control)
	add_controls_to_ui()


func add_controls_to_ui() -> void:
	if not is_node_ready():
		await ready
	var parent:Control = items_container
	for i in _option_controls.size():
		if i < _option_controls.size() - 1: #There are still 2 elements to add
			var split = VSplitContainer.new()
			split.size_flags_vertical = Control.SIZE_EXPAND_FILL
			split.add_theme_constant_override("separation", 10)
			parent.add_child(split)
			parent = split
		parent.add_child(_option_controls[i])
	await get_tree().process_frame
	label_individual.visible = _tool != null
	label_global.visible = _tool == null
	move_to_center()


func _on_close_requested() -> void:
	queue_free()


func _on_save_btn_pressed() -> void:
	var values = {}
	for control in _option_controls:
		if not control.is_valid():
			invalid_alert_dialog.popup()
			return
		values[control.get_option_id()] = control.get_value()
	if _tool:
		saved.emit(_tool, values)
	else:
		saved_global.emit(values)
	queue_free()
