@tool
class_name AIChat
extends Control

signal models_loaded
signal save_changed(chat:AIChat, save_on:bool)

enum Caller {
	You,
	Bot,
	System
}

const CHAT_HISTORY_EDITOR = preload("res://addons/ai_assistant_hub/chat_history_editor.tscn")
const SAVE_PATH := "user://ai_assistant_hub/saved_chats/"

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
@onready var bot_cancel: Button = %BotCancel
@onready var save_check_button: CheckButton = %SaveCheckButton
@onready var reasoning_section: HBoxContainer = %ReasoningSection
@onready var reasoning_options_btn: OptionButton = %ReasoningOptionsBtn


var _plugin:AIHubPlugin
var _bot_name: String
var _assistant_settings: AIAssistantResource
var _last_quick_prompt: AIQuickPromptResource
var _code_selector: AssistantToolSelection
var _bot_answer_handler: AIAnswerHandler
var _llm: LLMInterface
var _conversation: AIConversation
var _chat_save_path: String


func initialize(plugin:AIHubPlugin, assistant_settings: AIAssistantResource, bot_name:String) -> void:
	AIHubPlugin.print_msg("Initializing AIChat with %s." % bot_name)
	_plugin = plugin
	_assistant_settings = assistant_settings
	_bot_name = bot_name
	if not is_node_ready():
		await ready
	_code_selector = AssistantToolSelection.new(plugin)
	_bot_answer_handler = AIAnswerHandler.new(plugin, _code_selector)
	_bot_answer_handler.bot_message_produced.connect(func(message): _add_to_chat(message, Caller.Bot) )
	_bot_answer_handler.error_message_produced.connect(func(message): _add_to_chat(message, Caller.System) )
	_set_tab_label()
	
	if _chat_save_path.is_empty():
		var save_id = ("%s_%s_%s" % [Time.get_datetime_string_from_system(), assistant_settings.type_name, bot_name]).validate_filename()
		_chat_save_path = SAVE_PATH + save_id + ".cfg"
		if not DirAccess.dir_exists_absolute(SAVE_PATH):
			AIHubPlugin.print_msg("Creating folder %s" % SAVE_PATH)
			DirAccess.make_dir_absolute(SAVE_PATH)
	
	var llm_provider:= _find_llm_provider()
	if llm_provider == null:
		_add_to_chat("ERROR: No LLM provider found.", Caller.System)
		return
	api_label.text = llm_provider.name
	var new_conversation:= _conversation == null
	if new_conversation:
		_create_conversation(llm_provider)
	
	if _assistant_settings: # We need to check this, otherwise this is called when editing the plugin
		_load_api(llm_provider)
		if llm_provider.reasoning_levels and llm_provider.reasoning_levels.size() > 1:
			AIHubPlugin.print_msg("Loading reasoning levels for API %s." % llm_provider.name)
			reasoning_section.visible = true
			for level in llm_provider.reasoning_levels:
				var parts := level.split("|")
				var reasoning_key = parts[0].strip_edges()
				reasoning_options_btn.add_item(reasoning_key)
				if parts.size() > 1:
					reasoning_options_btn.set_item_tooltip(reasoning_options_btn.item_count - 1, parts[1].strip_edges())
		else:
			AIHubPlugin.print_msg("Reasoning levels are not supported yet for API %s." % llm_provider.name)
			reasoning_section.visible = false
		
		temperature_slider.value = assistant_settings.custom_temperature
		temperature_override_checkbox.button_pressed = assistant_settings.use_custom_temperature
		_on_temperature_override_checkbox_toggled(temperature_override_checkbox.button_pressed)
		
		_conversation.set_system_message("%s\nYour name is %s." % [_assistant_settings.ai_description, _bot_name])
		if new_conversation:
			bot_portrait.set_random()
		bot_portrait.think.connect(func(value:bool): bot_cancel.visible = value)
		reply_sound.pitch_scale = randf_range(0.7, 1.2)
	
		if _assistant_settings.quick_prompts and _assistant_settings.quick_prompts.size() > 0:
			AIHubPlugin.print_msg("Loading quick prompts for %s." % bot_name)
		else:
			AIHubPlugin.print_msg("No quick prompts found for %s." % bot_name)
		for qp in _assistant_settings.quick_prompts:
			var qp_button:= Button.new()
			qp_button.text = qp.action_name
			qp_button.tooltip_text = qp.action_prompt
			qp_button.icon = qp.icon
			qp_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			qp_button.pressed.connect(func(): _on_qp_button_pressed(qp))
			quick_prompts_panel.add_child(qp_button)
		
		_llm.send_get_models_request(models_http_request)
		prompt_txt.text = ""
		prompt_txt.editable = true
		if new_conversation:
			_greet()
		AIHubPlugin.print_msg("Chat initialized for %s." % bot_name)


