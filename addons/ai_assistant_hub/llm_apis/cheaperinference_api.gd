@tool
class_name CheaperInferenceAPI
extends LLMInterface

var _headers: PackedStringArray # set in _initialize function


func _rebuild_headers() -> void:
	_headers = ["Content-Type: application/json",
				"Authorization: Bearer %s" % _api_key,  # Include the key in the headers
	]


func _initialize() -> void:
	_rebuild_headers()
	llm_config_changed.connect(_rebuild_headers)


# Get model list
func send_get_models_request(http_request: HTTPRequest) -> bool:
	#API key is in LLMInterface base class
	if _api_key.is_empty():
		AIHubPlugin.print_err("Cheaper Inference API key not set. Configure the API key in the main tab and try again.")
		return false

	var error = http_request.request(_models_url, _headers, HTTPClient.METHOD_GET)
	if error != OK:
		AIHubPlugin.print_err("Cheaper Inference API request failed: %s" % _models_url)
		return false
	return true


# Parse model list response
func read_models_response(body: PackedByteArray) -> Array[String]:
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response := json.get_data()
	if response is Dictionary and response.has("data") and response.data is Array:
		var model_names: Array[String] = []
		for model_data in response.data:
			if model_data.has("id"):
				model_names.append(model_data.id)
		model_names.sort()
		return model_names
	else:
		AIHubPlugin.print_err("Failed to get model list from Cheaper Inference: %s" % JSON.stringify(response))
		return [INVALID_RESPONSE]


# NOTE: content is expected as Array of user/system/assistant message texts, not raw JSON.
# This method will transform the array into the OpenAI-compatible chat format.
func send_chat_request(http_request: HTTPRequest, message_list: Array) -> bool:
	# example request data:
	#{ "messages": [ { "role": "system", "content": "You are a helpful assistant." }, { "role": "user", "content": "What is 101*3?" } ], "model": "gpt-5.4-mini" }
	if _api_key.is_empty():
		AIHubPlugin.print_err("Cheaper Inference API key not set. Configure the API key in the main tab and spawn a new assistant.")
		return false

	if model.is_empty():
		AIHubPlugin.print_err("ERROR: You need to set an AI model for this assistant type.")
		return false

	var formatted_contents := []
	for msg in message_list:
		var role: String = str(msg.get("role", "user"))
		var text = msg.get("content", msg.get("text", msg))
		formatted_contents.append({
			"role": role,
			"content": str(text)
		})

	var body_dict := {
		"messages": formatted_contents,
		"model": model
	}
	if override_temperature:
		body_dict["temperature"] = temperature
	var body := JSON.stringify(body_dict)

	var error = http_request.request(_chat_url, _headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		AIHubPlugin.print_err("Cheaper Inference API chat request failed.\nURL: %s\nRequest body: %s" % [_chat_url, body])
		return false
	return true


func read_response(body: PackedByteArray) -> AIAssistantResponse:
	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		AIHubPlugin.print_err("Failed to parse Cheaper Inference response JSON: %s" % json.get_error_message())
		return null
	var json_response := json.get_data()
	if json_response == null:
		AIHubPlugin.print_err("Cheaper Inference response is null after parsing.")
		return null
	if json_response.has("error"):
		AIHubPlugin.print_err("Cheaper Inference API Error: " + str(json_response.error))
		return null
	if json_response.has("choices") and json_response.choices.size() > 0:
		if json_response.choices[0].has("message") and json_response.choices[0].message.has("content"):
			var response:= AIAssistantResponse.new()
			response.text_content = _msg_cleaner.clean(json_response.choices[0].message.content)
			return response
	AIHubPlugin.print_err("Failed to parse Cheaper Inference response: %s" % JSON.stringify(json_response))
	return null
