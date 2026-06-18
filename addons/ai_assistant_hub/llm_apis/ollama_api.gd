## Class to handle Ollama API 
## You can use this class as an example to support other APIs.
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
	
	if context_length > 0:
		body_dict["options"] = { "num_ctx": context_length }
	
	if _supports_reasoning_levels:
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
	
	if _supports_tools:
		if tools_enabled:
			body_dict["tools"] = _tools_payload
		else:
			body_dict["tools"] = []
	
	var body := JSON.new().stringify(body_dict)
	
	if ProjectSettings.get_setting(AIHubPlugin.OPT_DEBUG_HTTP_CONTENT, false):
		AIHubPlugin.print_msg("Sending HTTP request:\n\tUrl: %s,\n\tHeaders: %s,\n\tBody: %s" % [_chat_url, HEADERS, body])
	else:
		AIHubPlugin.print_msg("Sending chat HTTP request:\n\tUrl: %s,\n\tHeaders: %s" % [_chat_url, HEADERS])
	var error := http_request.request(_chat_url, HEADERS, HTTPClient.METHOD_POST, body)
	if error != OK:
		AIHubPlugin.print_err("Something went wrong with last AI API call.\n\tURL: %s\n\tBody:\n\t%s" % [_chat_url, body])
		return false
	return true


func read_response(body) -> AIAssistantResponse:
	if body is PackedByteArray:
		if ProjectSettings.get_setting(AIHubPlugin.OPT_DEBUG_HTTP_CONTENT, false):
			AIHubPlugin.print_msg("Reading response:\n%s" % body.get_string_from_utf8())
		else:
			AIHubPlugin.print_msg("Reading response.")
		var json := JSON.new()
		json.parse(body.get_string_from_utf8())
		var json_response = json.get_data()
		if json_response.has("message"):
			var response:= AIAssistantResponse.new()
			
			var tool_calls_raw:Array
			if json_response.message.has("tool_calls"):
				if json_response.message.tool_calls is Array:
					tool_calls_raw = json_response.message.tool_calls
				else:
					AIHubPlugin.print_err("Tool calls content received, but is not an array.")
			else:
				tool_calls_raw = _try_to_find_tools(json_response.message.content)
			if not tool_calls_raw.is_empty():
				response.tool_calls_raw = tool_calls_raw
				response.tool_calls = _parse_tool_calls(tool_calls_raw)
				
			response.text_content = _msg_cleaner.clean(json_response.message.content)
			
			if json_response.message.has("thinking"):
				response.thought = json_response.message.thinking
			
			_read_context_used(json_response)
			return response
		return null
	else:
		AIHubPlugin.print_err("Invalid response: %s" % body)
		return null


## Handle models that send the tool calls in the chat content (like Qwen)
func _try_to_find_tools(content:String) -> Array:
	if content.begins_with("<tools>") and content.ends_with("</tools>"):
		content = content.lstrip("<tools>").rstrip("</tools>")
	if content.begins_with("```json") and content.ends_with("```"):
		content = content.lstrip("```json").rstrip("```")
	var tool_calls_raw:Array
	if content.begins_with("{") and content.ends_with("}"):
		var tool_json := JSON.new()
		var error := tool_json.parse(content)
		if error == OK:
			AIHubPlugin.print_msg("Chat content is JSON only, assuming it is a tool call.")
			var tool_from_content = tool_json.get_data()
			var invalid:= false
			if tool_from_content is Array:
				var contains_functions := true
				for entry in tool_from_content:
					contains_functions = contains_functions and (entry is Dictionary and entry.has("function"))
				if contains_functions:
					tool_calls_raw = tool_from_content
				else:
					invalid = true
			if tool_from_content is Dictionary and tool_from_content.has("name"):
				AIHubPlugin.print_msg("Forcing tool response into array of functions.")
				tool_calls_raw = [{ "function": tool_from_content }]
			else:
				invalid = true
			
			if invalid:
				AIHubPlugin.print_err("It seems the assistant tried to use a tool, but the format was unexpected. If the assistant is simply returning some JSON, you can ignore this error.")
	return tool_calls_raw


func _parse_tool_calls(tool_calls_payload:Array) -> Array[AIToolCall]:
	var ordered_calls:Array[AIToolCall] = []
	for i in tool_calls_payload.size():
		var call:Dictionary = tool_calls_payload[i]
		if call.has("function") and call.function is Dictionary:
			var call_id:String = call.function.get("id", "")
			var tool_name:String = call.function.get("name", "")
			if tool_name.is_empty():
				AIHubPlugin.print_err("Ollama: Invalid function call, name is empty. Call payload:\n%s" % str(call))
				return []
			var args:Dictionary = call.function.get("arguments", {})
			var tool_call := AIToolCall.new(tool_name, args, call_id)
			ordered_calls.append(tool_call)
	return ordered_calls


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


func send_get_capabilities_request(http_request:HTTPRequest, model_name:String) -> bool:
	var body_dict:= {
		model = model_name
	}
	var body := JSON.new().stringify(body_dict)
	var error = http_request.request(_capabilities_url, HEADERS, HTTPClient.METHOD_POST, body)
	if error != OK:
		AIHubPlugin.print_err("Something went wrong with last AI API call: %s" % _models_url)
		return false
	return true


func read_capabilities_response(body: PackedByteArray) -> Array[Capabilities]:
	if body is PackedByteArray:
		if ProjectSettings.get_setting(AIHubPlugin.OPT_DEBUG_HTTP_CONTENT, false):
			AIHubPlugin.print_msg("Reading capabilities response:\n%s" % body.get_string_from_utf8())
		else:
			AIHubPlugin.print_msg("Reading capabilities response.")
		var json := JSON.new()
		json.parse(body.get_string_from_utf8())
		var response = json.get_data()
		if response.has("capabilities"):
			var result: Array[Capabilities] = []
			for c in response.capabilities:
				match c:
					"thinking": result.append(Capabilities.ReasoningLevels)
					"tools": result.append(Capabilities.Tools)
			return result
		else:
			AIHubPlugin.print_msg("No capabilities found: %s" % body.get_string_from_utf8() if body != null else "Empty response")
			return []
	else:
		AIHubPlugin.print_err("Invalid response: %s" % body.get_string_from_utf8() if body != null else "Empty response")
		return []
