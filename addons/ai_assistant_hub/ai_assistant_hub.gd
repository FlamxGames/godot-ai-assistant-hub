@tool
class_name AIAssistantHub
extends Control

const NEW_AI_ASSISTANT_BUTTON = preload("res://addons/ai_assistant_hub/new_ai_assistant_button.tscn")
const NEW_AI_ASSISTANT_TYPE_WINDOW = preload("res://addons/ai_assistant_hub/new_ai_assistant_type_window.tscn")
const AI_CHAT = preload("res://addons/ai_assistant_hub/ai_chat.tscn")

@onready var models_http_request: HTTPRequest = %ModelsHTTPRequest
@onready var url_txt: LineEdit = %UrlTxt
@onready var models_list: ItemList = %ModelsList
@onready var models_list_error: Label = %ModelsListError
@onready var no_assistants_guide: Label = %NoAssistantsGuide
@onready var assistant_types_container: HFlowContainer = %AssistantTypesContainer
@onready var tab_container: TabContainer = %TabContainer
@onready var new_assistant_type_button: Button = %NewAssistantTypeButton
@onready var llm_provider_option: OptionButton = %LLMProviderOption
@onready var url_label: Label = %UrlLabel
@onready var api_key_txt: LineEdit = %APIKeyTxt
@onready var get_key_link: LinkButton = %GetKeyLink
@onready var version_http_request: HTTPRequest = %VersionHTTPRequest
@onready var version_label: Label = %VersionLabel
@onready var upgrade_btn: Button = %UpgradeBtn


var _plugin:AIHubPlugin
var _tab_bar:TabBar
var _model_names:Array[String] = []
var _models_llm: LLMInterface
var _current_api_id:String


func _tab_changed(tab_index: int) -> void:
	var chat = tab_container.get_current_tab_control()
	if chat is AIChat:
		if chat.save_check_button.button_pressed:
			_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
		else:
			_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
	else:
		_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER


func _on_chat_save_changed(chat:AIChat, save_on:bool) -> void:
	if tab_container.get_current_tab_control() == chat:
		if save_on:
			_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER
		else:
			_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY


func _close_tab(tab_index: int) -> void:
	var chat = tab_container.get_tab_control(tab_index)
	chat.queue_free()


func initialize(plugin:AIHubPlugin) -> void:
	_plugin = plugin
	await ready
	_current_api_id = ProjectSettings.get_setting(AIHubPlugin.CONFIG_LLM_API)
	
	_initialize_llm_provider_options() # Load LLM providers
	_on_assistants_refresh_btn_pressed() # Load assistant buttons
	
	_tab_bar = tab_container.get_tab_bar()
	_tab_bar.tab_changed.connect(_tab_changed)
	_tab_bar.tab_close_pressed.connect(_close_tab)
	
	_load_saved_chats()
	_check_version()


# Initialize LLM provider options
func _initialize_llm_provider_options() -> void:
	llm_provider_option.clear()

	var files := _get_all_resources("%s/llm_providers" % self.scene_file_path.get_base_dir())
	var i := 0
	for provider_file in files:
		var provider = load(provider_file)
		if provider is LLMProviderResource:
			llm_provider_option.add_item(provider.name)
			llm_provider_option.set_item_tooltip(i, provider.description)
			llm_provider_option.set_item_metadata(i, provider)
			# Select currently used provider
			if provider.api_id == _current_api_id:
				llm_provider_option.select(i)
				_on_llm_provider_option_item_selected(i)
			i += 1


# Update UI based on current provider selection
func _update_provider_ui() -> void:
	var llm_provider:LLMProviderResource = llm_provider_option.get_selected_metadata()
	if llm_provider == null:
		push_error("No LLM provider is selected.")
		return
	
	var config = LLMConfigManager.new(llm_provider.api_id)
	if llm_provider.fix_url.is_empty():
		url_txt.editable = true
		url_txt.text = config.load_url()
	else:
		url_txt.editable = false
		url_txt.text = llm_provider.fix_url
	api_key_txt.visible = llm_provider.requires_key
	api_key_txt.text = config.load_key()
	get_key_link.visible = not llm_provider.get_key_url.is_empty()
	get_key_link.uri = llm_provider.get_key_url
	
	if url_txt.visible and api_key_txt.visible:
		url_label.text = "Server URL / API key"
	else:
		url_label.text = "Server URL"
	
	_on_refresh_models_btn_pressed() # Load models


