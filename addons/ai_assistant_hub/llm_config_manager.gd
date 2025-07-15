class_name LLMConfigManager
extends Node

const ADDON_FOLDER_PATH := "user://ai_assistant_hub/"
const SETTINGS_FILE_NAME := "llm_settings.cfg"

const SETTING_URL := "url"
const SETTING_API_KEY := "api_key"

var _api_id:String
var _llm_settings_path:String

func _init(api_id:String) -> void:
	_api_id = api_id
	if _api_id.is_empty():
		push_error("Error while configuring API settings, no API ID provided")
	if not DirAccess.dir_exists_absolute(ADDON_FOLDER_PATH):
		DirAccess.make_dir_absolute(ADDON_FOLDER_PATH)
	_llm_settings_path = ADDON_FOLDER_PATH + SETTINGS_FILE_NAME


func save_url(url:String) -> void:
	_save_string_property(SETTING_URL, url)


func load_url() -> String:
	return _load_string_property(SETTING_URL)


func save_key(key:String) -> void:
	_save_string_property(SETTING_API_KEY, key)


func load_key() -> String:
	return _load_string_property(SETTING_API_KEY)


func _save_string_property(property:String, value:String) -> void:
	if not _api_id.is_empty() and not value.is_empty():
		var config = ConfigFile.new()
		var load_response := config.load(_llm_settings_path)
		var current_value := ""
		if load_response == OK:
			current_value = config.get_value(_api_id, property, "")
		if current_value != value:
			config.set_value(_api_id, property, value)
			var save_response := config.save(_llm_settings_path)
			if save_response != OK:
				printerr("Error when saving API configuration. Error: %d" % save_response)
	else:
		printerr("Cannot save API configuration, API ID or %s value is null" % property)


func _load_string_property(property:String) -> String:
	var config := ConfigFile.new()
	var load_response := config.load(_llm_settings_path)
	if load_response == OK:
		var stored_value = config.get_value(_api_id, property, "")
		return stored_value
	return ""


## Function to migrate Base Url settings in version 1.5.0 or earlier, to user settings per LLM
func migrate_deprecated_1_5_0_base_url() -> void:
	var deprecated_base_url_1_2_0:= "ai_assistant_hub/base_url"
	var old_base_url := ""
	if ProjectSettings.has_setting(deprecated_base_url_1_2_0):
		old_base_url = ProjectSettings.get_setting(deprecated_base_url_1_2_0, "")
		ProjectSettings.set_setting(deprecated_base_url_1_2_0, null)
		ProjectSettings.save()
	var deprecated_base_url_1_5_0:= "plugins/ai_assistant_hub/base_url"
	if ProjectSettings.has_setting(deprecated_base_url_1_5_0):
		old_base_url = ProjectSettings.get_setting(deprecated_base_url_1_5_0, "")
		ProjectSettings.set_setting(deprecated_base_url_1_5_0, null)
		ProjectSettings.save()
	if not old_base_url.is_empty():
		print("Migrating base URL project settings to per LLM settings")
		if not _api_id.is_empty() and _api_id != "gemini_api" and _api_id != "openrouter_api":
			if load_url().is_empty():
				save_url(old_base_url)


## Function to migrate API keys in version 1.5.0 or earlier, to user settings
func migrate_deprecated_1_5_0_api_key(old_key:String, old_key_settings:String, old_key_file:String = "") -> void:
	if not old_key.is_empty():
		var new_key := load_key()
		if new_key.is_empty():
			print("Migrating existing %s Key to user settings" % _api_id)
			save_key(old_key)
		print("Deleting old %s Key project settings and redundant API key file" % _api_id)
		if not old_key_file.is_empty() and FileAccess.file_exists(old_key_file):
			var err := OS.move_to_trash(ProjectSettings.globalize_path(old_key_file))
			if err != OK:
				printerr("Error while trying to delete deprecated %s API key file. Error: %d" % [_api_id, err])
		if ProjectSettings.has_setting(old_key_settings):
			ProjectSettings.set_setting(old_key_settings, null)
			ProjectSettings.save()
