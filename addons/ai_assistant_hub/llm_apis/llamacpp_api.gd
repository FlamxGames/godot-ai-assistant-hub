@tool
class_name LlamaCppAPI
extends LLMInterface

## First-class llama.cpp llama-server provider.
##
## llama-server exposes an OpenAI-compatible API, but the AI Assistant Hub's
## conversation history is shaped around Ollama. This adapter normalizes the
## model list, chat responses, tool calls, tool-result messages, reasoning, and
## context metadata so the rest of the plugin can use the same workflows.

const REASONING_BUDGET_LOW := 512
const REASONING_BUDGET_MEDIUM := 2048
const REASONING_BUDGET_HIGH := 8192

var _headers: PackedStringArray


func _initialize() -> void:
	_rebuild_headers()
	llm_config_changed.connect(_rebuild_headers)


func _rebuild_headers() -> void:
	_headers = ["Content-Type: application/json"]
	# llama-server API keys are optional. When one is configured in AI Hub,
	# send it using the OpenAI-compatible Bearer header.
	if not _api_key.is_empty():
		_headers.append("Authorization: Bearer %s" % _api_key)


func send_get_models_request(http_request: HTTPRequest) -> bool:
	var error := http_request.request(_models_url, _headers, HTTPClient.METHOD_GET)
	if error != OK:
		AIHubPlugin.print_err("llama.cpp GET models failed: %s" % _models_url)
		return false
	return true


func read_models_response(body: PackedByteArray) -> Array[String]:
	var response := _parse_json_dictionary(body, "models response")
	if response.has("data") and response.data is Array:
		var model_names: Array[String] = []
		for entry in response.data:
			if entry is Dictionary and entry.has("id"):
				model_names.append(str(entry.id))
		model_names.sort()
		return model_names
	return [INVALID_RESPONSE]


