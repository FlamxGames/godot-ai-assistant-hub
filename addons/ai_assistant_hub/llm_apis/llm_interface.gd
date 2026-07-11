@tool
class_name LLMInterface
# The intention of this class is to serve as a base class for any LLM API
# to be implemented in this plugin. It is mainly to have a clear definition
# of what properties or functions should be used by other classes.

signal model_changed(model:String)
signal override_temperature_changed(value:bool)
signal temperature_changed(temperature:float)
signal reasoning_changed(reasoning:String)
signal tools_enabled_changed(value:bool)
signal llm_config_changed
signal context_usage_updated(max:int, current:int)

enum Capabilities { Tools, ReasoningLevels }
enum ToolPayloadParts { Name, Description, Parameters, RequiredParams }
enum ParamPayloadParts { Name, Description, Type, Enum }

const AI_TOOL_OPTION_EXTENDED_PROMPT = preload("res://addons/ai_assistant_hub/tools/general_params_and_options/ai_tool_option_extended_prompt.tres")
const TOOL_DEFAULT_ACCESS_PROFILE:AIToolAccessProfile = preload("res://addons/ai_assistant_hub/tools/access_profiles/default_access.tres")
const TOOL_CUSTOM_ACCESS_PATH := "res://addons/ai_assistant_hub/tools/access_profiles/custom_access.tres"
const TOOL_PAYLOAD_KEYWORDS := {
	ToolPayloadParts.Name: "<:NAME:>",
	ToolPayloadParts.Description: "<:DESC:>",
	ToolPayloadParts.Parameters: "<:PARAM:>",
	ToolPayloadParts.RequiredParams: "<:REQP:>"
}
const PARAM_PAYLOAD_KEYWORDS := {
	ParamPayloadParts.Name: "<:NAME:>",
	ParamPayloadParts.Description: "<:DESC:>",
	ParamPayloadParts.Type: "<:TYPE:>",
	ParamPayloadParts.Enum: "<:ENUM:>"
}
const INVALID_RESPONSE := "[INVALID_RESPONSE]"

# Public properties can be modified from the chat tab, you can subscribe to their change events
var model: String:
	set(value):
		_max_context = 0
		context_usage_updated.emit(0,0)
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


var reasoning: String:
	set(value):
		reasoning = value
		reasoning_changed.emit(value)
	get:
		return reasoning


var tools_enabled: bool = false:
	set(value):
		tools_enabled = value
		tools_enabled_changed.emit(value)
	get:
		return tools_enabled


var context_length: int:
	set(value):
		context_length = value
		#context_length.emit(value) #not implemented yet, this can be changed only in the assistant definition
	get:
		return context_length


var _msg_cleaner:= ResponseCleaner.new()

var _base_url:String
var _models_url:String
var _chat_url:String
var _max_context_url:String
var _capabilities_url:String
var _api_key:String
var _llm_provider:LLMProviderResource
var _max_context:int # This is read from the chat responses
var _current_context:int
var _available_tools:Dictionary # tool_id:String, ToolWithAccess (internal class)
var _manual_approval_tool_ids:Array[String]
var _tools_payload:Array
var _tool_undo_queue = AIToolUndoQueue.new()
var _global_tool_option_values:Dictionary

# Capabilitites
var _supports_reasoning_levels:bool
var _supports_tools:bool


class ToolWithAccess:
	var tool_definition:AIToolResource
	var tool_access:AIToolAccess
	func _init(_tool_definition:AIToolResource, _tool_access:AIToolAccess) -> void:
		tool_definition = _tool_definition
		tool_access = _tool_access


func _init(llm_provider:LLMProviderResource) -> void:
	if llm_provider == null:
		AIHubPlugin.print_err("Tried to create LLM instance with no provider.")
		return
	_llm_provider = llm_provider
	load_llm_parameters()
	_initialize()


func get_llm_provider() -> LLMProviderResource:
	return _llm_provider


func load_llm_parameters() -> void:
	var config = LLMConfigManager.new(_llm_provider.api_id)
	if _llm_provider.fix_url.is_empty():
		var custom_url := config.load_url()
		if custom_url.is_empty():
			_base_url = _llm_provider.default_url
		else:
			_base_url = custom_url 
	else:
		_base_url = _llm_provider.fix_url
	_models_url = _base_url + _llm_provider.models_url_postfix
	_chat_url = _base_url + _llm_provider.chat_url_postfix
	_max_context_url = _base_url + _llm_provider.max_context_url_postfix
	_capabilities_url = _base_url + _llm_provider.capabilities_url_postfix
	_api_key = config.load_key()
	llm_config_changed.emit()


