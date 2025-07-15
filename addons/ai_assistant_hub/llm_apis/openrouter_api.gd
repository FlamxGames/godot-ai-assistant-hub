@tool
class_name OpenRouterAPI
extends LLMInterface

const DEPRECATED_API_KEY_SETTING := "plugins/ai_assistant_hub/openrouter_api_key"
const DEPRECATED_API_KEY_FILE := "res://addons/ai_assistant_hub/llm_apis/openrouter_api_key.gd"

var _headers: PackedStringArray # set in _initialize function


func _initialize() -> void:
	_headers = ["Content-Type: application/json",
				"Authorization: Bearer %s" % _api_key,  # Include the key in the headers
				"HTTP-Referer: godot://ai_assistant_hub", # OpenRouter requires source reference
	]


# Get model list
func send_get_models_request(http_request: HTTPRequest) -> bool:
	if _api_key.is_empty():
		push_error("OpenRouter API key not set. Please configure the API key in the main tab and spawn a new assistant.")
		return false
	
	var error = http_request.request(_models_url, _headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("OpenRouter API request failed: %s" % _models_url)
		return false
	return true


# Parse model list response
func read_models_response(body: PackedByteArray) -> Array[String]:
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response := json.get_data()
	
	if response.has("data") and response.data is Array:
		var model_names: Array[String] = []
		for model in response.data:
			if model.has("id"):
				model_names.append(model.id)
		model_names.sort()
		return model_names
	else:
		push_error("Failed to get model list from OpenRouter: %s" % JSON.stringify(response))
		return [INVALID_RESPONSE]


# Send chat request
func send_chat_request(http_request: HTTPRequest, content: Array) -> bool:
	if _api_key.is_empty():
		push_error("OpenRouter API key not set. Please configure the API key in the main tab and spawn a new assistant.")
		return false
	
	if model.is_empty():
		push_error("ERROR: You need to set an AI model for this assistant type.")
		return false
	
	# Build request body
	var body_dict := {
		"model": model,
		"messages": content
	}
	
	# Add temperature setting (if needed)
	if override_temperature:
		body_dict["temperature"] = temperature
	
	var body := JSON.stringify(body_dict)
	var error = http_request.request(_chat_url, _headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("OpenRouter API chat request failed.\nURL: %s\nRequest body: %s" % [_chat_url, body])
		return false
	return true


# Parse chat response
func read_response(body: PackedByteArray) -> String:
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response := json.get_data()
	
	if response.has("choices") and response.choices.size() > 0:
		if response.choices[0].has("message") and response.choices[0].message.has("content"):
			return ResponseCleaner.clean(response.choices[0].message.content)
	
	push_error("Failed to parse OpenRouter response: %s" % JSON.stringify(response))
	return INVALID_RESPONSE


# ----- Deprecated section - used to read the key to migrate to user settings file -----

func get_deprecated_api_key() -> String:
	var old_api_key := _deprecated_load_api_key_from_file()
	if old_api_key.is_empty() and ProjectSettings.has_setting(DEPRECATED_API_KEY_SETTING):
		old_api_key = ProjectSettings.get_setting(DEPRECATED_API_KEY_SETTING)
	return old_api_key


func _deprecated_load_api_key_from_file() -> String:
	if not FileAccess.file_exists(DEPRECATED_API_KEY_FILE):
		return ""
	var file := FileAccess.open(DEPRECATED_API_KEY_FILE, FileAccess.READ)
	if not file:
		return ""
	var content := file.get_as_text()
	file.close()
	var regex := RegEx.new()
	regex.compile('const API_KEY := "([^"]*)"')
	var result := regex.search(content)
	if result and result.get_group_count() > 0:
		return result.get_string(1)
	return ""
