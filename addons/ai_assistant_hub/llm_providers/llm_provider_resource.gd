class_name LLMProviderResource
extends Resource

@export var api_id: String ## Identifier of the LLM API.
@export var name: String ## User friendly name, used in the LLM Provider list.
@export var description: String ## Description to be displayed as a tooltip when hovered in the LLM Provider list.

@export_group("API key setup")
@export var requires_key: bool ## Check this if the API requires an API key to work.
@export var get_key_url: String ## If provided a link will be displayed to ease getting the API key.

@export_group("URLs setup")
@export var fix_url: String ## Used for services with a specific URL that won't change from user to user, e.g. Google Gemini. For LLMs that allow local or custom URL, keep this empty, otherwise the URL won't be editable from the UI.
@export var models_url_postfix: String ## Concatenated at the end of the server URL to produce the endpoint to get the models list. E.g. "/api/tags" for Ollama.
@export var chat_url_postfix: String ## Concatenated at the end of the server URL to produce the endpoint to chat. E.g. "/api/chat" for Ollama.

@export_group("Chat setup")
@export var system_role_name:String = "system" # Chat role name for system.
@export var user_role_name:String = "user" # Chat role name for user.
@export var assistant_role_name:String = "assistant" # Chat role name for assistant.
