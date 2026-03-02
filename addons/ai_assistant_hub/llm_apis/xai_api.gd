@tool
class_name XaiAPI
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
		push_error("xAI API key not set. Configure the API key in the main tab and try again.")
		return false

	var error = http_request.request(_models_url, _headers, HTTPClient.METHOD_GET)
	if error != OK:
		push_error("xAI API request failed: %s" % _models_url)
		return false
	return true


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
# This method will transform the array into the required xAI format.
func send_chat_request(http_request: HTTPRequest, message_list: Array) -> bool:
	# example request data: 
	#{ "messages": [ { "role": "system", "content": "You are a helpful assistant that can answer questions and help with tasks." }, { "role": "user", "content": "What is 101*3?" } ], "model": "grok-4-0709" }
	if _api_key.is_empty():
		push_error("xAI API key not set. Configure the API key in the main tab and spawn a new assistant.")
		return false

	if model.is_empty():
		push_error("ERROR: You need to set an AI model for this assistant type.")
		return false

	var formatted_contents := []
	for i in range(message_list.size()):
		var msg = message_list[i]
		var role: String = str(msg.get("role", "user"))
		var text = msg.get("content", msg.get("text", msg))
		#print(text)
		#text = _extract_content_from_json_string(text)

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
	#print(_chat_url)

	var error = http_request.request(_chat_url, _headers, HTTPClient.METHOD_POST, body)
	
	if error != OK:
		push_error("xAI API chat request failed.\nURL: %s\nRequest body: %s" % [_chat_url, body])
		return false
	return true


func read_response(body: PackedByteArray) -> String:
	# example response data
	#{"id":"2a2db6ed-6e92-e80e-6bc5-0db5e4b3deba","object":"chat.completion","created":1770680490,"model":"grok-4-0709","choices":[{"index":0,"message":{"role":"assistant","content":"101 × 3 = 303.","refusal":null},"finish_reason":"stop"}],"usage":
	#{"prompt_tokens":706,"completion_tokens":8,"total_tokens":783,"prompt_tokens_details":{"text_tokens":706,"audio_tokens":0,"image_tokens":0,"cached_tokens":689},"completion_tokens_details":
	#{"reasoning_tokens":69,"audio_tokens":0,"accepted_prediction_tokens":0,"rejected_prediction_tokens":0},"num_sources_used":0,"cost_in_usd_ticks":17227500},"system_fingerprint":"fp_dd0aa291c6"}
	
	var raw_body = body.get_string_from_utf8()
	#print("xAI API raw response: ", raw_body)
	
	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	#print("HTTP Response body: ", body.get_string_from_utf8())
	if parse_result != OK:
		push_error("Failed to parse xAI response JSON: %s" % json.get_error_message())
		return INVALID_RESPONSE
	var response := json.get_data()
	if response == null:
		push_error("xAI response is null after parsing.")
		return INVALID_RESPONSE
	# Print and handle xAI errors
	if response.has("error"):
		#print("xAI API Error: ", JSON.stringify(response.error))
		push_error("xAI API Error: " + str(response.error))
		return INVALID_RESPONSE
	if response.has("choices") and response.choices.size() > 0:
		if response.choices[0].has("message") and response.choices[0].message.has("content"):
			return ResponseCleaner.clean(response.choices[0].message.content)
	push_error("Failed to parse xAI response: %s" % JSON.stringify(response))
	return INVALID_RESPONSE
