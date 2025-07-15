@tool
class_name AIChat
extends Control

signal models_loaded

enum Caller {
	You,
	Bot,
	System
}

const CHAT_HISTORY_EDITOR = preload("res://addons/ai_assistant_hub/chat_history_editor.tscn")

@onready var http_request: HTTPRequest = %HTTPRequest
@onready var models_http_request: HTTPRequest = %ModelsHTTPRequest
@onready var output_window: RichTextLabel = %OutputWindow
@onready var prompt_txt: TextEdit = %PromptTxt
@onready var bot_portrait: BotPortrait = %BotPortrait
@onready var quick_prompts_panel: Container = %QuickPromptsPanel
@onready var reply_sound: AudioStreamPlayer = %ReplySound
@onready var error_sound: AudioStreamPlayer = %ErrorSound
@onready var model_options_btn: OptionButton = %ModelOptionsBtn
@onready var temperature_slider: HSlider = %TemperatureSlider
@onready var temperature_override_checkbox: CheckBox = %TemperatureOverrideCheckbox
@onready var temperature_slider_container: HBoxContainer = %TemperatureSliderContainer
@onready var api_label: Label = %APILabel

var _plugin:AIHubPlugin
var _bot_name: String
var _assistant_settings: AIAssistantResource
var _last_quick_prompt: AIQuickPromptResource
var _code_selector: AssistantToolSelection
var _bot_answer_handler: AIAnswerHandler
var _llm: LLMInterface
var _conversation: AIConversation


func initialize(plugin:AIHubPlugin, assistant_settings: AIAssistantResource, bot_name:String) -> void:
	await ready
	_plugin = plugin
	_assistant_settings = assistant_settings
	_bot_name = bot_name
	_code_selector = AssistantToolSelection.new(plugin)
	_bot_answer_handler = AIAnswerHandler.new(plugin, _code_selector)
	_bot_answer_handler.bot_message_produced.connect(func(message): _add_to_chat(message, Caller.Bot) )
	_bot_answer_handler.error_message_produced.connect(func(message): _add_to_chat(message, Caller.System) )
	var llm_provider: LLMProviderResource = assistant_settings.llm_provider
	if llm_provider == null:
		_add_to_chat("Warning: Assistant %s does not have LLM provider. Using the current LLM API selected in the main tab." % assistant_settings.type_name, Caller.System)
		llm_provider = plugin.get_current_llm_provider()
		if llm_provider == null:
			_add_to_chat("ERROR: No LLM provider found.", Caller.System)
			return
	api_label.text = llm_provider.name
	_conversation = AIConversation.new(
		llm_provider.system_role_name,
		llm_provider.user_role_name,
		llm_provider.assistant_role_name
	)
		
	if _assistant_settings: # We need to check this, otherwise this is called when editing the plugin
		_load_api(llm_provider)
		_conversation.set_system_message(_assistant_settings.ai_description)
		
		temperature_slider.value = assistant_settings.custom_temperature
		temperature_override_checkbox.button_pressed = assistant_settings.use_custom_temperature
		_on_temperature_override_checkbox_toggled(temperature_override_checkbox.button_pressed)
		
		bot_portrait.set_random()
		reply_sound.pitch_scale = randf_range(0.7, 1.2)
	
		for qp in _assistant_settings.quick_prompts:
			var qp_button:= Button.new()
			qp_button.text = qp.action_name
			qp_button.icon = qp.icon
			qp_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			qp_button.pressed.connect(func(): _on_qp_button_pressed(qp))
			quick_prompts_panel.add_child(qp_button)
		
		_llm.send_get_models_request(models_http_request)
		await models_loaded
		prompt_txt.text = ""
		prompt_txt.editable = true
		_greet()


func _load_api(llm_provider:LLMProviderResource) -> void:
	_llm = _plugin.new_llm(llm_provider)
	if _llm:
		_llm.model = _assistant_settings.ai_model
		_llm.override_temperature = _assistant_settings.use_custom_temperature
		_llm.temperature = _assistant_settings.custom_temperature
	else:
		push_error("LLM provider failed to initialize. Check the LLM API configuration for it.")