func get_assistant_settings() -> AIAssistantResource:
	return _assistant_settings


func initialize_from_file(plugin:AIHubPlugin, file:String) -> void:
	_plugin = plugin
	_chat_save_path = file
	if not is_node_ready():
		await ready
	AIHubPlugin.print_msg("Loading chat from %s." % file)
	var config = ConfigFile.new()
	config.load(_chat_save_path)
	var res_path = config.get_value("setup","assistant_res")
	_assistant_settings = load(res_path)
	var bot_name:String = config.get_value("setup","bot_name")
	var system_message:String = config.get_value("setup","system_message")
	var chat_history:Array = config.get_value("chat","entries")
	var llm_provider:= _find_llm_provider()
	if llm_provider == null:
		_add_to_chat("ERROR: No LLM provider found.", Caller.System)
		return
	_create_conversation(llm_provider)
	_conversation.set_system_message(system_message)
	await initialize(plugin, _assistant_settings, bot_name)
	_conversation.overwrite_chat(chat_history)
	_load_conversation_to_chat(chat_history)
	var port_base_region:Rect2 = config.get_value("portrait","base_region")
	var port_mouth_region:Rect2 = config.get_value("portrait","mouth_region")
	var port_eyes_region:Rect2 = config.get_value("portrait","eyes_region")
	bot_portrait.load_regions(port_base_region, port_mouth_region, port_eyes_region)
	save_check_button.button_pressed = true
	AIHubPlugin.print_msg("Completed loading chat from %s." % file)


func _create_save_file() -> void:
	var config = ConfigFile.new()
	config.load(_chat_save_path)
	config.set_value("setup","assistant_res",_assistant_settings.resource_path)
	config.set_value("setup","bot_name",_bot_name)
	config.set_value("setup","system_message", _conversation.get_system_message())
	config.set_value("portrait","base_region",bot_portrait.get_portrait_base_region())
	config.set_value("portrait","mouth_region",bot_portrait.get_portrait_mouth_region())
	config.set_value("portrait","eyes_region",bot_portrait.get_portrait_eyes_region())
	config.set_value("chat","entries", _conversation.clone_chat())
	config.save(_chat_save_path)


func _create_conversation(llm_provider: LLMProviderResource) -> void:
	AIHubPlugin.print_msg("Starting new conversaion using API %s." % llm_provider.name)
	_conversation = AIConversation.new(
		llm_provider.system_role_name,
		llm_provider.user_role_name,
		llm_provider.assistant_role_name
	)
	_conversation.chat_edited.connect(_on_conversation_chat_edited)
	_conversation.chat_appended.connect(_on_conversation_chat_appended)


func _find_llm_provider() -> LLMProviderResource:
	var llm_provider := _assistant_settings.llm_provider
	if llm_provider == null:
		_add_to_chat("Warning: Assistant %s does not have LLM provider. Using the current LLM API selected in the main tab." % _assistant_settings.type_name, Caller.System)
		llm_provider = _plugin.get_current_llm_provider()
	return llm_provider


