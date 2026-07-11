@tool
class_name NewAIAssistantTypeWindow
extends Window

signal assistant_type_created
signal assistant_type_edited

const AI_TOOLS_ACCESS_WINDOW = preload("res://addons/ai_assistant_hub/tools/ai_tools_access_window.tscn")
const AI_QUICK_PROMPTS_WINDOW = preload("res://addons/ai_assistant_hub/quick_prompts/ai_quick_prompts_window.tscn")

@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var prompt_text_edit: TextEdit = %PromptTextEdit
@onready var res_name_line_edit: LineEdit = %ResNameLineEdit
@onready var create_button: Button = %CreateButton
@onready var model_api_value_label: Label = %ModelAPIValueLabel
@onready var tools_label: Label = %ToolsLabel
@onready var tools_button: Button = %ToolsButton
@onready var disclaimer: Label = %Disclaimer
@onready var icon_placeholder: Control = %IconPlaceholder
@onready var close_confirmation_dialog: ConfirmationDialog = %CloseConfirmationDialog
@onready var context_label: Label = %ContextLabel
@onready var context_line_edit: LineEdit = %ContextLineEdit


var _assistants_path:String
var _llm_provider:LLMProviderResource
var _model_name:String
var _tools_access:AIToolAccessProfile
var _quick_prompts:Array[AIQuickPromptResource]
var _editing_assistant_type:AIAssistantResource
var _image_resource_picker: EditorResourcePicker
var _dirty:bool
var _has_tools_capability:bool

func _ready():
	_image_resource_picker = EditorResourcePicker.new()
	_image_resource_picker.base_type = "Texture2D" 
	_image_resource_picker.resource_changed.connect(_on_image_resource_picker_resource_changed)
	icon_placeholder.add_child(_image_resource_picker)


func _on_image_resource_picker_resource_changed(_resource:Resource) -> void:
	_dirty = true


func initialize_to_edit(assistant_type: AIAssistantResource, capabilities:Array[LLMInterface.Capabilities]) -> void:
	await ready
	_editing_assistant_type = assistant_type
	_image_resource_picker.edited_resource = _editing_assistant_type.type_icon 
	_llm_provider = assistant_type.llm_provider
	_model_name = assistant_type.ai_model
	_tools_access = assistant_type.tool_access
	_quick_prompts = assistant_type.quick_prompts
	name_line_edit.editable = false
	model_api_value_label.text = "%s — %s" % [_model_name, _llm_provider.name]
	title = "Edit AI Assistant Type: %s" % assistant_type.type_name
	disclaimer.text = "You are editing model %s. All assistants using this model will be affected." % assistant_type.type_name
	create_button.text = "Save and close"
	create_button.tooltip_text = disclaimer.text
	create_button.disabled = false
	name_line_edit.text = assistant_type.type_name
	prompt_text_edit.text = assistant_type.ai_description
	res_name_line_edit.text = assistant_type.resource_path.get_file().get_basename()
	res_name_line_edit.editable = false
	context_label.visible = assistant_type.llm_provider.supports_context_size_override
	context_line_edit.visible = assistant_type.llm_provider.supports_context_size_override
	if assistant_type.context_length > 0:
		context_line_edit.text = str(assistant_type.context_length)
	_read_capabilitites(capabilities)


func initialize(llm_provider:LLMProviderResource, model_name:String, capabilities:Array[LLMInterface.Capabilities], assistants_path:String) -> void:
	_assistants_path = assistants_path
	_llm_provider = llm_provider
	await ready
	_model_name = model_name
	model_api_value_label.text = "%s — %s" % [model_name, _llm_provider.name]
	create_button.tooltip_text = """
This will create a resource under %s using this resource name.
- You will see a new button in the AI Hub tab, click it to start a new chat with your assistant.
- The resource will open in the Inspector editor, there you can add an icon, Quick Prompts, and other optional properties.
	""" % _assistants_path
	_read_capabilitites(capabilities)


func _read_capabilitites(capabilities:Array[LLMInterface.Capabilities]) -> void:
	_has_tools_capability = capabilities.has(LLMInterface.Capabilities.Tools)
	tools_button.visible = _has_tools_capability