func _greet() -> void:
	if _assistant_settings.quick_prompts.size() == 0:
		_add_to_chat("This assistant type doesn't have Quick Prompts defined. Add them to the assistant's resource configuration to unlock some additional capabilities, like writing in the code editor.", Caller.System)
	
	var greet_prompt := "Give a short greeting including just your name (which is \"%s\") and how can you help in a concise sentence." % _bot_name
	_submit_prompt(greet_prompt)


func _input(event: InputEvent) -> void:
	if prompt_txt.has_focus() and event.is_pressed() and event is InputEventKey:
		var e:InputEventKey = event
		var is_enter_key := e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER
		var shift_pressed := Input.is_physical_key_pressed(KEY_SHIFT)
		if shift_pressed and is_enter_key:
			prompt_txt.insert_text_at_caret("\n")
		else:
			var ctrl_pressed = Input.is_physical_key_pressed(KEY_CTRL)
			if not ctrl_pressed:
				if not prompt_txt.text.is_empty() and is_enter_key:
					if bot_portrait.is_thinking:
						_abandon_request()
					get_viewport().set_input_as_handled()
					var prompt = _engineer_prompt(prompt_txt.text)
					prompt_txt.text = ""
					_add_to_chat(prompt, Caller.You)
					_submit_prompt(prompt)


func _on_qp_button_pressed(qp: AIQuickPromptResource) -> void:
	_last_quick_prompt = qp
	var prompt = qp.action_prompt.replace("{CODE}", _code_selector.get_selection())
	if prompt.contains("{CHAT}"):
		prompt = prompt.replace("{CHAT}", prompt_txt.text)
		prompt_txt.text = ""
	_add_to_chat(prompt, Caller.You)
	_submit_prompt(prompt, qp)


func _find_code_editor() -> TextEdit:
	var script_editor := _plugin.get_editor_interface().get_script_editor().get_current_editor()
	return script_editor.get_base_editor()


func _engineer_prompt(original:String) -> String:
	if original.contains("{CODE}"):
		var curr_code:String = _find_code_editor().get_selected_text()
		var prompt:String = original.replace("{CODE}", curr_code)
		return prompt
	else:
		return original


func _submit_prompt(prompt:String, quick_prompt:AIQuickPromptResource = null) -> void:
	if bot_portrait.is_thinking:
		_abandon_request()
	_last_quick_prompt = quick_prompt
	bot_portrait.is_thinking = true
	_conversation.add_user_prompt(prompt)
	if not _llm:
		push_error("No LLM provider loaded. Check your Project Settings!")
		_add_to_chat("No language model provider loaded. Check configuration!", Caller.System)
		return
	var success := _llm.send_chat_request(http_request, _conversation.build())
	if not success:
		_add_to_chat("Something went wrong. Review the details in Godot's Output tab.", Caller.System)


func _abandon_request() -> void:
	error_sound.play()
	http_request.cancel_request()
	bot_portrait.is_thinking = false
	_add_to_chat("Abandoned previous request.", Caller.System)
	_conversation.forget_last_prompt()


func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	#print("HTTP response: Result: %d, Response Code: %d, Headers: %s, Body: %s" % [result, response_code, headers, body])
	bot_portrait.is_thinking = false
	if result == 0:
		var text_answer = _llm.read_response(body)
		if text_answer == LLMInterface.INVALID_RESPONSE:
			error_sound.play()
			push_error("Response: %s" % _llm.get_full_response(body))
			_add_to_chat("An error occurred while processing your last request. Review the details in Godot's Output tab.", Caller.System)
		else:
			reply_sound.play()
			_conversation.add_assistant_response(text_answer)
			_bot_answer_handler.handle(text_answer, _last_quick_prompt)
	else:
		error_sound.play()
		push_error("HTTP response: Result: %s, Response Code: %d, Headers: %s, Body: %s" % [result, response_code, headers, body])
		_add_to_chat("An error occurred while communicating with the assistant. Review the details in Godot's Output tab.", Caller.System)


