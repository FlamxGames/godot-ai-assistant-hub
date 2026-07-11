@tool
class_name AIQuickPromptsWindow
extends Window

signal saved(quick_prompts:Array[AIQuickPromptResource])

const AI_QUICK_PROMPT_UI = preload("res://addons/ai_assistant_hub/quick_prompts/ai_quick_prompt_ui.tscn")

@onready var scroll_container: ScrollContainer = %ScrollContainer
@onready var scroll_content_container: VBoxContainer = %ScrollContentContainer

var _has_tools_capability:bool


func initialize(existing_quick_prompts: Array[AIQuickPromptResource], has_tools_capability:bool) -> void:
	_has_tools_capability = has_tools_capability
	if not self.is_node_ready():
		await ready
	for i in existing_quick_prompts.size():
		var entry := await _add_quick_prompt_entry(existing_quick_prompts[i])
		entry.notify_index(i, existing_quick_prompts.size())


func _on_close_requested() -> void:
	var quick_prompts:Array[AIQuickPromptResource] = []
	for entry in scroll_content_container.get_children():
		var res: AIQuickPromptResource = entry.save_and_get_resource()
		quick_prompts.append(res)
	saved.emit(quick_prompts)
	queue_free()


func _on_add_new_btn_pressed() -> void:
	var entry := await _add_quick_prompt_entry(null)
	var total:= scroll_content_container.get_child_count()
	entry.notify_index(total - 1, total)
	if total > 1:
		scroll_content_container.get_child(total - 2).notify_index(total - 2, total)
	await get_tree().process_frame
	await get_tree().process_frame
	scroll_container.scroll_vertical = scroll_content_container.size.y


func _add_quick_prompt_entry(quick_prompt_resource: AIQuickPromptResource) -> AIQuickPromptUI:
	var entry = AI_QUICK_PROMPT_UI.instantiate()
	entry.delete_request.connect(_on_entry_delete_request)
	entry.moved.connect(_on_entry_moved)
	scroll_content_container.add_child(entry)
	await entry.initialize(quick_prompt_resource, _has_tools_capability)
	return entry


func _on_entry_delete_request(current_index:int) -> void:
	var new_count = scroll_content_container.get_child_count() - 1
	if current_index > 0:
		scroll_content_container.get_child(current_index - 1).notify_index(current_index - 1, new_count)
	if current_index < scroll_content_container.get_child_count() - 1:
		scroll_content_container.get_child(current_index + 1).notify_index(current_index, new_count)
	scroll_content_container.get_child(current_index).queue_free()


func _on_entry_moved(entry:AIQuickPromptUI, current_index:int, new_index:int) -> void:
	var other_moved = scroll_content_container.get_child(new_index)
	scroll_content_container.move_child(entry, new_index)
	other_moved.notify_index(current_index, scroll_content_container.get_child_count())
	entry.notify_index(new_index, scroll_content_container.get_child_count())
