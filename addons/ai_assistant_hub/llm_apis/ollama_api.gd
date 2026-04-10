@tool
class_name OllamaAPI
extends LLMInterface

const HEADERS := ["Content-Type: application/json"]


func send_get_models_request(http_request:HTTPRequest) -> bool:
	var error = http_request.request(_models_url, HEADERS, HTTPClient.METHOD_GET)
	if error != OK:
		AIHubPlugin.print_err("Something went wrong with last AI API call: %s" % _models_url)
		return false
	return true


func read_models_response(body:PackedByteArray) -> Array[String]:
	var json := JSON.new()
	json.parse(body.get_string_from_utf8())
	var response := json.get_data()
	if response.has("models"):
		var model_names:Array[String] = []
		for entry in response.models:
			model_names.append(entry.model)
		model_names.sort()
		return model_names
	else:
		return [INVALID_RESPONSE]


func send_chat_request(http_request:HTTPRequest, content:Array) -> bool:
	if model.is_empty():
		AIHubPlugin.print_err("ERROR: You need to set an AI model for this assistant type.")
		return false
	
	var body_dict := {
		"messages": content,
		"stream": false,
		"model": model
	}
	
	if override_temperature:
		body_dict["options"] = { "temperature": temperature }
	
	# This must match the Reasoning Levels array in the corresponding LLMProviderResource
	# The array supports setting a tooltip by using pipe "|", for example:
	#   "Disabled | In supported models, generates the answer without a reasoning step"
	# This should match only the first part of the string before the pipe.
	match reasoning:
		"Disabled": body_dict["think"] = false
		"Enabled": body_dict["think"] = true
		"Low": body_dict["think"] = "low"
		"Medium": body_dict["think"] = "medium"
		"High": body_dict["think"] = "high"
	
	var body := JSON.new().stringify(body_dict)
	
	#AIHubPlugin.print_msg("Sending HTTP request:\n\tUrl: %s,\n\tHeaders: %s,\n\tBody: %s" % [_chat_url, HEADERS, body])
	AIHubPlugin.print_msg("Sending chat HTTP request:\n\tUrl: %s,\n\tHeaders: %s" % [_chat_url, HEADERS])
	var error := http_request.request(_chat_url, HEADERS, HTTPClient.METHOD_POST, body)
	if error != OK:
		AIHubPlugin.print_err("Something went wrong with last AI API call.\n\tURL: %s\n\tBody:\n\t%s" % [_chat_url, body])
		return false
	return true


func read_response(body) -> String:
	if body is PackedByteArray:
		AIHubPlugin.print_msg("Reading response.")
		#AIHubPlugin.print_msg("Reading response:\n%s" % body.get_string_from_utf8())
		var json := JSON.new()
		json.parse(body.get_string_from_utf8())
		var response = json.get_data()
		var msg:String
		if response.has("message"):
			if response.message.has("thinking"):
				msg += handle_thinking(response.message.thinking)
			msg += _msg_cleaner.clean(response.message.content)
			_read_context_used(response)
		else:
			msg = LLMInterface.INVALID_RESPONSE
		return msg
	else:
		AIHubPlugin.print_err("Invalid response: %s" % body)
		return LLMInterface.INVALID_RESPONSE


func _read_context_used(response:Dictionary) -> void:
	if response.has("prompt_eval_count") and response.has("eval_count"):
		var input_tokens = response.prompt_eval_count
		var generated_tokens = response.eval_count
		_current_context = input_tokens + generated_tokens


func detect_max_context(http_request:HTTPRequest) -> void:
	AIHubPlugin.print_msg("Calling max context url %s" % _max_context_url)
	var error := http_request.request(_max_context_url, HEADERS)
	if error != OK:
		AIHubPlugin.print_err("Error while trying to get max context for model.\n\tURL: %s" % [_max_context_url])


func read_max_context_http_response(body: PackedByteArray) -> void:
	_max_context = 0
	if body is PackedByteArray:
		var body_string := body.get_string_from_utf8()
		AIHubPlugin.print_msg("Reading max context from %s" % body_string)
		var json := JSON.new()
		json.parse(body_string)
		var response = json.get_data()
		if response.has("models") and response.models is Array:
			for entry in response.models:
				if entry is Dictionary and entry.has("name") and entry.has("context_length") and entry.name == model:
					_max_context = entry.context_length
					AIHubPlugin.print_msg("Max context found for model %s: %d" % [model, _max_context])
					context_usage_updated.emit(_max_context, _current_context)
					break
