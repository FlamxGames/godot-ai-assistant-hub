class_name AIAssistantResource
extends Resource

## Name of the assistant type (e.g., "Writer", "Programmer").
@export var type_name: String

## Icon displayed in hub buttons and tabs for this assistant.
@export var type_icon: Texture2D

## The name of the AI model as listed in the available models section.
@export var ai_model: String

## The class of the LLM provider resource for that model, e.g. res://addons/ai_assistant_hub/llm_providers/ollama.tres, if empty it will try to use the API selected in AI Hub tab.
@export var llm_provider: LLMProviderResource

## Used to give the System message to the chat.
## This gives the overall direction on what the assistant should do.
@export_multiline var ai_description: String = "You are a useful Godot AI assistant." 

## Models have a default temperature recommended for most use cases.
## When checking this, the value of the temperature will be dictated by the CustomTemperature property.
@export var use_custom_temperature: bool = false

## The temperature indicates to the models how much they can deviate from the most expected patterns, usually having low temperature returns more precise output, and high temperature more creative output.
## This value is ignored if UseCustomTemperature is false.
@export_range(0.0, 1.0) var custom_temperature := 0.5

## Quick Prompts available for a model are displayed in the chat window as buttons.
## These allow to create prompt templates, as well as read and write to the code editor.
@export var quick_prompts: Array[AIQuickPromptResource]