func _set_tab_label() -> void:
	if _assistant_settings.type_icon == null:
		var tab_type_name = _assistant_settings.type_name
		if tab_type_name.is_empty():
			tab_type_name = _assistant_settings.resource_path.get_file().trim_suffix(".tres")
		name = "[%s] %s" % [tab_type_name, _bot_name]
	else:
		name = "%s" % [_bot_name]


func _load_conversation_to_chat(chat_history:Array) -> void:
	output_window.clear()
	var llm_provider: LLMProviderResource = _assistant_settings.llm_provider
	for entry in chat_history:
		if entry.has("role") and entry.has("content"):
			if entry.role == llm_provider.user_role_name:
				_add_to_chat(entry.content, Caller.You)
			elif entry.role == llm_provider.assistant_role_name:
				_add_to_chat(entry.content, Caller.Bot)
	output_window.scroll_to_line(output_window.get_line_count())


func _load_api(llm_provider:LLMProviderResource) -> void:
	_llm = _plugin.new_llm(llm_provider)
	if _llm:
		_llm.model = _assistant_settings.ai_model
		_llm.override_temperature = _assistant_settings.use_custom_temperature
		_llm.temperature = _assistant_settings.custom_temperature
	else:
		AIHubPlugin.print_err("LLM provider failed to initialize. Check the LLM API configuration for it.")


func _greet() -> void:
	if _assistant_settings.quick_prompts.size() == 0:
		_add_to_chat("This assistant type doesn't have Quick Prompts defined. Add them to the assistant's resource configuration to unlock some additional capabilities, like writing in the code editor.", Caller.System)
	if not ProjectSettings.get_setting(AIHubPlugin.PREF_SKIP_GREETING, false):
		var greet_prompt:= "In one short sentence say hello and introduce yourself by name."
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
		AIHubPlugin.print_err("No LLM provider loaded. Check your Project Settings!")
		_add_to_chat("No language model provider loaded. Check configuration!", Caller.System)
		return
	var success := _llm.send_chat_request(http_request, _conversation.build())
	if not success:
		_add_to_chat("Something went wrong. Review the details in Godot's Output tab.", Caller.System)


func _abandon_request() -> void:
	if ProjectSettings.get_setting(AIHubPlugin.PREF_AUDIO_HINTS, true):
		error_sound.play()
	http_request.cancel_request()
	bot_portrait.is_thinking = false
	_add_to_chat("Abandoned previous request.", Caller.System)
	_conversation.forget_last_prompt()


func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	bot_portrait.is_thinking = false
	AIHubPlugin.print_msg("Chat response received. Response code: %d" % response_code)
	if result == 0:
		var text_answer = _llm.read_response(body)
		if text_answer == LLMInterface.INVALID_RESPONSE:
			if ProjectSettings.get_setting(AIHubPlugin.PREF_AUDIO_HINTS, true):
				error_sound.play()
			AIHubPlugin.print_err("Response: %s" % _llm.get_full_response(body))
			_add_to_chat("An error occurred while processing your last request. Review the details in Godot's Output tab.", Caller.System)
		else:
			if ProjectSettings.get_setting(AIHubPlugin.PREF_AUDIO_HINTS, true):
				reply_sound.play()
			_conversation.add_assistant_response(text_answer)
			_bot_answer_handler.handle(text_answer, _last_quick_prompt)
	else:
		AIHubPlugin.print_msg("Chat HTTP response:\n\tResult: %d,\n\tResponse Code: %d,\n\tHeaders: %s,\n\tBody: %s" %
			[result, response_code, headers, body.get_string_from_utf8() if body != null else "null"]
		)
		if ProjectSettings.get_setting(AIHubPlugin.PREF_AUDIO_HINTS, true):
			error_sound.play()
		_add_to_chat("An error occurred while communicating with the assistant. Review the details in Godot's Output tab.", Caller.System)


