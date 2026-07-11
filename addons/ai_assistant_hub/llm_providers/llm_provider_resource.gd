class_name LLMProviderResource
extends Resource

@export var api_id: String ## Identifier of the LLM API.
@export var name: String ## User friendly name, used in the LLM Provider list.
@export var description: String ## Description to be displayed as a tooltip when hovered in the LLM Provider list.
@export var reasoning_levels: Array[String] ## List of reasoning levels accepted by this LLM Provider.
@export var supports_context_size_override:bool ## Set to true once the LLM has the code use the context_length from the assistants

@export_group("API key setup")
@export var requires_key: bool ## Check this if the API requires an API key to work.
@export var get_key_url: String ## If provided a link will be displayed to ease getting the API key.

@export_group("URLs setup")
@export var fix_url: String ## Used for services with a specific URL that won't change from user to user, e.g. Google Gemini. For LLMs that allow local or custom URL, keep this empty, otherwise the URL won't be editable from the UI.
@export var default_url: String ## The usual URL the LLM provider will use unless customized. If the server URL is not entered, this value will be used. This value is ignored when Fix URL is present.
@export var models_url_postfix: String ## Concatenated at the end of the server URL to produce the endpoint to get the models list. E.g. "/api/tags" for Ollama.
@export var chat_url_postfix: String ## Concatenated at the end of the server URL to produce the endpoint to chat. E.g. "/api/chat" for Ollama.
@export var max_context_url_postfix: String ## Concatenated at the end of the server URL to produce the endpoint to find the max context. E.g. "/api/ps" for Ollama.
@export var capabilities_url_postfix: String ## Concatenated at the end of the server URL to produce the endpoint to find the capabilities of a model. E.g. "/api/show" for Ollama.

@export_group("Chat setup")
@export var system_role_name:String = "system" ## Chat role name for system.
@export var user_role_name:String = "user" ## Chat role name for user.
@export var assistant_role_name:String = "assistant" ## Chat role name for assistant.
@export var tool_role_name:String = "tool" ## Chat role name for assistant.

@export_group("Tools setup")
## Expected payload for tools. Supports the following keywords that are replaced automatically:[br][br]
## {<:NAME:>} - The tool function name.[br][br]
## {<:DESC:>} - The tool function description.[br][br]
## {<:PARAM:>} - The tool parameters array, this is build based on property tool_param_payload_template.[br][br]
## {<:REQP:>} - The array that indicates the tool required parameter names.
@export_multiline var tool_payload_template:String
## Expected payload for tool parameters. Supports the following keywords that are replaced automatically:[br][br]
## {<:NAME:>} - The parameter name.[br][br]
## {<:TYPE:>} - The parameter type, which values depend on the properties below tool_param_type_*.[br][br]
## {<:DESC:>} - The parameter description.[br][br]
## {<:ENUM:>} - For enums, the array of accepted values. This line is removed automatically for non-enums, so it is important to consider if the payload will still be valid if removed (for instance, keep an eye on commas).
@export_multiline var tool_param_payload_template:String
@export var tool_param_type_int:String = "integer" ## The expected name of Integer type in the payload. This helps to map to the payload AIToolParameter.ParameterType variables that are part of the tools configuration.
@export var tool_param_type_float:String = "number" ## The expected name of Float type in the payload. This helps to map to the payload AIToolParameter.ParameterType variables that are part of the tools configuration.
@export var tool_param_type_boolean:String = "boolean" ## The expected name of Boolean type in the payload. This helps to map to the payload AIToolParameter.ParameterType variables that are part of the tools configuration.
@export var tool_param_type_string:String = "string" ## The expected name of String type in the payload. This helps to map to the payload AIToolParameter.ParameterType variables that are part of the tools configuration.
@export var tool_param_type_array:String = "array" ## The expected name of Array type in the payload. This helps to map to the payload AIToolParameter.ParameterType variables that are part of the tools configuration.
