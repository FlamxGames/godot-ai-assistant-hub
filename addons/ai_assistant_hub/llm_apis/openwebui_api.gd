@tool
class_name OpenWebUIAPI
extends LLMInterface

var _headers: PackedStringArray # set in initialize function

const DEPRECATED_API_KEY_SETTING := "plugins/ai_assistant_hub/openwebui_api_key"


func _initialize() -> void:
	_headers = ["Content-Type: application/json", 
				"Authorization: Bearer %s" % _api_key ]


func send_get_models_request(http_request:HTTPRequest) -> bool:
	if _api_key.is_empty():
		push_error("OpenWebUI API key not set. Please configure the API key in the main tab and spawn a new assistant.")
		return false
	
	var error = http_request.request(_models_url, _headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("Something when wrong with last AI API call: %s" % _models_url)
		return false
	return true


func read_models_response(body:PackedByteArray) -> Array[String]:
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response := json.get_data()
	if response.has("data"):
		var model_names:Array[String] = []
		for entry in response.data:
			model_names.append(entry.name)
		model_names.sort()
		return model_names
	else:
		return [INVALID_RESPONSE]


func send_chat_request(http_request:HTTPRequest, content:Array) -> bool:
	if _api_key.is_empty():
		push_error("OpenWebUI API key not set. Please configure the API key in the main tab and spawn a new assistant.")
		return false
	
	if model.is_empty():
		push_error("ERROR: You need to set an AI model for this assistant type.")
		return false
	
	var body_dict := {
		"messages": content,
		"stream": false,
		"model": model
	}
	
	if override_temperature:
		body_dict["options"] = { "temperature": temperature }
	
	var body := JSON.new().stringify(body_dict)
	
	var error = http_request.request(_chat_url, _headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("Something when wrong with last AI API call.\nURL: %s\nBody:\n%s" % [_chat_url, body])
		return false
	return true


func read_response(body) -> String:
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response := json.get_data()
	if response.has("choices"):
		return ResponseCleaner.clean(response.choices[0].message.content)
	else:
		return LLMInterface.INVALID_RESPONSE


# ----- Deprecated section - used to read the key to migrate to user settings file -----

func get_deprecated_api_key() -> String:
	return ProjectSettings.get_setting(DEPRECATED_API_KEY_SETTING, "")
