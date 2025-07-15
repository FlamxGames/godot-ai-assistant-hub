@tool
class_name GeminiAPI
extends LLMInterface

const DEPRECATED_API_KEY_SETTING := "plugins/ai_assistant_hub/gemini_api_key"
const DEPRECATED_API_KEY_FILE := "res://addons/ai_assistant_hub/llm_apis/gemini_api_key.gd"


var _headers := PackedStringArray([
	"Content-Type: application/json"
])


func _initialize() -> void:
	_rebuild_urls()
	llm_config_changed.connect(_rebuild_urls)
	model_changed.connect(_rebuild_urls.unbind(1))


func _rebuild_urls() -> void:
	_models_url = "%s?key=%s" % [_base_url, _api_key]
	_chat_url = "%s/%s:generateContent?key=%s" % [_base_url, model, _api_key]


# Get model list (Gemini has a fixed set, but we can fetch or hardcode)
func send_get_models_request(http_request: HTTPRequest) -> bool:
	#API key is in LLMInterface base class
	if _api_key.is_empty():
		push_error("Gemini API key not set. Configure the API key in the main tab and try again.")
		return false

	var error = http_request.request(_models_url, _headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("Gemini API request failed: %s" % _models_url)
		return false
	return true


func read_models_response(body: PackedByteArray) -> Array[String]:
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response := json.get_data()
	if response.has("models") and response.models is Array:
		var model_names: Array[String] = []
		for model in response.models:
			if model.has("name"):
				model_names.append(model.name)
		model_names.sort()
		return model_names
	else:
		return [INVALID_RESPONSE]


# Helper function: recursively extract 'content' from stringified JSON messages
func _extract_content_from_json_string(s) -> String:
	var attempts := 0
	var txt = s
	while typeof(txt) == TYPE_STRING and txt.begins_with("{") and txt.find("\"content\"") != -1 and attempts < 3:
		var json := JSON.new()
		if json.parse(txt) == OK:
			var jmsg = json.get_data()
			if "content" in jmsg:
				txt = jmsg["content"]
				attempts += 1
			else:
				break
		else:
			break
	return str(txt)


# NOTE: content is expected as Array of user/system/assistant message texts, not raw JSON.
# This method will transform the array into the required Gemini format.
func send_chat_request(http_request: HTTPRequest, message_list: Array) -> bool:
	# message_list is Array of Dictionaries: [{role="user", text="Hello"}, ...]
	if _api_key.is_empty():
		push_error("Gemini API key not set. Configure the API key in the main tab and spawn a new assistant.")
		return false

	if model.is_empty():
		push_error("ERROR: You need to set an AI model for this assistant type.")
		return false
	
	# Ensure model does not have "models/" prefix
	if model.begins_with("models/"):
		model = model.substr("models/".length())

	# Gemini expects each message with role and a parts array of {text: ...}
	var formatted_contents := []
	for i in range(message_list.size()):
		var msg = message_list[i]
		var role: String = str(msg.get("role", "user"))
		var text = msg.get("content", msg.get("text", msg))
		text = _extract_content_from_json_string(text)

		# If it's the first message and it's a system message, change the role to user
		if i == 0 and role == "system":
			role = "user"

		formatted_contents.append({
			"role": role,
			"parts": [ { "text": str(text) } ]
		})
	
	#print("ACTUAL message_list: ", message_list)

	var body_dict := {
		"contents": formatted_contents
	}
	if override_temperature:
		body_dict["generationConfig"] = { "temperature": temperature }
	var body := JSON.stringify(body_dict)

	var error = http_request.request(_chat_url, _headers, HTTPClient.METHOD_POST, body)
	#print("Gemini API Request URL: ", _chat_url)
	#print("Gemini API Request body: ", body)
	if error != OK:
		push_error("Gemini API chat request failed.\nURL: %s\nRequest body: %s" % [_chat_url, body])
		return false
	return true


func read_response(body: PackedByteArray) -> String:
	var raw_body = body.get_string_from_utf8()
	#print("Gemini API raw response: ", raw_body)
	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	#print("HTTP Response body: ", body.get_string_from_utf8())
	if parse_result != OK:
		push_error("Failed to parse Gemini response JSON: %s" % json.get_error_message())
		return INVALID_RESPONSE
	var response := json.get_data()
	if response == null:
		push_error("Gemini response is null after parsing.")
		return INVALID_RESPONSE
	# Print and handle Gemini errors
	if response.has("error"):
		print("Gemini API Error: ", JSON.stringify(response.error))
		push_error("Gemini API Error: " + str(response.error))
		return INVALID_RESPONSE
	if response.has("candidates") and response.candidates.size() > 0:
		if response.candidates[0].has("content") and response.candidates[0].content.has("parts"):
			var parts = response.candidates[0].content.parts
			if parts.size() > 0 and parts[0].has("text"):
				return ResponseCleaner.clean(parts[0].text)
	push_error("Failed to parse Gemini response: %s" % JSON.stringify(response))
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