func _on_settings_changed(_x) -> void:
	var llm_provider:LLMProviderResource = llm_provider_option.get_selected_metadata()
	if llm_provider == null:
		push_error("No LLM provider is selected. Settings not saved.")
		return
	var config = LLMConfigManager.new(llm_provider.api_id)
	if not api_key_txt.text.is_empty():
		config.save_key(api_key_txt.text)
	if llm_provider.fix_url.is_empty() and not url_txt.text.is_empty():
		config.save_url(url_txt.text)
	_models_llm.load_llm_parameters()


func _on_refresh_models_btn_pressed() -> void:
	var llm_provider:LLMProviderResource = llm_provider_option.get_selected_metadata()
	if not url_txt.text.is_empty():
		models_list.deselect_all()
		models_list.visible = false
		models_list_error.visible = false
		_models_llm.send_get_models_request(models_http_request)
	else:
		models_list_error.text = "Configure the Server URL below to get the list of available models."
		models_list_error.visible = true
		models_list.visible = false


func _on_models_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	models_list_error.visible = false
	models_list.visible = false
	if result == 0:
		var models_returned: Array = _models_llm.read_models_response(body)
		if models_returned.size() == 0:
			models_list_error.text = "No models found. Download at least one model and try again."
			models_list_error.visible = true
		else:
			if models_returned[0] == LLMInterface.INVALID_RESPONSE:
				models_list_error.text = "Error while trying to get the models list. Response: %s" % _models_llm.get_full_response(body)
				models_list_error.visible = true
			else:
				models_list.clear()
				models_list.visible = true
				_model_names = models_returned
				for model in _model_names:
					models_list.add_item(model)
	else:
		push_error("HTTP response: Result: %s, Response Code: %d, Headers: %s, Body: %s" % [result, response_code, headers, body])
		models_list_error.text = "Something went wrong querying for models, is the Server URL correct?"
		models_list_error.visible = true


func _on_assistants_refresh_btn_pressed() -> void:
	var assistants_path = "%s/assistants" % self.scene_file_path.get_base_dir()
	var files = _get_all_resources(assistants_path)
	var found:= false
	
	for child in assistant_types_container.get_children():
		if child != no_assistants_guide:
			assistant_types_container.remove_child(child)
	
	for assistant_file in files:
		var assistant = load(assistant_file)
		if assistant is AIAssistantResource:
			found = true
			var new_bot_btn:NewAIAssistantButton= NEW_AI_ASSISTANT_BUTTON.instantiate()
			new_bot_btn.initialize(_plugin, assistant)
			new_bot_btn.chat_created.connect(_on_new_bot_btn_chat_created)
			assistant_types_container.add_child(new_bot_btn)
			var bot_menu: PopupMenu = PopupMenu.new()
			bot_menu.add_item("Edit", 0)
			bot_menu.add_item("Delete", 1)
			new_bot_btn.add_child(bot_menu)
			var menu_callable = Callable(self, "_on_assistant_button_menu_select").bind(assistant_file)
			bot_menu.id_pressed.connect(menu_callable)
			var button_callable = Callable(self, "_on_button_gui_input").bind(bot_menu)
			new_bot_btn.gui_input.connect(button_callable)
	
	if not found:
		no_assistants_guide.text = "Create an assistant type by selecting a model and clicking \"New assistant type\"."
		no_assistants_guide.visible = true
		assistant_types_container.visible = false
	else:
		no_assistants_guide.visible = false
		assistant_types_container.visible = true


func _on_button_gui_input(event, delete_menu: PopupMenu):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		delete_menu.position = DisplayServer.mouse_get_position()
		delete_menu.show()


func _on_assistant_button_menu_select(id: int, assistant_file: String) -> void:
	match id:
		0:  #  Edit
			var res = ResourceLoader.load(assistant_file)
			EditorInterface.edit_resource(res)
		1:  # Delete
			DirAccess.remove_absolute(assistant_file)
			_on_assistants_refresh_btn_pressed()
			EditorInterface.get_resource_filesystem().scan()


func _on_new_bot_btn_chat_created(chat:AIChat) -> void:
	tab_container.add_child(chat)
	tab_container.set_tab_icon(tab_container.get_child_count() - 1, chat.get_assistant_settings().type_icon)
	tab_container.current_tab = chat.get_index()
	chat.save_changed.connect(_on_chat_save_changed)


