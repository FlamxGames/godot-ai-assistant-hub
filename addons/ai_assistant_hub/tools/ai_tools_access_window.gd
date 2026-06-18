@tool
class_name AIToolsAccessWindow
extends Window

signal saved(access_profile:AIToolAccessProfile)

enum Columns { Tool, Allow, Ask, Hide, Options, Reset }

const TOOLS_PATH := "res://addons/ai_assistant_hub/tools"
const OPTIONS_ICON = preload("res://addons/ai_assistant_hub/graphics/icons/gear_16.svg")
const RESET_ICON = preload("res://addons/ai_assistant_hub/graphics/icons/Reload.svg")
const AI_TOOL_OPTIONS_WINDOW = preload("res://addons/ai_assistant_hub/tools/tool_option_ui_controls/ai_tool_options_window.tscn")

@onready var tree: Tree = %Tree
@onready var advanced_setup_container: HBoxContainer = %AdvancedSetupContainer
@onready var save_default_confirmation_dialog: ConfirmationDialog = %SaveDefaultConfirmationDialog
@onready var reset_all_confirmation_dialog: ConfirmationDialog = %ResetAllConfirmationDialog
@onready var resource_placeholder: MarginContainer = %ResourcePlaceholder
@onready var reset_btn: Button = %ResetBtn
@onready var save_default_btn: Button = %SaveDefaultBtn


var _all_tools:Array[AIToolResource]
var _tools_by_category:Dictionary
var _access_profile:AIToolAccessProfile
var _custom_base_profile:AIToolAccessProfile
var _resource_picker: EditorResourcePicker
var _use_default_access:bool


func initialize(access_profile:AIToolAccessProfile, use_default_access := true) -> void:
	if access_profile.resource_path.get_extension() == "tres":
		_access_profile = access_profile
	else:
		_access_profile = AIToolAccessProfile.create_from_profiles_in_order([access_profile])
	_use_default_access = use_default_access


func _ready() -> void:
	if not _access_profile:
		return #This is required to avoid this running while editing the window
	
	tree.set_column_title(Columns.Tool, "Tool")
	tree.set_column_expand_ratio(Columns.Tool, 1)
	tree.set_column_title(Columns.Allow, "Allow")
	tree.set_column_expand_ratio(Columns.Allow, 0)
	tree.set_column_title(Columns.Ask, "Ask")
	tree.set_column_expand_ratio(Columns.Ask, 0)
	tree.set_column_title(Columns.Hide, "Hide")
	tree.set_column_expand_ratio(Columns.Hide, 0)
	tree.set_column_title(Columns.Options, "Options")
	tree.set_column_expand_ratio(Columns.Options, 0)
	tree.set_column_title(Columns.Reset, "Reset")
	tree.set_column_expand_ratio(Columns.Reset, 0)
	var root = tree.create_item()
	tree.hide_root = true
	
	_find_tools()
	#var categories:Array[AIToolCategory] = _tools_by_category.keys() #unsupported in Godot 4.3
	var categories:= _tools_by_category.keys()
	categories.sort_custom(AIToolCategory.sort_by_name)
	
	for category in categories:
		var category_entry := tree.create_item(root)
		category_entry.set_text(Columns.Tool, category.name)
		category_entry.set_icon(Columns.Tool, category.icon)
		
		var tools:Array[AIToolResource] = _tools_by_category[category]
		tools.sort_custom(AIToolResource.sort_by_title)
		for tool in tools:
			var tool_entry := tree.create_item(category_entry)
			tool_entry.set_meta("resource", tool)
			tool_entry.set_text(Columns.Tool, tool.title)
			tool_entry.set_tooltip_text(Columns.Tool, "Tool ID: %s\nDescription: %s" % [tool.id, tool.description])
			
			tool_entry.set_tooltip_text(Columns.Allow, "Allow to use this tool at any time.")
			tool_entry.set_cell_mode(Columns.Allow, TreeItem.CELL_MODE_CHECK)
			tool_entry.set_editable(Columns.Allow, true)
			
			tool_entry.set_tooltip_text(Columns.Ask, "You will be prompted to review and confirm before the tool is used.")
			tool_entry.set_cell_mode(Columns.Ask, TreeItem.CELL_MODE_CHECK)
			tool_entry.set_editable(Columns.Ask, true)
			
			tool_entry.set_tooltip_text(Columns.Hide, "The assistant will not be aware of the tool’s existence, reducing unnecessary context and making it easier to select the right tools.")
			tool_entry.set_cell_mode(Columns.Hide, TreeItem.CELL_MODE_CHECK)
			tool_entry.set_editable(Columns.Hide, true)
			
			if tool.options and tool.options.size() > 0:
				tool_entry.add_button(Columns.Options, OPTIONS_ICON)
				tool_entry.set_cell_mode(Columns.Options, TreeItem.CELL_MODE_CUSTOM)
				tool_entry.set_tooltip_text(Columns.Options, "Customize the tool behavior.")
	_load_current_access()
	
	_resource_picker = EditorResourcePicker.new()
	_resource_picker.base_type = "AIToolAccessProfile" 
	_resource_picker.edited_resource = _access_profile
	_resource_picker.resource_changed.connect(_on_resource_changed)
	resource_placeholder.add_child(_resource_picker)
	
	if not _use_default_access:
		reset_btn.visible = false
		save_default_btn.visible = false


