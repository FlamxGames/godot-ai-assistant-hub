@tool
class_name AIHubPlugin
extends EditorPlugin

enum ThinkingTargets { Output, Chat, Discard }
const PREF_REMOVE_THINK:= "plugins/ai_assistant_hub/preferences/thinking_target"
const PREF_SCROLL_BOTTOM:= "plugins/ai_assistant_hub/preferences/always_scroll_to_bottom"

const CONFIG_LLM_API:= "plugins/ai_assistant_hub/llm_api"

# Configuration deprecated in version 1.6.0
const DEPRECATED_CONFIG_OPENROUTER_API_KEY := "plugins/ai_assistant_hub/openrouter_api_key"
const DEPRECATED_CONFIG_GEMINI_API_KEY := "plugins/ai_assistant_hub/gemini_api_key"
const DEPRECATED_CONFIG_OPENWEBUI_API_KEY := "plugins/ai_assistant_hub/openwebui_api_key"

var _hub_dock:AIAssistantHub

func _enter_tree() -> void:
	initialize_project_settings()
	_hub_dock = load("res://addons/ai_assistant_hub/ai_assistant_hub.tscn").instantiate()
	_hub_dock.initialize(self)
	add_control_to_bottom_panel(_hub_dock, "AI Hub")
	#add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, _hub_dock)


func initialize_project_settings() -> void:
	# Version 1.6.0 cleanup - Migrate base URL from global setting to per LLM setting
	var api_id :String = ProjectSettings.get_setting(AIHubPlugin.CONFIG_LLM_API, "")
	if not api_id.is_empty():
		var config_base_url = LLMConfigManager.new(api_id)
		config_base_url.migrate_deprecated_1_5_0_base_url()
	
	# Version 1.6.0 cleanup - delete API key files and project settings
	var config_gemini = LLMConfigManager.new("gemini_api")
	var dummy := LLMProviderResource.new()
	dummy.api_id = "dummy"
	config_gemini.migrate_deprecated_1_5_0_api_key(
		(GeminiAPI.new(dummy)).get_deprecated_api_key(),
		GeminiAPI.DEPRECATED_API_KEY_SETTING,
		GeminiAPI.DEPRECATED_API_KEY_FILE)
	var config_openrouter = LLMConfigManager.new("openrouter_api")
	config_openrouter.migrate_deprecated_1_5_0_api_key(
		OpenRouterAPI.new(dummy).get_deprecated_api_key(),
		OpenRouterAPI.DEPRECATED_API_KEY_SETTING,
		OpenRouterAPI.DEPRECATED_API_KEY_FILE)
	var config_openwebui = LLMConfigManager.new("openwebui_api")
	config_openwebui.migrate_deprecated_1_5_0_api_key(
		OpenWebUIAPI.new(dummy).get_deprecated_api_key(),
		OpenWebUIAPI.DEPRECATED_API_KEY_SETTING)
	
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
func new_llm(llm_provider:LLMProviderResource) -> LLMInterface:
	if llm_provider == null:
		push_error("No LLM provider has been selected.")
		return null
	if llm_provider.api_id.is_empty():
		push_error("Provider %s has no API ID." % llm_provider.api_id)
		return null
	var script_path = "res://addons/ai_assistant_hub/llm_apis/%s.gd" % llm_provider.api_id
	var script = load(script_path)
	if script == null:
		push_error("Failed to load LLM provider script: %s" % script_path)
		return null
	var instance:LLMInterface = script.new(llm_provider)
	if instance == null:
		push_error("Failed to instantiate the LLM provider from script: %s" % script_path)
		return null # Add this line to ensure a value is always returned
	return instance


func get_current_llm_provider() -> LLMProviderResource:
	return _hub_dock.get_selected_llm_resource()
