@tool
class_name AIHubPlugin
extends EditorPlugin

enum ThinkingTargets { Output, Chat, Discard }
const PREF_REMOVE_THINK:= "plugins/ai_assistant_hub/preferences/thinking_target"
const PREF_SCROLL_BOTTOM:= "plugins/ai_assistant_hub/preferences/always_scroll_to_bottom"

const CONFIG_BASE_URL:= "plugins/ai_assistant_hub/base_url"
const CONFIG_LLM_API:= "plugins/ai_assistant_hub/llm_api"
const CONFIG_OPENROUTER_API_KEY := "plugins/ai_assistant_hub/openrouter_api_key"
const CONFIG_GEMINI_API_KEY := "plugins/ai_assistant_hub/gemini_api_key"
const CONFIG_OPENWEBUI_API_KEY := "plugins/ai_assistant_hub/openwebui_api_key"

var _hub_dock:AIAssistantHub

func _enter_tree() -> void:
	initialize_project_settings()
	
	# Setup OpenRouter API key (will be loaded from file if it exists)
	_init_openrouter_api_key()

	# Setup Gemini API key (will be loaded from file if it exists)
	_init_gemini_api_key()

	# Setup OpenWeb UI API Key (will be loaded from settings only)
	_init_openwebui_api_key()

	_hub_dock = load("res://addons/ai_assistant_hub/ai_assistant_hub.tscn").instantiate()
	_hub_dock.initialize(self)
	add_control_to_bottom_panel(_hub_dock, "AI Hub")
	#add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, _hub_dock)


func initialize_project_settings() -> void:
	if ProjectSettings.get_setting(CONFIG_BASE_URL, "").is_empty():
		# In the future we can consider moving this back to simply:
		# ProjectSettings.set_setting(CONFIG_BASE_URL, "http://127.0.0.1:11434")
		# the code below handles migrating the config from 1.2.0 to 1.3.0
		var old_path:= "ai_assistant_hub/base_url"
		if ProjectSettings.has_setting(old_path):
			ProjectSettings.set_setting(CONFIG_BASE_URL, ProjectSettings.get_setting(old_path))
			ProjectSettings.set_setting(old_path, null)
			ProjectSettings.save()
		else:
			ProjectSettings.set_setting(CONFIG_BASE_URL, "http://127.0.0.1:11434")
			
	if ProjectSettings.get_setting(CONFIG_LLM_API, "").is_empty():
		# In the future we can consider moving this back to simply:
		# ProjectSettings.set_setting(CONFIG_LLM_API, "ollama_api")
		# the code below handles migrating the config from 1.2.0 to 1.3.0
		var old_path:= "ai_assistant_hub/llm_api"
		if ProjectSettings.has_setting(old_path):
			ProjectSettings.set_setting(CONFIG_LLM_API, ProjectSettings.get_setting(old_path))
			ProjectSettings.set_setting(old_path, null)
			ProjectSettings.save()
		else:
			ProjectSettings.set_setting(CONFIG_LLM_API, "ollama_api")
	
	if not ProjectSettings.has_setting(PREF_REMOVE_THINK):
		ProjectSettings.set_setting(PREF_REMOVE_THINK, ThinkingTargets.Output)
		ProjectSettings.save()
	
	var property_info = {
		"name": PREF_REMOVE_THINK,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Output,Chat,Discard"
	}
	ProjectSettings.add_property_info(property_info)
	
	if not ProjectSettings.has_setting(PREF_SCROLL_BOTTOM):
		ProjectSettings.set_setting(PREF_SCROLL_BOTTOM, false)
		ProjectSettings.save()


# Initialize OpenRouter API key settings
func _init_openrouter_api_key() -> void:
	# First check if we have a key from the file
	var openrouter_api = load("res://addons/ai_assistant_hub/llm_apis/openrouter_api.gd").new()
	var api_key = openrouter_api._load_api_key_from_file()
	
	if api_key.is_empty():
		# If no key in file, check ProjectSettings
		if ProjectSettings.has_setting(CONFIG_OPENROUTER_API_KEY):
			api_key = ProjectSettings.get_setting(CONFIG_OPENROUTER_API_KEY)
			
			# If we have a key in ProjectSettings, save it to file
			if not api_key.is_empty():
				openrouter_api._save_api_key_to_file(api_key)
	else:
		# If we found a key in file, update ProjectSettings
		ProjectSettings.set_setting(CONFIG_OPENROUTER_API_KEY, api_key)
	
	# Add setting if it doesn't exist
	_add_project_setting(CONFIG_OPENROUTER_API_KEY, api_key, TYPE_STRING, PROPERTY_HINT_NONE, 
		"OpenRouter API key - Get it from https://openrouter.ai/keys")

		# Initialize Gemini API key settings