func _get_all_resources(path: String) -> Array[String]:  
	var file_paths: Array[String] = []  
	var dir = DirAccess.open(path)  
	dir.list_dir_begin()  
	var file_name = dir.get_next()  
	while not file_name.is_empty():  
		if file_name.ends_with(".tres"):
			var file_path = path + "/" + file_name
			file_paths.append(file_path)  
		file_name = dir.get_next()
	return file_paths


# Called when LLM provider option changes
func _on_llm_provider_option_item_selected(index: int) -> void:
	var llm_provider:LLMProviderResource = llm_provider_option.get_item_metadata(index)
	_current_api_id = llm_provider.api_id
	var new_llm:LLMInterface = _plugin.new_llm(llm_provider)
	if new_llm == null:
		push_error("Invalid LLM API")
	else:
		_models_llm = new_llm
	ProjectSettings.set_setting(AIHubPlugin.CONFIG_LLM_API, llm_provider.api_id)
	ProjectSettings.save()
	_update_provider_ui()


func get_selected_llm_resource() -> LLMProviderResource:
	return llm_provider_option.get_selected_metadata()


func _on_new_assistant_type_button_pressed() -> void:
	if models_list.is_anything_selected():
		var new_assistant_type_window:NewAIAssistantTypeWindow = NEW_AI_ASSISTANT_TYPE_WINDOW.instantiate()
		var api_class :String = _current_api_id
		var model_name :String = models_list.get_item_text(models_list.get_selected_items()[0])
		var assistants_path = "%s/assistants" % self.scene_file_path.get_base_dir()
		var llm_provider:LLMProviderResource = llm_provider_option.get_selected_metadata()
		new_assistant_type_window.initialize(llm_provider, model_name, assistants_path)
		new_assistant_type_window.assistant_type_created.connect(_on_assistants_refresh_btn_pressed)
		add_child(new_assistant_type_window)
		new_assistant_type_window.popup()
	else:
		new_assistant_type_button.disabled = true


func _on_models_list_item_selected(index: int) -> void:
	new_assistant_type_button.disabled = false


func _on_models_list_empty_clicked(at_position: Vector2, mouse_button_index: int) -> void:
	models_list.deselect_all()
	new_assistant_type_button.disabled = true


func _load_saved_chats() -> void:
	var dir = DirAccess.open(AIChat.SAVE_PATH)  
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()  
		while not file_name.is_empty():  
			if file_name.ends_with(".cfg"):
				var file_path = "%s/%s" % [ AIChat.SAVE_PATH , file_name ]
				_load_chat(file_path)
			file_name = dir.get_next()
	tab_container.current_tab = 0


func _load_chat(file_path:String) -> void:
	var chat = AI_CHAT.instantiate()
	chat.initialize_from_file(_plugin, file_path)
	_on_new_bot_btn_chat_created(chat)


func _check_version() -> void:
	var err := version_http_request.request("https://api.github.com/repos/FlamxGames/godot-ai-assistant-hub/releases/latest", ["Accept: application/vnd.github+json", "X-GitHub-Api-Version: 2022-11-28"], HTTPClient.METHOD_GET)
	if err != OK:
		print("There was an error trying to check the latest version for Godot AI Assistant Hub.")


func _on_version_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	var error:= true
	upgrade_btn.visible = false
	if result == 0:
		var j := JSON.new()
		j.parse(body.get_string_from_utf8())
		var data := j.get_data()
		if data.has("name"):
			var latest_version = data.name
			if version_label.text != latest_version:
				upgrade_btn.visible = true
				upgrade_btn.tooltip_text = "Version available %s. Click here to know more." % latest_version
			error = false
	if error:
		print("It was not possible to check the latest version for Godot AI Assistant Hub, you may want to check GitHub manually: https://github.com/FlamxGames/godot-ai-assistant-hub. The response was: %s " % body)


func _on_support_btn_pressed() -> void:
	OS.shell_open("https://github.com/FlamxGames/godot-ai-assistant-hub/blob/main/support.md")


func _on_upgrade_btn_pressed() -> void:
	OS.shell_open("https://github.com/FlamxGames/godot-ai-assistant-hub/blob/main/README.md#whats-new-in-the-latest-version")
