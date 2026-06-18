@tool
class_name AIToolOptionUIArray
extends AIToolOptionUIAbstract

@onready var invalid_mark: TextureRect = %InvalidMark
@onready var label: Label = %Label
@onready var item_list: ItemList = %ItemList

var _valid:bool


func initialize(option:AIToolOption, values) -> void:
	if not is_node_ready():
		await ready
	_option = option
	label.text = option.name
	label.tooltip_text = option.description
	if values:
		if not values is Array:
			AIHubPlugin.print_msg("AIToolOptionUIArray initialized with a value different to an array.")
			return
		for item in values:
			item_list.add_item(str(item))
	validate_for_empty()


func get_value() -> Array:
	var result = []
	for i in item_list.item_count:
		var text := item_list.get_item_text(i)
		if not text.is_empty():
			result.append(text)
	return result


func is_valid() -> bool:
	return _valid


func _on_add_btn_pressed() -> void:
	var dialog := EditorFileDialog.new()
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	if _option.type == AIToolOption.OptionType.ArrayOfProjectDir:
		dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
		dialog.dir_selected.connect(_dir_selected)
	if _option.type == AIToolOption.OptionType.ArrayOfProjectFiles:
		dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
		dialog.files_selected.connect(_files_selected)
	add_child(dialog)
	dialog.popup_file_dialog()


func _on_remove_btn_pressed() -> void:
	var selected_indices := item_list.get_selected_items()
	selected_indices.sort()
	selected_indices.reverse()
	for index in selected_indices:
		item_list.remove_item(index)
	validate_for_empty()


func validate_for_empty() -> void:
	if not _option.allow_null and item_list.item_count == 0:
		_valid = false
	else:
		_valid = true
	invalid_mark.visible = not _valid


func _dir_selected(dir: String) -> void:
	item_list.add_item(dir)
	validate_for_empty()


func _files_selected(paths: PackedStringArray) -> void:
	for p in paths:
		item_list.add_item(p)
	validate_for_empty()
