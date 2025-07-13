@tool
class_name AIAssistantHub
extends Control

signal models_refreshed(models:Array[String])
signal new_api_loaded(api_class:String)

const NEW_AI_ASSISTANT_BUTTON = preload("res://addons/ai_assistant_hub/new_ai_assistant_button.tscn")
const NEW_AI_ASSISTANT_TYPE_WINDOW = preload("res://addons/ai_assistant_hub/new_ai_assistant_type_window.tscn")

@onready var models_http_request: HTTPRequest = %ModelsHTTPRequest
@onready var url_txt: LineEdit = %UrlTxt
@onready var api_class_txt: LineEdit = %ApiClassTxt
@onready var models_list: ItemList = %ModelsList
@onready var models_list_error: Label = %ModelsListError
@onready var no_assistants_guide: Label = %NoAssistantsGuide
@onready var assistant_types_container: HFlowContainer = %AssistantTypesContainer
@onready var tab_container: TabContainer = %TabContainer
@onready var new_assistant_type_button: Button = %NewAssistantTypeButton
@onready var llm_provider_option: OptionButton = %LLMProviderOption
@onready var url_label: Label = %UrlLabel
@onready var openrouter_key_container: HBoxContainer = %OpenRouterKeyContainer
@onready var openrouter_api_key: LineEdit = %OpenRouterAPIKey

var _plugin:EditorPlugin
var _tab_bar:TabBar
var _model_names:Array[String] = []
var _models_llm: LLMInterface
var _current_provider_id: String = ""


func _tab_changed(tab_index: int) -> void:
	if tab_index > 0:
		_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_ACTIVE_ONLY
	else:
		_tab_bar.tab_close_display_policy = TabBar.CLOSE_BUTTON_SHOW_NEVER


func _close_tab(tab_index: int) -> void:
	var chat = tab_container.get_tab_control(tab_index)
	models_refreshed.disconnect(chat.refresh_models)
	chat.queue_free()


func initialize(plugin:EditorPlugin) -> void:
	_plugin = plugin
	_models_llm = _plugin.new_llm_provider()
	
	await ready
	url_txt.text = ProjectSettings.get_setting(AIHubPlugin.CONFIG_BASE_URL)
	api_class_txt.text = ProjectSettings.get_setting(AIHubPlugin.CONFIG_LLM_API)
	_current_provider_id = api_class_txt.text
	
	# Load OpenRouter API key
	if _current_provider_id == "openrouter_api":
		_load_openrouter_api_key()
	elif ProjectSettings.has_setting(AIHubPlugin.CONFIG_OPENROUTER_API_KEY):
		openrouter_api_key.text = ProjectSettings.get_setting(AIHubPlugin.CONFIG_OPENROUTER_API_KEY)
	
	# Initialize LLM provider dropdown
	_initialize_llm_provider_options()
	
	_on_assistants_refresh_btn_pressed()
	_on_refresh_models_btn_pressed()
	
	_tab_bar = tab_container.get_tab_bar()
	_tab_bar.tab_changed.connect(_tab_changed)
	_tab_bar.tab_close_pressed.connect(_close_tab)


# Initialize LLM provider options
func _initialize_llm_provider_options() -> void:
	llm_provider_option.clear()
	var providers = _plugin.get_available_llm_providers()
	
	for i in range(providers.size()):
		var provider = providers[i]
		llm_provider_option.add_item(provider.name)
		llm_provider_option.set_item_metadata(i, provider.id)
		
		# Select currently used provider
		if provider.id == _current_provider_id:
			llm_provider_option.select(i)
	
	# Update UI state
	_update_provider_ui()


# Update UI based on current provider selection
func _update_provider_ui() -> void:
	var provider_id = _current_provider_id
	
	# Ollama needs URL, OpenRouter needs API key
	if provider_id == "ollama_api":
		url_label.text = "Server URL"
		url_txt.placeholder_text = "Example: http://127.0.0.1:11434"
		url_txt.tooltip_text = "URL of the host running the LLM.\n\nDefault value uses Ollama's default port."
		url_txt.visible = true
		openrouter_key_container.visible = false
	elif provider_id == "openrouter_api":
		url_label.text = "OpenRouter Settings"
		url_txt.visible = false
		openrouter_key_container.visible = true
	else:
		url_label.text = "Server URL"
		url_txt.visible = true
		openrouter_key_container.visible = false