func _init_gemini_api_key() -> void:
	# First check if we have a key from the file
	var gemini_api = load("res://addons/ai_assistant_hub/llm_apis/gemini_api.gd").new()
	var api_key = gemini_api._load_api_key_from_file()
	
	if api_key.is_empty():
		# If no key in file, check ProjectSettings
		if ProjectSettings.has_setting(CONFIG_GEMINI_API_KEY):
			api_key = ProjectSettings.get_setting(CONFIG_GEMINI_API_KEY)

			# If we have a key in ProjectSettings, save it to file
			if not api_key.is_empty():
				gemini_api._save_api_key_to_file(api_key)
	else:
		# If we found a key in file, update ProjectSettings
		ProjectSettings.set_setting(CONFIG_GEMINI_API_KEY, api_key)
	
		# Add setting if it doesn't exist
	_add_project_setting(CONFIG_GEMINI_API_KEY, api_key, TYPE_STRING, PROPERTY_HINT_NONE, "Gemini API key - Get it from https://aistudio.google.com/app/apikey")

func _init_openwebui_api_key() -> void:
	var api_key : String = ""
	if ProjectSettings.has_setting(CONFIG_OPENWEBUI_API_KEY):
		api_key = ProjectSettings.get_setting(CONFIG_OPENWEBUI_API_KEY)
	_add_project_setting(CONFIG_OPENWEBUI_API_KEY, api_key, TYPE_STRING, PROPERTY_HINT_NONE, "OpenWebUI Key - Get it from Settings>Account>API Keys>JWT Token in your OpenWebUI Session")

func _exit_tree() -> void:
	remove_control_from_bottom_panel(_hub_dock)
	#remove_control_from_docks(_hub_dock)
	_hub_dock.queue_free()


## Helper function: Add project setting
func _add_project_setting(name: String, default_value, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	if ProjectSettings.has_setting(name):
		return
	
	var property_info := {
		"name": name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string
	}
	
	ProjectSettings.set_setting(name, default_value)
	ProjectSettings.add_property_info(property_info)
	ProjectSettings.set_initial_value(name, default_value)


## Load the API dinamically based on the script name given in project setting: ai_assistant_hub/llm_api
## By default this is equivalent to: return OllamaAPI.new()
func new_llm_provider(api_class: String = ProjectSettings.get_setting(AIHubPlugin.CONFIG_LLM_API)) -> LLMInterface:
	var script_path = "res://addons/ai_assistant_hub/llm_apis/%s.gd" % api_class
	var script = load(script_path)
	if script == null:
		push_error("Failed to load LLM provider script: %s" % script_path)
		return null
	var instance = script.new()
	if instance == null:
		push_error("Failed to instantiate the LLM provider from script: %s" % script_path)
		return null # Add this line to ensure a value is always returned
	return instance


## Get available LLM providers list
func get_available_llm_providers() -> Array[Dictionary]:
	var providers: Array[Dictionary] = []
	
	# Add Ollama provider
	providers.append({
		"id": "ollama_api",
		"name": "Ollama",
		"description": "Locally run open source LLM (requires Ollama software)"
	})
	
	# Add OpenRouter provider
	providers.append({
		"id": "openrouter_api",
		"name": "OpenRouter",
		"description": "Unified interface to access various commercial LLMs (requires API key)"
	})

	# Add Jan.IA provider
	providers.append({
		"id":"jan_api",
		"name":"Jan",
		"description":"Locally run open source LLMs models (requires Jan’s OpenAI‑compatible server)"
	})

	# Add Gemini provider
	providers.append({
		"id": "gemini_api",
		"name": "Gemini",
		"description": "Google Gemini LLM (requires API key)"
	})

	# OpenWeb UI provider
	providers.append({
		"id": "openwebui_api",
		"name": "OpenWebUI",
		"description": "OpenWebUI for locally hosted LLM (requires API key)"
	})
		
	return providers