func get_full_response(body: PackedByteArray) -> Variant:
	var json := JSON.new()
	var parse_result := json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		AIHubPlugin.print_err("Failed to parse JSON in get_full_response: %s" % json.get_error_message())
		return body.get_string_from_utf8()
	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		return data
	else:
		AIHubPlugin.print_err("Parsed JSON is not a Dictionary in get_full_response.")
		return body.get_string_from_utf8()


func check_context_usage(http_request:HTTPRequest) -> void:
	if _max_context > 0:
		context_usage_updated.emit(_max_context, _current_context)
	else:
		detect_max_context(http_request)


func load_capabilities(model_capabilities: Array[Capabilities], tool_access:AIToolAccessProfile) -> void:
	AIHubPlugin.print_msg("Loading capabilities.")
	_supports_reasoning_levels = false
	_supports_tools = false
	if model_capabilities:
		for capability in model_capabilities:
			match capability:
				Capabilities.ReasoningLevels: _supports_reasoning_levels = true
				Capabilities.Tools: _supports_tools = true
	if _supports_tools:
		_global_tool_option_values = tool_access.get_global_option_values()
		_available_tools.clear()
		_manual_approval_tool_ids.clear()
		for key in tool_access.permissions:
			var tool_definition:AIToolResource = key
			var access:AIToolAccess = tool_access.permissions[key]
			if access.usage_permission != AIToolAccess.Permission.Hide:
				_available_tools[tool_definition.id] = ToolWithAccess.new(tool_definition, access)
				if access.usage_permission == AIToolAccess.Permission.Ask:
					_manual_approval_tool_ids.append(tool_definition.id)
		_tools_payload = _build_tools_payload()


func get_permission_for_tool (tool_id:String) -> AIToolAccess.Permission:
	if _manual_approval_tool_ids.has(tool_id):
		return AIToolAccess.Permission.Ask
	if _available_tools.has(tool_id):
		return AIToolAccess.Permission.Allow
	return AIToolAccess.Permission.Hide


func get_tool_instance (tool_id:String) -> AITool:
	var tool_data:ToolWithAccess = _available_tools.get(tool_id)
	# Combine the global option values with the tool specific option values
	var option_values:= {}
	var tool_opt_values := tool_data.tool_access.option_values
	for option in tool_data.tool_definition.options:
		var option_id := option.id
		var in_global := _global_tool_option_values.has(option_id) and _global_tool_option_values[option_id] != null
		var in_tool := tool_opt_values.has(option_id) and tool_opt_values[option_id] != null
		if in_tool and in_global and (option.type == AIToolOption.OptionType.ArrayOfProjectDir or option.type == AIToolOption.OptionType.ArrayOfProjectFiles):
			var combined_value := []
			combined_value.append_array(tool_opt_values[option_id])
			combined_value.append_array(_global_tool_option_values[option_id])
			option_values[option_id] = combined_value
		elif in_global:
			option_values[option_id] = _global_tool_option_values[option_id]
		elif in_tool:
			option_values[option_id] = tool_opt_values[option_id]
	var tool:AITool = tool_data.tool_definition.create_instance(option_values, _tool_undo_queue)
	if tool:
		return tool
	else:
		AIHubPlugin.print_err("An error ocurred when creating an instance of tool %s." % tool_id)
		return null 


#--- The methods below should be overriden by child classes, see for example OllamaAPI ---

func send_get_models_request(http_request:HTTPRequest) -> bool:
	return false


func read_models_response(body:PackedByteArray) -> Array[String]:
	return [INVALID_RESPONSE]


func send_chat_request(http_request:HTTPRequest, content:Array) -> bool:
	return false


func read_response(body:PackedByteArray) -> AIAssistantResponse:
	return null


func detect_max_context(http_request:HTTPRequest) -> void:
	return


func read_max_context_http_response(body: PackedByteArray) -> void:
	return


func send_get_capabilities_request(http_request:HTTPRequest, model_name:String) -> bool:
	return false


func read_capabilities_response(body: PackedByteArray) -> Array[Capabilities]:
	return []


## This is an optional method to override, only if you need to perform any logic
## after the URL and API key are loaded, e.g. generate custom headers
func _initialize() -> void:
	return


#--- Internal methods available to child classes, you are not expected to override these ---