func _on_name_line_edit_text_changed(new_text: String) -> void:
	_dirty = true
	if _editing_assistant_type == null:
		if new_text.is_empty():
			res_name_line_edit.text = ""
		else:
			res_name_line_edit.text = "ai_%s" % new_text.to_lower().replace(" ","_").validate_filename()
		_on_res_name_line_edit_text_changed(res_name_line_edit.text)


func _on_create_button_pressed() -> void:
	if _editing_assistant_type:
		_save_edits_and_close()
	else:
		_create_new_and_close()


func _save_edits_and_close() -> void:
	_editing_assistant_type.ai_description = prompt_text_edit.text
	_editing_assistant_type.type_icon = _image_resource_picker.edited_resource
	_editing_assistant_type.type_name = name_line_edit.text
	_editing_assistant_type.tool_access = _tools_access
	_editing_assistant_type.quick_prompts = _quick_prompts
	if context_line_edit.text.is_valid_int():
		_editing_assistant_type.context_length = context_line_edit.text.to_int()
	else:
		_editing_assistant_type.context_length = 0
	_editing_assistant_type.take_over_path(_editing_assistant_type.resource_path)
	var error := ResourceSaver.save(_editing_assistant_type, _editing_assistant_type.resource_path)
	if error != OK:
		AIHubPlugin.print_err("Error while saving the assistant type resource. Error code: %d" % error)
	else:
		assistant_type_edited.emit()
	queue_free()


func _create_new_and_close() -> void:
	var res = AIAssistantResource.new()
	res.ai_description = prompt_text_edit.text
	res.type_icon = _image_resource_picker.edited_resource
	res.ai_model = _model_name
	res.llm_provider = _llm_provider
	res.type_name = name_line_edit.text
	res.tool_access = _tools_access
	res.quick_prompts = _quick_prompts
	if context_line_edit.text.is_valid_int():
		res.context_length = context_line_edit.text.to_int()
	else:
		res.context_length = 0
	var path:= _assistants_path + "/" + res_name_line_edit.text.validate_filename() + ".tres"
	res.take_over_path(path)
	var error := ResourceSaver.save(res, path)
	if error != OK:
		AIHubPlugin.print_err("Error while creating the new assistant type resource. Error code: %d" % error)
	else:
		assistant_type_created.emit()
	#EditorInterface.edit_resource(res) - we don't encourage editing it in the inspector anymore, since we want to propagate changes automatically
	queue_free()


func _on_close_requested() -> void:
	if _dirty:
		close_confirmation_dialog.popup()
	else:
		queue_free()


func _on_res_name_line_edit_text_changed(new_text: String) -> void:
	create_button.disabled = new_text.is_empty()


func _on_tools_button_pressed() -> void:
	_dirty = true
	var tools_access_window:AIToolsAccessWindow = AI_TOOLS_ACCESS_WINDOW.instantiate()
	if not _tools_access:
		_tools_access = AIToolAccessProfile.new()
	tools_access_window.saved.connect(_on_tools_access_window_saved)
	tools_access_window.initialize(_tools_access)
	add_child(tools_access_window)
	tools_access_window.popup()


func _on_tools_access_window_saved(access_profile:AIToolAccessProfile) -> void:
	_tools_access = access_profile


func _on_quick_prompts_button_pressed() -> void:
	_dirty = true
	var quick_prompts_window:AIQuickPromptsWindow = AI_QUICK_PROMPTS_WINDOW.instantiate()
	if not _quick_prompts:
		_quick_prompts = []
	quick_prompts_window.initialize(_quick_prompts, _has_tools_capability)
	add_child(quick_prompts_window)
	quick_prompts_window.saved.connect(_on_quick_prompts_window_saved)
	quick_prompts_window.popup()


func _on_quick_prompts_window_saved(new_quick_prompts: Array[AIQuickPromptResource]) -> void:
	_quick_prompts = new_quick_prompts


func _on_prompt_text_edit_text_changed() -> void:
	_dirty = true


func _on_close_confirmation_dialog_confirmed() -> void:
	queue_free()


func _on_context_line_edit_text_changed(new_text: String) -> void:
	_dirty = true
	if not new_text.is_empty() and not new_text.is_valid_int():
		context_line_edit.text = ""
