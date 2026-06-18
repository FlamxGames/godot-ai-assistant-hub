@tool
class_name AIModelInfoFetcher
extends Node

signal _capabilities_read


class ModelsInfoInternalCache:
	var _internal_cache:= {}
	
	
	func add_model_capabilitites(llm_provider:LLMProviderResource, model_name:String, capabilities:Array[LLMInterface.Capabilities]) -> void:
		var model_capabilities_per_api:Dictionary = _internal_cache.get_or_add(llm_provider, {})
		model_capabilities_per_api[model_name] = capabilities
	
	
	func has_model_capabiltities(llm_provider:LLMProviderResource, model_name:String) -> bool:
		return _internal_cache.has(llm_provider) and _internal_cache[llm_provider].has(model_name)
	
	
	func get_model_capabiltities(llm_provider:LLMProviderResource, model_name:String) -> Array[LLMInterface.Capabilities]:
		if _internal_cache.has(llm_provider) and _internal_cache[llm_provider].has(model_name):
			return _internal_cache[llm_provider][model_name]
		else:
			return []


@onready var capabilities_http_request: HTTPRequest = %CapabilitiesHTTPRequest

var _last_model: String
var _last_llm_api: LLMInterface
var _cache:= ModelsInfoInternalCache.new()
var _last_request_succeeded: bool


## Finds the model capabilities and adds them to cache. Returns false only if an error is produced.
func detect_model_capabilities(llm_api:LLMInterface, model:String) -> bool:
	if not _cache.has_model_capabiltities(llm_api.get_llm_provider(), model):
		capabilities_http_request.cancel_request()
		_last_llm_api = llm_api
		_last_model = model
		if llm_api.send_get_capabilities_request(capabilities_http_request, model):
			await _capabilities_read
			return _last_request_succeeded
		else:
			return true #If send_get_capabilities_request returns false it means this LLM API does not support finding capabilities yet
	return true


func get_model_capabilities(llm_api:LLMInterface, model:String) -> Array[LLMInterface.Capabilities]:
	if _cache.has_model_capabiltities(llm_api.get_llm_provider(), model):
		return _cache.get_model_capabiltities(llm_api.get_llm_provider(), model)
	else:
		return []


func _on_capabilities_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == 0 and response_code == 200:
		_last_request_succeeded = true
		var capabilities:= _last_llm_api.read_capabilities_response(body)
		_cache.add_model_capabilitites(_last_llm_api.get_llm_provider(), _last_model, capabilities)
	else:
		_last_request_succeeded = false
		AIHubPlugin.print_err("Error while trying to check model capabilities.
			\n\tResult: %d,\n\tResponse Code: %d,\n\tHeaders: %s,\n\tBody: %s" %
			[result, response_code, headers, body.get_string_from_utf8() if body != null else "null"]
		)
	_capabilities_read.emit()