func _build_tools_payload() -> Array:
	var tool_parts:Array[String]
	for tool_data in _available_tools.values():
		var tool:AITool = tool_data.tool_definition.create_instance(tool_data.tool_access.option_values, _tool_undo_queue)
		if tool == null:
			AIHubPlugin.print_err("An error ocurred when creating an instance of tool %s. Tool skipped from payload." % tool_data.tool_definition.id)
			continue
		var parameters_definition := tool.get_parameters()
		var parameters:Array[String] = []
		var required_parameters:Array[String] = []
		var failed := false
		for parameter in parameters_definition: #Iterates AIToolParameter
			if parameter.required:
				required_parameters.append(parameter.name)
			var parameter_payload := _build_parameter_payload(parameter)
			if parameter_payload.is_empty():
				AIHubPlugin.print_err("Error: Tool %s cannot be used because of an error in parameter %s." % [ tool.get_function_name(), parameter.name ])
				failed = true
				break
			parameters.append(parameter_payload)
		var access: AIToolAccess = tool_data.tool_access
		var tool_description:String
		if access.option_values.has(AI_TOOL_OPTION_EXTENDED_PROMPT.id):
			tool_description = "%s\n\n*Important instructions:*\n%s" % [tool.get_description() , access.option_values[AI_TOOL_OPTION_EXTENDED_PROMPT.id] ]
		else:
			tool_description = tool.get_description()
		if not failed:
			var function_data := {
				TOOL_PAYLOAD_KEYWORDS[ToolPayloadParts.Name]: tool.get_function_name(),
				TOOL_PAYLOAD_KEYWORDS[ToolPayloadParts.Description]: tool_description.json_escape(),
				TOOL_PAYLOAD_KEYWORDS[ToolPayloadParts.Parameters]: ",\n".join(parameters),
				TOOL_PAYLOAD_KEYWORDS[ToolPayloadParts.RequiredParams]: required_parameters
			}
			tool_parts.append(_llm_provider.tool_payload_template.format(function_data))
	var payload_string = "[\n%s\n]" % ",".join(tool_parts)
	var payload = JSON.new()
	var error = payload.parse(payload_string)
	if error == OK:
		return payload.get_data()
	else:
		AIHubPlugin.print_err("JSON payload for tools is invalid. Error: %s at line %d.\nFull payload:\n%s" % [ payload.get_error_message(), payload.get_error_line(), payload_string ])
		return []


func _build_parameter_payload(parameter:AIToolParameter) -> String:
	var type:= _get_parameter_type_payload_name(parameter.type)
	if type.is_empty():
		AIHubPlugin.print_err("Error: Parameter type %s is not supported." % AIToolParameter.ParameterType.find_key(parameter.type))
		return ""
	var param_data := {
		PARAM_PAYLOAD_KEYWORDS[ParamPayloadParts.Name]: parameter.name,
		PARAM_PAYLOAD_KEYWORDS[ParamPayloadParts.Description]: parameter.description.json_escape(),
		PARAM_PAYLOAD_KEYWORDS[ParamPayloadParts.Type]: type
	}
	var parameter_payload_template:= _llm_provider.tool_param_payload_template
	var enum_key := PARAM_PAYLOAD_KEYWORDS[ParamPayloadParts.Enum]
	if parameter.type == AIToolParameter.ParameterType.StringEnum:
		param_data[enum_key] = parameter.string_enum_valid_values
	else:
		parameter_payload_template = _remove_line_with_substring(parameter_payload_template, enum_key)
	return parameter_payload_template.format(param_data)


func _get_parameter_type_payload_name(parameter_type:AIToolParameter.ParameterType) -> String:
	var name:String
	match parameter_type:
		AIToolParameter.ParameterType.Int: name = _llm_provider.tool_param_type_int
		AIToolParameter.ParameterType.Float: name = _llm_provider.tool_param_type_float
		AIToolParameter.ParameterType.Boolean: name = _llm_provider.tool_param_type_boolean
		AIToolParameter.ParameterType.String: name = _llm_provider.tool_param_type_string
		AIToolParameter.ParameterType.Code: name = _llm_provider.tool_param_type_string
		AIToolParameter.ParameterType.StringEnum: name = _llm_provider.tool_param_type_string
		AIToolParameter.ParameterType.Array: name = _llm_provider.tool_param_type_array
	return name


func _remove_line_with_substring(original_text: String, substring: String) -> String:
	var lines = original_text.split("\n")
	var filtered_lines = []
	for line in lines:
		if not line.contains(substring):
			filtered_lines.append(line)
	return "\n".join(filtered_lines)