func escape_bbcode(bbcode_text):
	return bbcode_text.replace("[", "[lb]")


func _add_to_chat(text:String, caller:Caller) -> void:
	var auto_scroll_to_bottom: bool = ProjectSettings.get_setting(AIHubPlugin.PREF_SCROLL_BOTTOM, false)
	
	# Set auto-scroll based on message sender
	if caller == Caller.You or caller == Caller.System:
		# User and system messages always auto-scroll
		output_window.scroll_following = true
	else:  # Caller.Bot
		# AI replies depend on the auto-scroll switch
		output_window.scroll_following = auto_scroll_to_bottom
	
	# Save current text length to calculate how much new content was added
	var prev_text_length := output_window.text.length()
	
	match caller:
		Caller.You:
			output_window.push_color(Color(0xFFFF00FF))
			output_window.append_text("\n> %s\n" % text)
		Caller.Bot:
			output_window.push_indent(1)
			output_window.push_indent(1)
			output_window.append_text("\n[color=FF770066][b]%s[/b][/color]:\n" % _bot_name)
			output_window.push_indent(1)
			if text.count("```") > 1:
				# Format markup response with code
				var parts:= text.split("```")
				var writing_code := false
				
				for part in parts:
					if writing_code:
						var subparts: = part.split("\n", true, 1)
						output_window.push_color(Color(0x676767FF))
						output_window.append_text("```%s" % escape_bbcode(subparts[0]))
						output_window.push_color(Color(0x33AAFFFF))
						output_window.push_indent(1)
						output_window.push_mono()
						if subparts.size() > 1:
							output_window.append_text("%s" % escape_bbcode(subparts[1]))
						output_window.pop()
						output_window.pop()
						output_window.pop()
						output_window.append_text("```")
						output_window.pop()
					else:
						output_window.append_text(escape_bbcode(part))
					writing_code = !writing_code
				output_window.append_text("\n")
			else:
				# Format bbcode response
				text = text.replace("[code]","[color=33AAFFFF][code]")
				text = text.replace("[/code]","[/code][/color]")
				output_window.append_text("%s\n" % text)
		Caller.System:
			output_window.push_color(Color(0xFF7700FF))
			output_window.append_text("\n[center]%s[/center]\n" % text)
	
	output_window.pop_all()
	
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
			AIHubPlugin.print_err("No models found. Download at least one model and try again.")
		else:
			if models_returned[0] == LLMInterface.INVALID_RESPONSE:
				AIHubPlugin.print_err("Error while trying to get the models list. Response: %s" % _llm.get_full_response(body))
			else:
				_load_models(models_returned)
	else:
		AIHubPlugin.print_msg("(Chat) Models HTTP response:\n\tResult: %d,\n\tResponse Code: %d,\n\tHeaders: %s,\n\tBody: %s" %
			[result, response_code, headers, body.get_string_from_utf8() if body != null else "null"]
		)


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


func _on_reasoning_options_btn_item_selected(index: int) -> void:
	_llm.reasoning = reasoning_options_btn.text


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


func _on_save_check_button_toggled(toggled_on: bool) -> void:
	save_changed.emit(self, toggled_on)
	if toggled_on:
		_create_save_file()
	else:
		DirAccess.remove_absolute(_chat_save_path)


func _on_conversation_chat_edited(chat_history:Array) -> void:
	if save_check_button.button_pressed:
		_create_save_file()
	_load_conversation_to_chat(chat_history)


func _on_conversation_chat_appended(new_entry:Dictionary) -> void:
	if save_check_button.button_pressed:
		var config = ConfigFile.new()
		var load_result := config.load(_chat_save_path)
		if load_result != OK:
			_create_save_file()
		else:
			var current_chat:Array = config.get_value("chat","entries", [])
			current_chat.append(new_entry)
			config.save(_chat_save_path)


func focus_prompt() -> void:
	prompt_txt.grab_focus()