func _on_resource_changed(resource: AIToolAccessProfile) -> void:
	if _resource_picker.edited_resource == null or (
		_resource_picker.edited_resource and
			(_resource_picker.edited_resource == LLMInterface.TOOL_DEFAULT_ACCESS_PROFILE
			or _resource_picker.edited_resource.resource_path == LLMInterface.TOOL_CUSTOM_ACCESS_PATH
			)
	):
		_resource_picker.edited_resource = AIToolAccessProfile.new()
	_access_profile = _resource_picker.edited_resource
	_load_current_access()


func _on_close_requested() -> void:
	if _access_profile.resource_path.get_extension() == "tres":
		var err = ResourceSaver.save(_access_profile, _access_profile.resource_path)
		if err != OK:
			AIHubPlugin.print_err("Failed to save AIToolAccessProfile to %s: %s" % [_access_profile.resource_path, str(err)])
	saved.emit(_access_profile)
	queue_free()


func _find_tools() -> void:
	AIHubPlugin.print_msg("Finding tools %s" % TOOLS_PATH)
	var tools_dir := DirAccess.open(TOOLS_PATH)
	if tools_dir:
		_tools_by_category = {}
		tools_dir.list_dir_begin()
		var dir_name := tools_dir.get_next()
		while not dir_name.is_empty():  
			if dir_name.begins_with("_"):
				AIHubPlugin.print_msg("Reading tools under %s" % dir_name)
				var dir := DirAccess.open("%s/%s" % [TOOLS_PATH, dir_name])
				if dir:
					dir.list_dir_begin()
					var file_name = dir.get_next()  
					while not file_name.is_empty():  
						if file_name.ends_with(".tres"):
							var tool_path = "%s/%s/%s" % [ TOOLS_PATH, dir_name, file_name ]
							_load_tool(tool_path)
						file_name = dir.get_next()
				else:
					AIHubPlugin.print_err("Error reading tools directory %s. Error: %s" % [ dir_name, str(DirAccess.get_open_error())] )
			dir_name = tools_dir.get_next()
	else:
		AIHubPlugin.print_err("Error reading %s. Error: %s" % [ TOOLS_PATH, str(DirAccess.get_open_error())] )


func _load_tool(tool_path:String) -> void:
	var tool = load(tool_path)
	AIHubPlugin.print_msg("Reading tool at %s." % tool_path)
	if tool is AIToolResource:
		if tool.id.is_empty():
			AIHubPlugin.print_err("Missing ID for tool at %s." % tool_path)
			return
		if tool.title.is_empty():
			AIHubPlugin.print_err("Missing title for tool %s." % tool.id)
			return
		if tool.description.is_empty():
			AIHubPlugin.print_err("Missing description for tool %s." % tool.id)
			return
		if tool.category == null:
			AIHubPlugin.print_err("Missing category for tool %s." % tool.id)
			return
		var cat_group:Array[AIToolResource]
		if _tools_by_category.has(tool.category):
			cat_group = _tools_by_category[tool.category]
		else:
			cat_group = []
			_tools_by_category[tool.category] = cat_group
		cat_group.append(tool)
		_all_tools.append(tool)
	else:
		AIHubPlugin.print_err("File %s is not an AIToolResource." % tool_path)


