@tool
class_name N8NWorkflowAPI
extends LLMInterface

const HEADERS := ["Content-Type: application/json"]

# Reference to the AIAssistantResource
var assistant_resource: AIAssistantResource

func _ready() -> void:
	# Ensure session_id is set in assistant_resource
	if assistant_resource and assistant_resource.session_id.is_empty():
		assistant_resource.session_id = _generate_session_id()
		print("Generated sessionId: %s" % assistant_resource.session_id)

func _generate_session_id() -> String:
	var time := str(Time.get_ticks_msec())
	var random := str(randi() % 1000000)
	var unique_id := time + "_" + random
	return unique_id.sha256_text().substr(0, 32)

func send_get_models_request(http_request:HTTPRequest) -> bool:
	var model_names := ["deepseek-r1-0528-qwen3-8b"]
	emit_signal("response_received", JSON.new().stringify({"data": [{"id": "deepseek-r1-0528-qwen3-8b"}]}).to_utf8_buffer())
	return true

func read_models_response(body:PackedByteArray) -> Array[String]:
	var json := JSON.new()
	var error := json.parse(body.get_string_from_utf8())
	if error != OK:
		push_error("Failed to parse models response: %s" % error)
		return [INVALID_RESPONSE]
	var response := json.get_data()
	if response.has("data"):
		var model_names:Array[String] = []
		for entry in response.data:
			model_names.append(entry.id)
		model_names.sort()
		return model_names
	else:
		return [INVALID_RESPONSE]

func send_chat_request(http_request:HTTPRequest, content:Array) -> bool:
	if model.is_empty():
		model = assistant_resource.ai_model if assistant_resource and assistant_resource.ai_model else "deepseek-r1-0528-qwen3-8b"
	
	# Ensure session_id is set
	var session_id = assistant_resource.session_id if assistant_resource and assistant_resource.session_id else _generate_session_id()
	if session_id.is_empty():
		session_id = _generate_session_id()
		if assistant_resource:
			assistant_resource.session_id = session_id
		print("Generated new sessionId: %s" % session_id)
	
	var body_dict := {
		"messages": content,
		"stream": false,
		"model": model,
		"sessionId": session_id
	}
	
	if override_temperature or (assistant_resource and assistant_resource.use_custom_temperature):
		body_dict["temperature"] = assistant_resource.custom_temperature if assistant_resource and assistant_resource.use_custom_temperature else temperature
	
	var body := JSON.new().stringify(body_dict)
	
	var url = _get_chat_url()
	var error = http_request.request(url, HEADERS, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("Something went wrong with last n8n API call.\nURL: %s\nBody:\n%s" % [url, body])
		return false
	return true

func read_response(body) -> String:
	var json := JSON.new()
	var error := json.parse(body.get_string_from_utf8())
	if error != OK:
		push_error("Failed to parse response: %s" % error)
		return INVALID_RESPONSE
	var response := json.get_data()
	
	if response.has("choices") and response.choices.size() > 0:
		var choice = response.choices[0]
		if choice.has("message") and choice.message.has("content"):
			return choice.message.content
		return INVALID_RESPONSE
	else:
		return INVALID_RESPONSE

func _get_chat_url() -> String:
	# return "http://localhost:5678/webhook-test/chat-api"
	return "http://localhost:5678/webhook/chat-api"

func start_new_conversation() -> void:
	if assistant_resource:
		assistant_resource.start_new_conversation()
		print("Started new conversation with sessionId: %s" % assistant_resource.session_id)
	else:
		print("No assistant_resource set; cannot start new conversation")