func _add_to_chat(text:String, caller:Caller) -> void:
	var auto_scroll_to_bottom: bool = ProjectSettings.get_setting(AIHubPlugin.PREF_SCROLL_BOTTOM, false)
	
	# Set auto-scroll based on message sender
	if caller == Caller.You or caller == Caller.System:
		# User and system messages always auto-scroll
		output_window.scroll_following = true
	else:  # Caller.Bot
		# AI replies depend on the auto-scroll switch
		output_window.scroll_following = auto_scroll_to_bottom
	
	var prefix:String
	var suffix:String
	match caller:
		Caller.You:
			prefix = "\n[color=FFFF00]> "
			suffix = "[/color]\n"
		Caller.Bot:
			prefix = "\n[right][color=777777][b]%s[/b][/color]:\n" % _bot_name
			var code_found := false
			if text.contains("```gdscript"):
				code_found = true
				text = text.replace("```gdscript","[left][color=33AAFF]")
			if text.contains("```glsl"):
				code_found = true
				text = text.replace("```glsl","[left][color=33AAFF]")
			if code_found:
				text = text.replace("```","[/color][/left]")
			suffix = "[/right]\n"
		Caller.System:
			prefix = "\n[center][color=FF7700][ "
			suffix = " ][/color][/center]\n"
	
	# Save current text length to calculate how much new content was added
	var prev_text_length = output_window.text.length()
	
	# Add new content
	output_window.text += "%s%s%s" % [prefix, text, suffix]
	
	# If this is an AI reply and auto-scroll is disabled, scroll one page
	if caller == Caller.Bot and not auto_scroll_to_bottom:
		# Make sure the interface updates first so the scrollbar is properly calculated
		await get_tree().process_frame
		await get_tree().process_frame  # Wait two frames to ensure text and scrollbar are updated
		_scroll_output_by_page()


func _on_models_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == 0:
		var models_returned: Array = _llm.read_models_response(body)
		if models_returned.size() == 0:
			push_error("No models found. Download at least one model and try again.")
		else:
			if models_returned[0] == LLMInterface.INVALID_RESPONSE:
				push_error("Error while trying to get the models list. Response: %s" % _llm.get_full_response(body))
			else:
				_load_models(models_returned)
	else:
		push_error("HTTP response: Result: %s, Response Code: %d, Headers: %s, Body: %s" % [result, response_code, headers, body])


func _load_models(models: Array[String]) -> void:
	model_options_btn.clear()
	var selected_found := false
	for model in models:
		model_options_btn.add_item(model)
		if model == _assistant_settings.ai_model:
			model_options_btn.select(model_options_btn.item_count - 1)
			selected_found = true
	if not selected_found:
		model_options_btn.add_item(_assistant_settings.ai_model)
		model_options_btn.select(model_options_btn.item_count - 1)
	models_loaded.emit()


func _on_edit_history_pressed() -> void:
	var history_editor:ChatHistoryEditor = CHAT_HISTORY_EDITOR.instantiate()
	history_editor.initialize(_conversation)
	add_child(history_editor)
	history_editor.popup()


func _on_temperature_override_checkbox_toggled(toggled_on: bool) -> void:
	temperature_slider_container.visible = toggled_on
	_llm.override_temperature = toggled_on


func _on_model_options_btn_item_selected(index: int) -> void:
	_llm.model = model_options_btn.text


func _on_temperature_slider_value_changed(value: float) -> void:
	_llm.temperature = snappedf(temperature_slider.value, 0.001)


# Scroll the output window by one page
func _scroll_output_by_page() -> void:
	if output_window == null:
		return
	# Get the vertical scrollbar of the output window
	var v_scroll_bar := output_window.get_v_scroll_bar()
	if v_scroll_bar == null:
		return
	# Get the visible height of the output window (one page height)
	var visible_height = output_window.size.y
	# Calculate new position by adding one page height, but don't exceed maximum value
	var new_value = min(v_scroll_bar.value + visible_height, v_scroll_bar.max_value)
	# Set the new scroll position
	v_scroll_bar.value = new_value