func send_chat_request(http_request: HTTPRequest, content: Array) -> bool:
	if model.is_empty():
		AIHubPlugin.print_err("ERROR: You need to set an AI model for this assistant type.")
		return false

	var body_dict := {
		"model": model,
		"messages": _normalize_messages_for_openai(content),
		"stream": false,
		# Reuse the shared prompt prefix between turns when llama-server can.
		"cache_prompt": true
	}

	if override_temperature:
		body_dict["temperature"] = temperature

	if _supports_reasoning_levels:
		_apply_reasoning_options(body_dict)

	if _supports_tools and tools_enabled:
		body_dict["tools"] = _tools_payload
		body_dict["tool_choice"] = "auto"
		# AI Assistant Hub currently executes tool calls serially.
		body_dict["parallel_tool_calls"] = false
		body_dict["parse_tool_calls"] = true

	var body := JSON.stringify(body_dict)
	if ProjectSettings.get_setting(AIHubPlugin.OPT_DEBUG_HTTP_CONTENT, false):
		AIHubPlugin.print_hidding(
			"Sending llama.cpp HTTP request:\n\tUrl: %s,\n\tHeaders: %s,\n\tBody: %s" % [_chat_url, _headers, body],
			_api_key
		)
	else:
		AIHubPlugin.print_hidding(
			"Sending llama.cpp chat HTTP request:\n\tUrl: %s,\n\tHeaders: %s" % [_chat_url, _headers],
			_api_key
		)

	var error := http_request.request(_chat_url, _headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		AIHubPlugin.print_err("llama.cpp chat request failed.\n\tURL: %s\n\tBody:\n\t%s" % [_chat_url, body])
		return false
	return true


func read_response(body: PackedByteArray) -> AIAssistantResponse:
	if ProjectSettings.get_setting(AIHubPlugin.OPT_DEBUG_HTTP_CONTENT, false):
		AIHubPlugin.print_msg("Reading llama.cpp response:\n%s" % body.get_string_from_utf8())
	else:
		AIHubPlugin.print_msg("Reading llama.cpp response.")

	var response_data := _parse_json_dictionary(body, "chat response")
	if not response_data.has("choices") or not (response_data.choices is Array) or response_data.choices.is_empty():
		return null

	var first_choice = response_data.choices[0]
	if not (first_choice is Dictionary) or not first_choice.has("message") or not (first_choice.message is Dictionary):
		return null

	var message: Dictionary = first_choice.message
	var response := AIAssistantResponse.new()

	var content_value = message.get("content", "")
	if content_value is String:
		response.text_content = _msg_cleaner.clean(content_value)
	elif content_value != null:
		response.text_content = _msg_cleaner.clean(str(content_value))

	var tool_calls_raw: Array = []
	if message.has("tool_calls") and message.tool_calls is Array:
		tool_calls_raw = _normalize_tool_calls(message.tool_calls)
	if tool_calls_raw.is_empty() and not response.text_content.is_empty():
		tool_calls_raw = _try_to_find_tools(response.text_content)

	if not tool_calls_raw.is_empty():
		response.tool_calls_raw = tool_calls_raw
		response.tool_calls = _parse_tool_calls(tool_calls_raw)

	var reasoning_content = message.get("reasoning_content", message.get("thinking", ""))
	if reasoning_content is String:
		response.thought = reasoning_content

	_read_context_used(response_data)
	return response


func detect_max_context(http_request: HTTPRequest) -> void:
	var url := _url_for_model(_max_context_url, model)
	AIHubPlugin.print_msg("Calling llama.cpp max context URL %s" % url)
	var error := http_request.request(url, _headers, HTTPClient.METHOD_GET)
	if error != OK:
		AIHubPlugin.print_err("Error while trying to get llama.cpp max context.\n\tURL: %s" % url)


func read_max_context_http_response(body: PackedByteArray) -> void:
	_max_context = 0
	var response := _parse_json_dictionary(body, "server properties")
	var generation_settings = response.get("default_generation_settings", {})
	if generation_settings is Dictionary and generation_settings.has("n_ctx"):
		var server_context := int(generation_settings.n_ctx)
		_max_context = server_context

		# Stock llama-server fixes the physical context size at startup. Keep the
		# assistant setting useful as a lower, client-side warning threshold and
		# never report a value larger than the running server can provide.
		if context_length > 0:
			_max_context = mini(server_context, context_length)
			if context_length != server_context:
				AIHubPlugin.print_msg(
					"llama.cpp context is fixed by the server at %d tokens; AI Hub will use %d tokens as this assistant's context warning threshold." % [server_context, _max_context]
				)

		AIHubPlugin.print_msg("llama.cpp context available for model %s: %d" % [model, _max_context])
		context_usage_updated.emit(_max_context, _current_context)


func send_get_capabilities_request(http_request: HTTPRequest, model_name: String) -> bool:
	var url := _url_for_model(_capabilities_url, model_name)
	var error := http_request.request(url, _headers, HTTPClient.METHOD_GET)
	if error != OK:
		AIHubPlugin.print_err("llama.cpp capabilities request failed: %s" % url)
		return false
	return true


func read_capabilities_response(body: PackedByteArray) -> Array[Capabilities]:
	var response := _parse_json_dictionary(body, "capabilities response")
	if response.is_empty():
		return []

	var result: Array[Capabilities] = []
	var template_caps: Dictionary = {}
	var template_caps_value = response.get("chat_template_caps", {})
	if template_caps_value is Dictionary:
		template_caps = template_caps_value

	var supports_tools := false
	if template_caps.has("supports_tools"):
		supports_tools = bool(template_caps.get("supports_tools", false)) \
			and bool(template_caps.get("supports_tool_calls", true))
	else:
		# Compatibility fallback for older llama-server builds that expose a
		# template but do not yet report chat_template_caps.
		supports_tools = not str(response.get("chat_template", "")).is_empty()

	if supports_tools:
		result.append(Capabilities.Tools)

	var generation_settings = response.get("default_generation_settings", {})
	var generation_params: Dictionary = {}
	if generation_settings is Dictionary and generation_settings.get("params", {}) is Dictionary:
		generation_params = generation_settings.get("params", {})

	var chat_template := str(response.get("chat_template", ""))
	var supports_reasoning := generation_params.has("reasoning_format") \
		or chat_template.contains("thinking") \
		or chat_template.contains("reasoning") \
		or chat_template.contains("<think>")
	if supports_reasoning:
		result.append(Capabilities.ReasoningLevels)

	return result


func _apply_reasoning_options(body_dict: Dictionary) -> void:
	match reasoning:
		"Disabled":
			body_dict["reasoning_effort"] = "none"
			_set_reasoning_budget(body_dict, 0)
			body_dict["chat_template_kwargs"] = {"enable_thinking": false}
		"Enabled":
			_set_reasoning_budget(body_dict, -1)
			body_dict["chat_template_kwargs"] = {"enable_thinking": true}
		"Low":
			_set_reasoning_budget(body_dict, REASONING_BUDGET_LOW)
			body_dict["chat_template_kwargs"] = {"enable_thinking": true}
		"Medium":
			_set_reasoning_budget(body_dict, REASONING_BUDGET_MEDIUM)
			body_dict["chat_template_kwargs"] = {"enable_thinking": true}
		"High":
			_set_reasoning_budget(body_dict, REASONING_BUDGET_HIGH)
			body_dict["chat_template_kwargs"] = {"enable_thinking": true}
		_:
			# Default leaves model and server behavior unchanged.
			pass


func _set_reasoning_budget(body_dict: Dictionary, budget: int) -> void:
	# Current llama-server prefers reasoning_budget_tokens. Older builds used
	# thinking_budget_tokens, so send both with the same value.
	body_dict["reasoning_budget_tokens"] = budget
	body_dict["thinking_budget_tokens"] = budget


func _normalize_messages_for_openai(content: Array) -> Array:
	var normalized_messages: Array = []
	var pending_calls: Array[Dictionary] = []

	for message_value in content:
		if not (message_value is Dictionary):
			normalized_messages.append(message_value)
			continue

		var message: Dictionary = message_value.duplicate(true)
		var role := str(message.get("role", ""))

		if role == "assistant" and message.has("tool_calls") and message.tool_calls is Array:
			var normalized_calls := _normalize_tool_calls(message.get("tool_calls", []))
			message["tool_calls"] = normalized_calls
			for call_value in normalized_calls:
				if call_value is Dictionary and call_value.get("function", {}) is Dictionary:
					pending_calls.append({
						"id": str(call_value.get("id", "")),
						"name": str(call_value.function.get("name", ""))
					})

		elif role == "tool":
			var existing_call_id := str(message.get("tool_call_id", ""))
			if existing_call_id.is_empty() and not pending_calls.is_empty():
				var pending_call: Dictionary = pending_calls.pop_front()
				message["tool_call_id"] = pending_call.id
				if not str(pending_call.name).is_empty():
					message["name"] = pending_call.name
			elif not existing_call_id.is_empty():
				_remove_pending_call(pending_calls, existing_call_id)

		normalized_messages.append(message)

	return normalized_messages


func _remove_pending_call(pending_calls: Array[Dictionary], call_id: String) -> void:
	for index in range(pending_calls.size()):
		if str(pending_calls[index].get("id", "")) == call_id:
			pending_calls.remove_at(index)
			return


func _normalize_tool_calls(tool_calls_payload: Array) -> Array:
	var normalized_calls: Array = []
	for index in range(tool_calls_payload.size()):
		var raw_call = tool_calls_payload[index]
		if not (raw_call is Dictionary):
			continue

		var function_data: Dictionary = {}
		if raw_call.get("function", {}) is Dictionary:
			function_data = raw_call.function.duplicate(true)
		elif raw_call.has("name"):
			# Compatibility with older llama-server responses that returned a
			# flattened {name, arguments} tool-call object.
			function_data = raw_call.duplicate(true)
			function_data.erase("id")
			function_data.erase("type")
		else:
			continue

		var tool_name := str(function_data.get("name", ""))
		if tool_name.is_empty():
			AIHubPlugin.print_err("llama.cpp returned a tool call with no function name: %s" % str(raw_call))
			continue

		var legacy_function_id := str(function_data.get("id", ""))
		var arguments_dict := _parse_tool_arguments(function_data.get("arguments", {}), tool_name)
		# OpenAI-compatible assistant history expects function arguments as a
		# JSON string. _parse_tool_calls converts it back for Godot tools.
		function_data["arguments"] = JSON.stringify(arguments_dict)
		function_data.erase("id")

		var call_id := str(raw_call.get("id", legacy_function_id))
		if call_id.is_empty():
			call_id = "call_%d_%d" % [Time.get_ticks_msec(), index]

		normalized_calls.append({
			"id": call_id,
			"type": "function",
			"function": function_data
		})

	return normalized_calls


func _parse_tool_calls(tool_calls_payload: Array) -> Array[AIToolCall]:
	var ordered_calls: Array[AIToolCall] = []
	for call_value in tool_calls_payload:
		if not (call_value is Dictionary) or not (call_value.get("function", {}) is Dictionary):
			continue

		var function_data: Dictionary = call_value.function
		var tool_name := str(function_data.get("name", ""))
		if tool_name.is_empty():
			AIHubPlugin.print_err("llama.cpp returned an invalid function call: %s" % str(call_value))
			continue

		var arguments := _parse_tool_arguments(function_data.get("arguments", {}), tool_name)
		var call_id := str(call_value.get("id", function_data.get("id", "")))
		ordered_calls.append(AIToolCall.new(tool_name, arguments, call_id))

	return ordered_calls


func _parse_tool_arguments(arguments_value, tool_name: String) -> Dictionary:
	if arguments_value is Dictionary:
		return arguments_value.duplicate(true)
	if arguments_value is String:
		if arguments_value.is_empty():
			return {}
		var arguments_json := JSON.new()
		var parse_error := arguments_json.parse(arguments_value)
		if parse_error == OK and arguments_json.get_data() is Dictionary:
			return arguments_json.get_data()
		AIHubPlugin.print_err(
			"llama.cpp returned invalid JSON arguments for tool %s: %s" % [tool_name, arguments_value]
		)
	return {}


## Handle a model that emits a JSON-only tool call in content instead of using
## llama-server's structured tool_calls response.
func _try_to_find_tools(content: String) -> Array:
	var candidate := content.strip_edges()
	if candidate.begins_with("<tools>") and candidate.ends_with("</tools>"):
		candidate = candidate.trim_prefix("<tools>").trim_suffix("</tools>").strip_edges()
	if candidate.begins_with("```json") and candidate.ends_with("```"):
		candidate = candidate.trim_prefix("```json").trim_suffix("```").strip_edges()
	if not candidate.begins_with("{") and not candidate.begins_with("["):
		return []

	var tool_json := JSON.new()
	if tool_json.parse(candidate) != OK:
		return []
	var parsed = tool_json.get_data()
	if parsed is Dictionary:
		if parsed.has("function") or parsed.has("name"):
			return _normalize_tool_calls([parsed])
	elif parsed is Array:
		return _normalize_tool_calls(parsed)
	return []


func _read_context_used(response: Dictionary) -> void:
	var timings = response.get("timings", {})
	if timings is Dictionary \
		and timings.has("prompt_n") \
		and timings.has("cache_n") \
		and timings.has("predicted_n"):
		_current_context = int(timings.prompt_n) + int(timings.cache_n) + int(timings.predicted_n)
		return

	var usage = response.get("usage", {})
	if usage is Dictionary:
		if usage.has("total_tokens"):
			_current_context = int(usage.total_tokens)
		elif usage.has("prompt_tokens") and usage.has("completion_tokens"):
			_current_context = int(usage.prompt_tokens) + int(usage.completion_tokens)


func _url_for_model(base_url: String, model_name: String) -> String:
	if model_name.is_empty():
		return base_url
	var separator := "&" if base_url.contains("?") else "?"
	return "%s%smodel=%s" % [base_url, separator, model_name.uri_encode()]


func _parse_json_dictionary(body: PackedByteArray, response_name: String) -> Dictionary:
	var json := JSON.new()
	var parse_error := json.parse(body.get_string_from_utf8())
	if parse_error != OK:
		AIHubPlugin.print_err(
			"Failed to parse llama.cpp %s JSON: %s" % [response_name, json.get_error_message()]
		)
		return {}
	var data = json.get_data()
	if data is Dictionary:
		return data
	AIHubPlugin.print_err("llama.cpp %s was not a JSON object." % response_name)
	return {}