func _on_settings_changed(_x) -> void:
	ProjectSettings.set_setting(AIHubPlugin.CONFIG_BASE_URL, url_txt.text)
	ProjectSettings.set_setting(AIHubPlugin.CONFIG_LLM_API, api_class_txt.text)
	
	# Save OpenRouter API key
	if _current_provider_id == "openrouter_api":
		ProjectSettings.set_setting(AIHubPlugin.CONFIG_OPENROUTER_API_KEY, openrouter_api_key.text)
	ProjectSettings.save()


func _on_refresh_models_btn_pressed() -> void:
	models_list.deselect_all()
	models_list.visible = false
	models_list_error.visible = false
	_models_llm.send_get_models_request(models_http_request)


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
				models_refreshed.emit(_model_names) #for existing chats
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
		no_assistants_guide.text = "Create an assistant type by selecting a model and clicking \"New assistant type\". Or manually create a new resource AIAssistantResource in the assistant types folder, then click the reload button.\nThe assistant types folder is at: %s" % assistants_path
		no_assistants_guide.visible = true
		assistant_types_container.visible = false
	else:
		no_assistants_guide.visible = false
		assistant_types_container.visible = true


func _on_button_gui_input(event, delete_menu: PopupMenu):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		delete_menu.position = mouse_pos
		delete_menu.show()


func _on_assistant_button_menu_select(id: int, assistant_file: String) -> void:
	match id:
		0:  #  Edit
			var res = ResourceLoader.load(assistant_file)
			EditorInterface.edit_resource(res)
		1:  # Delete
			DirAccess.remove_absolute(assistant_file)
			_on_assistants_refresh_btn_pressed()


func _on_new_bot_btn_chat_created(chat:AIChat, assistant_type:AIAssistantResource) -> void:
	tab_container.add_child(chat)
	tab_container.set_tab_icon(tab_container.get_child_count() - 1, assistant_type.type_icon)
	tab_container.current_tab = chat.get_index()
	chat.refresh_models(_model_names)
	models_refreshed.connect(chat.refresh_models)
	new_api_loaded.connect(chat.load_api)
	chat.greet()


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


func _on_api_load_btn_pressed() -> void:
	var new_llm:LLMInterface = _plugin.new_llm_provider()
	if new_llm == null:
		push_error("Invalid API class")
		return
	_models_llm = new_llm
	new_api_loaded.emit(api_class_txt.text)


# Called when LLM provider option changes
func _on_llm_provider_option_item_selected(index: int) -> void:
	var provider_id = llm_provider_option.get_item_metadata(index)
	if _current_provider_id != provider_id:
		_current_provider_id = provider_id
		api_class_txt.text = provider_id
		ProjectSettings.set_setting(AIHubPlugin.CONFIG_LLM_API, provider_id)
		
		# Load API key for OpenRouter if we're switching to it
		if provider_id == "openrouter_api":
			_load_openrouter_api_key()
			
		_update_provider_ui()
		_on_api_load_btn_pressed()


# Load OpenRouter API key from the API class
func _load_openrouter_api_key() -> void:
	var openrouter_api = load("res://addons/ai_assistant_hub/llm_apis/openrouter_api.gd").new()
	var api_key = openrouter_api._get_api_key()
	if not api_key.is_empty():
		openrouter_api_key.text = api_key


# Called when OpenRouter API key changes
func _on_openrouter_api_key_text_changed(new_text: String) -> void:
	# Save to ProjectSettings for backward compatibility
	ProjectSettings.set_setting(AIHubPlugin.CONFIG_OPENROUTER_API_KEY, new_text)
	
	# Save to file using the OpenRouter API class
	if _current_provider_id == "openrouter_api":
		var openrouter_api = load("res://addons/ai_assistant_hub/llm_apis/openrouter_api.gd").new()
		openrouter_api.save_api_key(new_text)
	ProjectSettings.save()


func _on_new_assistant_type_button_pressed() -> void:
	if models_list.is_anything_selected():
		var new_assistant_type_window:NewAIAssistantTypeWindow = NEW_AI_ASSISTANT_TYPE_WINDOW.instantiate()
		var api_class :String = api_class_txt.text
		var model_name :String = models_list.get_item_text(models_list.get_selected_items()[0])
		var assistants_path = "%s/assistants" % self.scene_file_path.get_base_dir()
		new_assistant_type_window.initialize(api_class, model_name, assistants_path)
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
