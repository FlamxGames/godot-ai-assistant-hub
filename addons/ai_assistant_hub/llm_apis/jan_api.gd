@tool
class_name JanAPI
extends LLMInterface

var _headers: PackedStringArray # set in _initialize function


func _rebuild_headers() -> void:
	_headers = ["Content-Type: application/json",
				"Authorization: Bearer %s" % _api_key,  # Include the key in the headers
	]


func _initialize() -> void:
	AIHubPlugin.print_msg("JanAPI _initialize")
	_rebuild_headers()
	AIHubPlugin.print_hidding("Headers: %s" % _headers, _api_key)
	llm_config_changed.connect(_rebuild_headers)


func send_get_models_request(http_request: HTTPRequest) -> bool:
	if _api_key.is_empty():
		AIHubPlugin.print_err("JanAPI API key not set. Please configure the API key in the main tab.")
		return false
	
	var err := http_request.request(_models_url, _headers, HTTPClient.METHOD_GET)
	if err != OK:
		AIHubPlugin.print_err("JanAPI GET models failed: %s" % _models_url)
		return false
	return true


func read_models_response(body: PackedByteArray) -> Array[String]:
	var j := JSON.new()
	j.parse(body.get_string_from_utf8())
	var data := j.get_data()
	if data != null and data.has("data") and data.data is Array:
		var out: Array[String]= []
		for m in data.data:
			if m.has("id"):
				out.append(m.id)
		out.sort()
		return out
	return [INVALID_RESPONSE]


func send_chat_request(http_request: HTTPRequest, content: Array) -> bool:
	if _api_key.is_empty():
		AIHubPlugin.print_err("JanAPI API key not set. Please configure the API key in the main tab and spawn a new assistant.")
		return false
	
	if model.is_empty():
		AIHubPlugin.print_err("ERROR: You need to set an AI model for this assistant type.")
		return false
	
	var body := {
		"model": model,
		"messages": content
	}
	if override_temperature:
		body["temperature"] = temperature
	var payload := JSON.new().stringify(body)
	var err := http_request.request(_chat_url, _headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		AIHubPlugin.print_err("JanAPI chat request failed: %s\n%s" % [_chat_url, payload])
		return false
	return true


func read_response(body: PackedByteArray) -> String:
	var j := JSON.new()
	j.parse(body.get_string_from_utf8())
	var data := j.get_data()
	if data.has("choices") and data.choices.size() > 0:
		var c = data.choices[0]
		if c.has("message") and c.message.has("content"):
			return _msg_cleaner.clean(c.message.content)
	return INVALID_RESPONSE
 
