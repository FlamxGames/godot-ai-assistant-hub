@tool
class_name AIHubPlugin
extends EditorPlugin

enum ThinkingTargets { Output, Chat, Discard }
enum DebugOption { Disabled, Console, ConsoleAndLog }
const PREF_REMOVE_THINK:= "plugins/ai_assistant_hub/preferences/thinking_target"
const PREF_SCROLL_BOTTOM:= "plugins/ai_assistant_hub/preferences/always_scroll_to_bottom"
const PREF_SKIP_GREETING:= "plugins/ai_assistant_hub/preferences/skip_greeting"
const PREF_AUDIO_HINTS:= "plugins/ai_assistant_hub/preferences/audio_hints"
const OPT_DEBUG:= "plugins/ai_assistant_hub/options/debug_mode"

const CONFIG_LLM_API:= "plugins/ai_assistant_hub/llm_api"

const LOG_PATH := "user://ai_assistant_hub/logs/debug.log"
const PLUGIN_DATA_PATH := "user://ai_assistant_hub/plugin_data.cfg"

# Configuration deprecated in version 1.6.0
const DEPRECATED_CONFIG_OPENROUTER_API_KEY := "plugins/ai_assistant_hub/openrouter_api_key"
const DEPRECATED_CONFIG_GEMINI_API_KEY := "plugins/ai_assistant_hub/gemini_api_key"
const DEPRECATED_CONFIG_OPENWEBUI_API_KEY := "plugins/ai_assistant_hub/openwebui_api_key"

var _hub_dock:AIAssistantHub
var _dock #Not giving type EditorDock to keep this compatible with versions older than 4.6

# Static area start ----

static func print_msg(message, is_error:=false, hide_from_log:String = "") -> void:
	var str_msg:= str(message)
	var option := ProjectSettings.get_setting(OPT_DEBUG, DebugOption.Disabled)
	if is_error:
		printerr("AI Hub: %s" % str_msg)
	elif option != DebugOption.Disabled:
		print("AI Hub: %s" % str_msg)
	if option == DebugOption.ConsoleAndLog:
		if hide_from_log != "":
			str_msg = str_msg.replace(hide_from_log, "[REDACTED]")
		var time = Time.get_datetime_string_from_system()
		if not DirAccess.dir_exists_absolute(LOG_PATH.get_base_dir()):
			DirAccess.make_dir_absolute(LOG_PATH.get_base_dir())
		var file:FileAccess
		if not FileAccess.file_exists(LOG_PATH):
			file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
		else:
			file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
		var err := file.get_open_error()
		if err == Error.OK:
			file.seek_end()
			file.store_line("%s: %s" % [time, str_msg])
			file.close()
		else:
			printerr("AI Hub: Error using log file: %s" % err)


static func print_err(message) -> void:
	print_msg(message, true)


static func print_hidding(message, hide_from_log:String) -> void:
	print_msg(message, false, hide_from_log)


# Static area end ----

func _enter_tree() -> void:
	initialize_project_settings()
	_hub_dock = load("res://addons/ai_assistant_hub/ai_assistant_hub.tscn").instantiate()
	_hub_dock.initialize(self)
	
	var godot_version: Dictionary = Engine.get_version_info()
	if godot_version.major >= 4 and godot_version.minor >= 6:
		# Loading EditorDock dynamically as it only exists in Godot 4.6+ and otherwise it won't compile in previous versions.
		var editor_dock_script : GDScript = GDScript.new()
		editor_dock_script.set_source_code("static func eval(): return EditorDock")
		var error = editor_dock_script.reload()
		if error == OK:
			_dock = editor_dock_script.eval().new()
			_dock.title = "AI Hub"
			_dock.default_slot = _dock.DOCK_SLOT_BOTTOM
			_dock.set_available_layouts(_dock.DOCK_LAYOUT_HORIZONTAL | _dock.DOCK_LAYOUT_FLOATING);
			_dock.add_child(_hub_dock)
			call("add_dock", _dock)
			_dock.open()
	
	if not _dock:
		add_control_to_bottom_panel(_hub_dock, "AI Hub")