func _load_current_access() -> void:
	if ResourceLoader.exists(LLMInterface.TOOL_CUSTOM_ACCESS_PATH):
		AIHubPlugin.print_msg("Custom access profile found: %s" % LLMInterface.TOOL_CUSTOM_ACCESS_PATH)
		_custom_base_profile = load(LLMInterface.TOOL_CUSTOM_ACCESS_PATH)
	var category_entry:TreeItem = tree.get_root().get_first_child()
	while category_entry:
		var tool_entry:TreeItem = category_entry.get_first_child()
		while tool_entry:
			_load_current_access_for_entry(tool_entry)
			tool_entry = tool_entry.get_next()
		category_entry = category_entry.get_next()


func _load_current_access_for_entry(tool_entry:TreeItem) -> void:
	# Deselecting all in case the tool is not in the base profile
	tool_entry.set_checked(Columns.Allow, false)
	tool_entry.set_checked(Columns.Ask, false)
	tool_entry.set_checked(Columns.Hide, false)
	
	var tool:= _get_tree_item_tool(tool_entry)
	if tool_entry.get_button_count(Columns.Reset) > 0:
		tool_entry.erase_button(Columns.Reset, 0)
	if _access_profile.has_tool(tool):
		tool_entry.add_button(Columns.Reset, RESET_ICON, 0)
		tool_entry.set_cell_mode(Columns.Reset, TreeItem.CELL_MODE_CUSTOM)
		tool_entry.set_tooltip_text(Columns.Reset, "Reset to defaut.")
		_fill_permission_checkboxes(tool_entry, tool, _access_profile)
	elif _custom_base_profile and _custom_base_profile.has_tool(tool) and _use_default_access:
		_fill_permission_checkboxes(tool_entry, tool, _custom_base_profile)
	elif LLMInterface.TOOL_DEFAULT_ACCESS_PROFILE.has_tool(tool) and _use_default_access:
		_fill_permission_checkboxes(tool_entry, tool, LLMInterface.TOOL_DEFAULT_ACCESS_PROFILE)
	elif not _use_default_access:
		AIHubPlugin.print_msg("WARNING: Tool \"%s\" not found in any access profile." % tool_entry.get_text(0))


func _fill_permission_checkboxes(tool_entry:TreeItem, tool:AIToolResource, profile:AIToolAccessProfile) -> void:
	var permission := profile.get_tool_permission(tool)
	tool_entry.set_checked(Columns.Allow, permission == AIToolAccess.Permission.Allow)
	tool_entry.set_checked(Columns.Ask, permission == AIToolAccess.Permission.Ask)
	tool_entry.set_checked(Columns.Hide, permission == AIToolAccess.Permission.Hide)


func _on_advanced_checkbox_toggled(toggled_on: bool) -> void:
	advanced_setup_container.visible = toggled_on


func _on_reset_btn_pressed() -> void:
	reset_all_confirmation_dialog.show()


func _on_save_default_btn_pressed() -> void:
	save_default_confirmation_dialog.show()


func _on_reset_all_confirmation_dialog_confirmed() -> void:
	if _access_profile != LLMInterface.TOOL_DEFAULT_ACCESS_PROFILE:
		_access_profile.reset()
	_load_current_access()


func _on_save_default_confirmation_dialog_confirmed() -> void:
	var new_base_profile:= AIToolAccessProfile.create_from_profiles_in_order([
		LLMInterface.TOOL_DEFAULT_ACCESS_PROFILE,
		_custom_base_profile,
		_access_profile
	])
	new_base_profile.take_over_path(LLMInterface.TOOL_CUSTOM_ACCESS_PATH)
	var error := ResourceSaver.save(new_base_profile, LLMInterface.TOOL_CUSTOM_ACCESS_PATH)
	if error != OK:
		AIHubPlugin.print_err("Error while creating the tool access profile. Error code: %d" % error)
	else:
		AIHubPlugin.print_msg("Custom access profile saved.")
		_access_profile.reset()
		_load_current_access()


