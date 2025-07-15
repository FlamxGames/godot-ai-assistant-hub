@tool
class_name NewAIAssistantTypeWindow
extends Window

signal assistant_type_created

@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var prompt_text_edit: TextEdit = %PromptTextEdit
@onready var model_line_edit: LineEdit = %ModelLineEdit
@onready var res_name_line_edit: LineEdit = %ResNameLineEdit
@onready var create_button: Button = %CreateButton
@onready var create_note_label: Label = %CreateNoteLabel
@onready var api_label: Label = %APILabel

var _assistants_path:String
var _llm_provider:LLMProviderResource


func initialize(llm_provider:LLMProviderResource, model_name:String, assistants_path:String) -> void:
	_assistants_path = assistants_path
	_llm_provider = llm_provider
	await ready
	model_line_edit.text = model_name
	create_note_label.text = create_note_label.text % _assistants_path
	api_label.text = _llm_provider.name


func _on_name_line_edit_text_changed(new_text: String) -> void:
	if new_text.is_empty():
		res_name_line_edit.text = ""
	else:
		res_name_line_edit.text = "ai_%s" % new_text.to_lower().replace(" ","_")
	_on_res_name_line_edit_text_changed(res_name_line_edit.text)


func _on_create_button_pressed() -> void:
	var res = AIAssistantResource.new()
	res.ai_description = prompt_text_edit.text
	res.ai_model = model_line_edit.text
	res.llm_provider = _llm_provider
	res.type_name = name_line_edit.text
	var path:= _assistants_path + "/" + res_name_line_edit.text + ".tres"
	res.take_over_path(path)
	var error := ResourceSaver.save(res, path)
	if error != OK:
		printerr("Error while creating the new assistant type resource. Error code: %d" % error)
	else:
		assistant_type_created.emit()
	EditorInterface.edit_resource(res)
	queue_free()


func _on_close_requested() -> void:
	queue_free()


func _on_res_name_line_edit_text_changed(new_text: String) -> void:
	create_button.disabled = new_text.is_empty()
