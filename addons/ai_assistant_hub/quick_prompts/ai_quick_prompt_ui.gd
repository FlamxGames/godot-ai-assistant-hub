@tool
class_name AIQuickPromptUI
extends MarginContainer

signal moved(item:AIQuickPromptUI, current_index:int, new_index:int)
signal delete_request(current_index:int)

const AI_TOOLS_ACCESS_WINDOW = preload("res://addons/ai_assistant_hub/tools/ai_tools_access_window.tscn")

@onready var resource_picker_placeholder: MarginContainer = %ResourcePickerPlaceholder
@onready var icon_placeholder: MarginContainer = %IconPlaceholder
@onready var delete_confirmation_dialog: ConfirmationDialog = %DeleteConfirmationDialog
@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var limit_tools_toggle: CheckButton = %LimitToolsToggle
@onready var tool_access_btn: Button = %ToolAccessBtn
@onready var prompt_text_edit: TextEdit = %PromptTextEdit
@onready var up_pos_btn: Button = %UpPosBtn
@onready var down_pos_btn: Button = %DownPosBtn

var _resource_picker: EditorResourcePicker
var _icon_picker: EditorResourcePicker
var _resource: AIQuickPromptResource
var _current_index:int
var _has_tools_capability:bool


func initialize(resource: AIQuickPromptResource, has_tools_capability:bool) -> void:
	_has_tools_capability = has_tools_capability
	if not self.is_node_ready():
		await ready
	if resource == null:
		_resource = AIQuickPromptResource.new()
	else:
		if resource.resource_path.get_extension() == "tres":
			_on_resource_selected(resource)
		else:
			_on_resource_selected(resource.duplicate())
	_resource_picker.edited_resource = _resource
	limit_tools_toggle.visible = _has_tools_capability


func _ready():
	_resource_picker = EditorResourcePicker.new()
	_resource_picker.base_type = "AIQuickPromptResource" 
	_resource_picker.resource_changed.connect(_on_resource_selected)
	resource_picker_placeholder.add_child(_resource_picker)
	
	_icon_picker = EditorResourcePicker.new()
	_icon_picker.base_type = "Texture2D" 
	icon_placeholder.add_child(_icon_picker)


func _on_resource_selected(resource: AIQuickPromptResource) -> void:
	if resource == null: #In case the user clears the resource
		resource = AIQuickPromptResource.new()
		_resource_picker.edited_resource = resource
	_resource = resource
	name_line_edit.text = resource.action_name
	_icon_picker.edited_resource = resource.icon
	limit_tools_toggle.button_pressed = resource.limit_tool_access
	prompt_text_edit.text = resource.action_prompt


func _on_delete_btn_pressed() -> void:
	delete_confirmation_dialog.popup()


func _on_delete_confirmation_dialog_confirmed() -> void:
	delete_request.emit(_current_index)


func _on_limit_tools_toggle_toggled(toggled_on: bool) -> void:
	tool_access_btn.visible = toggled_on
	if toggled_on and not _resource.tool_access:
		_resource.tool_access = AIToolAccessProfile.new()
	elif not toggled_on:
		_resource.tool_access = null


func _on_tool_access_btn_pressed() -> void:
	var tools_access_window:AIToolsAccessWindow = AI_TOOLS_ACCESS_WINDOW.instantiate()
	tools_access_window.saved.connect(_on_tools_access_window_saved)
	tools_access_window.initialize(_resource.tool_access, false)
	add_child(tools_access_window)
	tools_access_window.popup()


func _on_tools_access_window_saved(access_profile:AIToolAccessProfile) -> void:
	_resource.tool_access = access_profile


func save_and_get_resource() -> AIQuickPromptResource:
	_resource.action_name = name_line_edit.text
	_resource.icon = _icon_picker.edited_resource
	_resource.limit_tool_access = limit_tools_toggle.button_pressed
	_resource.action_prompt = prompt_text_edit.text
	if _resource.resource_path.get_extension() == "tres":
		var err = ResourceSaver.save(_resource, _resource.resource_path)
		if err != OK:
			AIHubPlugin.print_err("Failed to save AIQuickPromptResource to %s: %s" % [_resource.resource_path, str(err)])
	return _resource


func _on_code_keyword_btn_pressed() -> void:
	prompt_text_edit.text += "{CODE}"


func _on_chat_keyword_btn_pressed() -> void:
	prompt_text_edit.text += "{CHAT}"


func _on_up_pos_btn_pressed() -> void:
	moved.emit(self, _current_index, _current_index - 1)


func _on_down_pos_btn_pressed() -> void:
	moved.emit(self, _current_index, _current_index + 1)


func notify_index(current_index:int, total_count:int) -> void:
	_current_index = current_index
	if total_count > 1:
		if current_index == 0:
			up_pos_btn.visible = false
			down_pos_btn.visible = true
		elif current_index == total_count - 1:
			up_pos_btn.visible = true
			down_pos_btn.visible = false
		else:
			up_pos_btn.visible = true
			down_pos_btn.visible = true
	else:
		up_pos_btn.visible = false
		down_pos_btn.visible = false