func initialize_project_settings() -> void:
	if not ProjectSettings.has_setting(OPT_DEBUG):
		ProjectSettings.set_setting(OPT_DEBUG, DebugOption.Disabled)
		ProjectSettings.save()
	elif ProjectSettings.get_setting(OPT_DEBUG, DebugOption.Disabled) == DebugOption.ConsoleAndLog:
		if DirAccess.dir_exists_absolute(LOG_PATH.get_base_dir()):
			DirAccess.remove_absolute(LOG_PATH)
	var debug_property_info = {
		"name": OPT_DEBUG,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Disabled,Debug messages to Console,Debug messages to Console and log file"
	}
	print_msg("Version: %s" % get_version())
	print_msg("Godot version: %s" % Engine.get_version_info().string)
	ProjectSettings.add_property_info(debug_property_info)
	
	var last_ver:= "1.0.0"
	var plugin_data = ConfigFile.new()
	var err = plugin_data.load(PLUGIN_DATA_PATH)
	if err == Error.OK:
		last_ver = plugin_data.get_value("general","last_used_version", "1.0.0")
	
	if _version_lower_than(last_ver, "1.6.0"):
		_migrate_properties_1_6_0()
	
	if not ProjectSettings.has_setting(CONFIG_LLM_API):
		ProjectSettings.set_setting(CONFIG_LLM_API, "ollama_api")
		ProjectSettings.save()
	
	if not ProjectSettings.has_setting(PREF_REMOVE_THINK):
		ProjectSettings.set_setting(PREF_REMOVE_THINK, ThinkingTargets.Output)
		ProjectSettings.save()
	
	if not ProjectSettings.has_setting(PREF_SKIP_GREETING):
		ProjectSettings.set_setting(PREF_SKIP_GREETING, false)
		ProjectSettings.save()
	
	var think_property_info = {
		"name": PREF_REMOVE_THINK,
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Output,Chat,Discard"
	}
	ProjectSettings.add_property_info(think_property_info)
	
	if not ProjectSettings.has_setting(PREF_SCROLL_BOTTOM):
		ProjectSettings.set_setting(PREF_SCROLL_BOTTOM, false)
		ProjectSettings.save()
	
	if not ProjectSettings.has_setting(PREF_AUDIO_HINTS):
		ProjectSettings.set_setting(PREF_AUDIO_HINTS, true)
		ProjectSettings.save()
	
	plugin_data.set_value("general","last_used_version",get_version())
	plugin_data.save(PLUGIN_DATA_PATH)
	
	print_msg("Plugin initialized.")


func _exit_tree() -> void:
	print_msg("Removing dock.")
	if _dock:
		# Unloading dock dynamically as it only exists in Godot 4.6+ and otherwise it won't compile in previous versions.
		call("remove_dock", _dock)
	else:
		remove_control_from_bottom_panel(_hub_dock)
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
		print_err("No LLM provider has been selected.")
		return null
	if llm_provider.api_id.is_empty():
		print_err("Provider %s has no API ID." % llm_provider.api_id)
		return null
	var script_path = "res://addons/ai_assistant_hub/llm_apis/%s.gd" % llm_provider.api_id
	var script = load(script_path)
	if script == null:
		print_err("Failed to load LLM provider script: %s" % script_path)
		return null
	var instance:LLMInterface = script.new(llm_provider)
	if instance == null:
		print_err("Failed to instantiate the LLM provider from script: %s" % script_path)
		return null # Add this line to ensure a value is always returned
	return instance


func get_current_llm_provider() -> LLMProviderResource:
	return _hub_dock.get_selected_llm_resource()


func get_version() -> String:
	var config_path := "res://addons/ai_assistant_hub/plugin.cfg"
	var config := ConfigFile.new()
	var err := config.load(config_path)
	if err != OK:
		printerr("Error loading AI Assistan Hub plugin version from %s. Please install the plugin in res://addons/" % config_path)
		return "Unknown"
	var version:String = config.get_value("plugin", "version", "Unknown")
	return version


# Compare two version strings of 3 parts (e.g. 1.0.0)
# ---------------------------------------------------
# Return value:
#   -1  if v1 < v2
#    0  if v1 == v2
#    1  if v1 > v2
func _compare_versions(v1: String, v2: String) -> int:
	# Split the strings into their numeric parts
	var parts1 = v1.split(".")
	var parts2 = v2.split(".")
	# All versions are guaranteed to have 3 numeric parts
	for i in range(3):
		var a = int(parts1[i])
		var b = int(parts2[i])
		if a < b:
			return -1
		elif a > b:
			return 1
	return 0  # all parts are equal


func _version_lower_than(checked_version: String, target_version: String) -> bool:
	return _compare_versions(checked_version, target_version) == -1


func _migrate_properties_1_6_0() -> void:
	print_msg("Migrating old properties.")
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
		# The code below handles migrating the config from 1.2.0 to 1.3.0
		var old_path:= "ai_assistant_hub/llm_api"
		if ProjectSettings.has_setting(old_path):
			ProjectSettings.set_setting(CONFIG_LLM_API, ProjectSettings.get_setting(old_path))
			ProjectSettings.set_setting(old_path, null)
			ProjectSettings.save()
