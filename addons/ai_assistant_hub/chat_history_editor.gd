@tool
class_name ChatHistoryEditor
extends Window

const CHAT_HISTORY_ENTRY = preload("res://addons/ai_assistant_hub/chat_history_entry.tscn")

@onready var entries_container: VBoxContainer = %EntriesContainer
@onready var background: Panel = %Background

var _converstaion:AIConversation
var _chat_history:Array
var _entries_map:Dictionary # ChatHistoryEntry, Dictionary - maps the UI entries to the array entries

func initialize(converstaion:AIConversation) -> void:
	_converstaion = converstaion
	_chat_history = _converstaion.clone_chat()
	await ready
	
	var back_color:= EditorInterface.get_base_control().get_theme_color("base_color", "Editor")
	background.get_theme_stylebox("panel").bg_color = back_color
	
	for section in _chat_history:
		var entry:ChatHistoryEntry = CHAT_HISTORY_ENTRY.instantiate()
		entry.initialize(section, _converstaion.get_assistant_role_name())
		entries_container.add_child(entry)
		_entries_map[entry] = section
		entry.modified.connect(_on_entry_modified)


func _on_entry_modified(entry:ChatHistoryEntry) -> void:
	var section:Dictionary = _entries_map[entry]
	section["role"] = entry.get_role()
	section["content"] = entry.get_content()


func _on_save_and_close_btn_pressed() -> void:
	for entry in _entries_map.keys():
		if entry.should_be_forgotten():
			_chat_history.erase(_entries_map[entry])
	_converstaion.overwrite_chat(_chat_history)
	queue_free()


func _on_close_requested() -> void:
	queue_free()