func _on_tree_item_edited() -> void:
	var entry:TreeItem = tree.get_edited()
	var column := tree.get_edited_column()
	
	if entry.is_checked(column):
		entry.set_checked(Columns.Allow, column == Columns.Allow)
		entry.set_checked(Columns.Ask, column == Columns.Ask)
		entry.set_checked(Columns.Hide, column == Columns.Hide)
	else:
		if column == Columns.Hide:
			entry.set_checked(Columns.Ask, true)
		else:
			entry.set_checked(Columns.Hide, true)
	
	var permission := _get_permission_from_checkboxes(entry)
	
	_access_profile.set_tool_permission(_get_tree_item_tool(entry), permission)
	_load_current_access_for_entry(entry)


func _get_permission_from_checkboxes(tree_entry:TreeItem) -> AIToolAccess.Permission:
	var permission:AIToolAccess.Permission
	if tree_entry.is_checked(Columns.Hide): permission = AIToolAccess.Permission.Hide
	if tree_entry.is_checked(Columns.Ask): permission = AIToolAccess.Permission.Ask
	if tree_entry.is_checked(Columns.Allow): permission = AIToolAccess.Permission.Allow
	return permission


func _on_tree_button_clicked(entry: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	var tool:= _get_tree_item_tool(entry)
	if column == Columns.Options:
		var profile:AIToolAccessProfile
		if _access_profile.has_tool(tool):
			profile = _access_profile
		elif _custom_base_profile and _custom_base_profile.has_tool(tool):
			profile = _custom_base_profile
		elif LLMInterface.TOOL_DEFAULT_ACCESS_PROFILE.has_tool(tool):
			profile = LLMInterface.TOOL_DEFAULT_ACCESS_PROFILE
		else:
			AIHubPlugin.print_msg("WARNING: Tool \"%s\" not found in any access profile." % tool.title)
		
		var options_window:AIToolOptionsWindow = AI_TOOL_OPTIONS_WINDOW.instantiate()
		options_window.initialize(tool, profile.get_tool_option_values(tool) if profile else {})
		options_window.saved.connect(_on_options_window_saved.bind(entry))
		add_child(options_window)
		options_window.popup()
	elif column == Columns.Reset:
		_access_profile.remove_tool(tool)
		_load_current_access_for_entry(entry)


func _on_options_window_saved(tool:AIToolResource, option_values:Dictionary, tool_entry: TreeItem) -> void:
	if not _access_profile.has_tool(tool):
		var permission := _get_permission_from_checkboxes(tool_entry)
		_access_profile.set_tool_permission(tool, permission)
	_access_profile.set_tool_option_values(tool, option_values)
	_load_current_access_for_entry(tool_entry)


func _on_options_window_saved_global(option_values:Dictionary) -> void:
	_access_profile.set_global_option_values(option_values)


func _get_tree_item_tool(entry:TreeItem) -> AIToolResource:
	var tool:AIToolResource = entry.get_meta("resource")
	if not tool:
		AIHubPlugin.print_err("Tool entry \"%s\" is not associated with an AIToolResource." % entry.get_text(0))
	return tool


func _on_global_options_btn_pressed() -> void:
	var all_options:Array[AIToolOption] = []
	for tool in _all_tools:
		for o in tool.options:
			if not all_options.has(o):
				all_options.append(o)
	
	var current_global_option_values:Dictionary
	if _access_profile.get_global_option_values().size() > 0:
		current_global_option_values = _access_profile.get_global_option_values()
	elif _custom_base_profile and _custom_base_profile.get_global_option_values().size() > 0:
		current_global_option_values = _custom_base_profile.get_global_option_values()
	elif LLMInterface.TOOL_DEFAULT_ACCESS_PROFILE.get_global_option_values().size() > 0:
		current_global_option_values = LLMInterface.TOOL_DEFAULT_ACCESS_PROFILE.get_global_option_values()
	else:
		current_global_option_values = {}
	
	var options_window:AIToolOptionsWindow = AI_TOOL_OPTIONS_WINDOW.instantiate()
	options_window.initialize_global(all_options, current_global_option_values)
	options_window.saved_global.connect(_on_options_window_saved_global)
	add_child(options_window)
	options_window.popup()
