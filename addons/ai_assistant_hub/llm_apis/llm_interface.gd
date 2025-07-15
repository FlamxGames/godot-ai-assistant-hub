@tool
class_name LLMInterface
# The intention of this class is to serve as a base class for any LLM API
# to be implemented in this plugin. It is mainly to have a clear definition
# of what properties or functions should be used by other classes.

signal model_changed(model:String)
signal override_temperature_changed(value:bool)
signal temperature_changed(temperature:float)
signal llm_config_changed

const INVALID_RESPONSE := "[INVALID_RESPONSE]"

# Public properties can be modified from the chat tab, you can subscribe to their change events
var model: String:
	set(value):
		model = value
		model_changed.emit(value)
	get:
		return model
		
var override_temperature: bool:
	set(value):
		override_temperature = value
		override_temperature_changed.emit(value)
	get:
		return override_temperature
		
var temperature: float:
	set(value):
		temperature = value
		temperature_changed.emit(value)
	get:
		return temperature

var _base_url:String
var _models_url:String
var _chat_url:String
var _api_key:String
var _llm_provider:LLMProviderResource


func _init(llm_provider:LLMProviderResource) -> void:
	if llm_provider == null:
		push_error("Tried to create LLM instance with no provider.")
		return
	_llm_provider = llm_provider
	load_llm_parameters()
	_initialize()


func load_llm_parameters() -> void:
	var config = LLMConfigManager.new(_llm_provider.api_id)
	if _llm_provider.fix_url.is_empty():
		_base_url = config.load_url()
	else:
		_base_url = _llm_provider.fix_url
	_models_url = _base_url + _llm_provider.models_url_postfix
	_chat_url = _base_url + _llm_provider.chat_url_postfix
	_api_key = config.load_key()
	llm_config_changed.emit()


func get_full_response(body: PackedByteArray) -> Dictionary:
	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		push_error("Failed to parse JSON in get_full_response: %s" % json.get_error_message())
		return {}
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		return data
	else:
		push_error("Parsed JSON is not a Dictionary in get_full_response.")
		return {}


#--- All methods below should be overriden by child classes, see for example OllamaAPI ---

func send_get_models_request(http_request:HTTPRequest) -> bool:
	return false


func read_models_response(body:PackedByteArray) -> Array[String]:
	return [INVALID_RESPONSE]


func send_chat_request(http_request:HTTPRequest, content:Array) -> bool:
	return false


func read_response(body:PackedByteArray) -> String:
	return INVALID_RESPONSE


## This is an optional method to override, only if you need to perform any logic
## after the URL and API key are loaded, e.g. generate custom headers
func _initialize() -> void:
	return


func _model_changed() -> void:
	return


func _override_temperature_changed() -> void:
	return


func _temperature_changed() -> void:
	return
