@tool
class_name AIChat
extends Control

signal models_loaded
signal save_changed(chat:AIChat, save_on:bool)
signal assistant_type_modified(assistant_type:AIAssistantResource)

enum Caller {
	System,
	You,
	Bot,
	Thought,
	Tool
}

const AI_TOOLS_ACCESS_WINDOW = preload("res://addons/ai_assistant_hub/tools/ai_tools_access_window.tscn")
const CHAT_HISTORY_EDITOR = preload("res://addons/ai_assistant_hub/chat_history_editor.tscn")
const SAVE_PATH := "user://ai_assistant_hub/saved_chats/"
const COLOR_SICK:Color = 0x89a232ff
const COLOR_NORMAL:Color = 0xc6b7beff

const GD_CTX_TAG := "godot-context"
const GD_CTX_KEY_SCENE := "open_scene"
const GD_CTX_KEY_NODES := "selected_nodes"
const GD_CTX_KEY_SCRIPT := "open_script"
const GD_CTX_KEY_SCRIPT_LENGTH := "script_line_count"
const GD_CTX_KEY_LINE_NUM := "code_line_number"
const GD_CTX_KEY_LINE_CONTENT := "code_line_content"
const GD_CTX_KEY_LINE_SECTION := "code_line_section_selected"
const GD_CTX_KEY_CODE_SELECTION := "code_selected_numbered"
const GD_CTX_KEY_TOOLS_STATUS := "tools_status"

@onready var http_request: HTTPRequest = %HTTPRequest
@onready var models_http_request: HTTPRequest = %ModelsHTTPRequest
@onready var max_context_http_request: HTTPRequest = %MaxContextHTTPRequest
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
@onready var tool_toggle_section: HBoxContainer = %ToolToggleSection
@onready var tools_toggle: CheckButton = %ToolsToggle
@onready var reasoning_section: HBoxContainer = %ReasoningSection
@onready var reasoning_options_btn: OptionButton = %ReasoningOptionsBtn
@onready var context_progress_bar: TextureProgressBar = %ContextProgressBar
@onready var context_warning_icon: TextureRect = %ContextWarningIcon
@onready var regular_chat_input_container: HBoxContainer = %RegularChatInputContainer
@onready var tool_approval_input_container: HBoxContainer = %ToolApprovalInputContainer
@onready var error_loading_model_container: VBoxContainer = %ErrorLoadingModelContainer
@onready var reject_reason_txt: TextEdit = %RejectReasonTxt


var _plugin:AIHubPlugin
var _bot_name: String
var _assistant_settings: AIAssistantResource
var _last_quick_prompt: AIQuickPromptResource
var _code_selector: AssistantToolSelection
var _bot_answer_handler: AIAnswerHandler
var _llm: LLMInterface
var _conversation: AIConversation
var _chat_save_path: String
var _model_capabilities: Array[LLMInterface.Capabilities]
var _models_info:AIModelInfoFetcher
var _tool_call_queue:Array[AIToolCall]
var _tool_pending_approval:AITool
var _has_tools_capability:bool
var _last_prompt_sent:String
var _in_tool_approval_mode:bool


func initialize(plugin:AIHubPlugin, assistant_settings: AIAssistantResource, bot_name:String, models_info:AIModelInfoFetcher) -> void:
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
	_models_info = models_info
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
	var is_new_conversation:= _conversation == null
	if is_new_conversation:
		_create_conversation(llm_provider)
	
	if _assistant_settings: # We need to check this, otherwise this is called when editing the plugin
		AIHubPlugin.print_msg("Loading LLM API %s" % llm_provider.name)
		_load_api(llm_provider)
		
		if is_new_conversation:
			bot_portrait.set_random()
		bot_portrait.think.connect(func(value:bool): bot_cancel.visible = value)
		reply_sound.pitch_scale = randf_range(0.7, 1.2)
		
		_on_temperature_override_checkbox_toggled(temperature_override_checkbox.button_pressed)
		
		load_assistant_type_resource(is_new_conversation)


func get_assistant_settings() -> AIAssistantResource:
	return _assistant_settings


# This is called on load, when the assistant type is modified, and when switching models
func load_assistant_type_resource(is_new_chat:bool) -> void:
	temperature_slider.value = _assistant_settings.custom_temperature
	temperature_override_checkbox.button_pressed = _assistant_settings.use_custom_temperature
	
	if _assistant_settings.quick_prompts and _assistant_settings.quick_prompts.size() > 0:
		AIHubPlugin.print_msg("Loading quick prompts for %s." % _bot_name)
	else:
		AIHubPlugin.print_msg("No quick prompts found for %s." % _bot_name)
	
	for qp_btn in quick_prompts_panel.get_children():
		quick_prompts_panel.remove_child(qp_btn)
	for qp in _assistant_settings.quick_prompts:
		var qp_button:= Button.new()
		qp_button.text = qp.action_name
		qp_button.tooltip_text = qp.action_prompt
		qp_button.icon = qp.icon
		qp_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qp_button.pressed.connect(func(): _on_qp_button_pressed(qp))
		quick_prompts_panel.add_child(qp_button)
	await _load_capabilities()
	_set_system_prompt()
	if not error_loading_model_container.visible:
		_llm.send_get_models_request(models_http_request)
		prompt_txt.text = ""
		prompt_txt.editable = true
		if is_new_chat:
			_greet()
		AIHubPlugin.print_msg("Assistant type loaded for %s." % _bot_name)
	else:
		AIHubPlugin.print_msg("Assistant type not fully loaded for %s." % _bot_name)


func _set_system_prompt() -> void:
	var settings = EditorInterface.get_editor_settings()
	var indent_type:String
	if settings.get_setting("text_editor/behavior/indent/type") == 0:
		indent_type = "Tabs"
	else:
		var indent_size = settings.get_setting("text_editor/behavior/indent/size")
		indent_type = "%d spaces" % indent_size
	var godot_version: Dictionary = Engine.get_version_info()
	var sys_msg:="""You are {bot_name}, an AI assistant accessed via the AI Assistant Hub plugin in Godot.
- Engine: Godot {godot_version}
- Programming language: GDScript
- Code indentation type: {indent_type}
- If the user asks about the plugin usage, direct them to https://github.com/FlamxGames/godot-ai-assistant-hub.""".format({
			bot_name = _bot_name,
			godot_version = godot_version.string,
			indent_type = indent_type
		})
	if _has_tools_capability:
		if tools_toggle.button_pressed:
			sys_msg += """
- The `<{gd_ctx}>` tag is used by the plugin to keep you informed about Godot’s current state. It can contain the following:
	- {scene}: The current scene open in Godot.
	- {nodes}: The node(s) currently selected in the editor.
	- {script}: The script currently open in Godot's code editor.
	- {script_line_count}: The amount of lines in the current script.
	- {line_num}: The line number where the cursor is located when no lines are selected, or a single line is selected.
	- {line_content}: The content of the line where the cursor is located when no lines are selected, or a single line is selected.
	- {line_section}: The selected section of a line's content when no lines are selected, or a single line is selected.
	- {code_selection}: The code from multiple selected lines in the Godot editor, each prefixed with its respective line number.
	- {tools_status}: Tells you if the user has enabled or disabled the tools usage.
- When tools display code they prefix each line with `<line number>|`. The real code has no leading pipes, so don’t include them when writing code.
- The `<{gd_ctx}>` information does NOT indicate a user prompt, you should use it only to understand the current state of Godot in order to use tools properly.
	Examples:
		1. The user asks to open a file, you can use this context to tell if the file is already open.
		2. The user asks you about "this code", you can assume the user means the code currently selected.
- Your available tools could vary through the conversation.
- Never try to use tools not listed as available in the last request.
- If you lack a tool for a requested action, state that and suggest an alternative.""".format({
				gd_ctx = GD_CTX_TAG,
				scene = GD_CTX_KEY_SCENE,
				nodes = GD_CTX_KEY_NODES,
				script = GD_CTX_KEY_SCRIPT,
				script_line_count = GD_CTX_KEY_SCRIPT_LENGTH,
				line_num = GD_CTX_KEY_LINE_NUM,
				line_content = GD_CTX_KEY_LINE_CONTENT,
				line_section = GD_CTX_KEY_LINE_SECTION,
				code_selection = GD_CTX_KEY_CODE_SELECTION,
				tools_status = GD_CTX_KEY_TOOLS_STATUS
			})
	else:
		sys_msg += """
- The user can configure Quick Prompts to allow you to read and write code to the editor. You don't have the information about how to do this. If asked about it, direct the user to learn more on https://github.com/FlamxGames/godot-ai-assistant-hub
- You must mark code starting with "```gdscript" and ending with "```" for the plugin to use it.
- You don't have other means to edit the project. To change this, the user could swap to a different LLM model with tools support without leaving this conversation."""
	sys_msg += "\n\nIMPORTANT: Next is the user-provided system prompt, it takes precedence over everything above:\n---\n%s\n---" % _assistant_settings.ai_description
	_conversation.set_system_message(sys_msg)


func initialize_from_file(plugin:AIHubPlugin, file:String, models_info:AIModelInfoFetcher) -> void:
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
	#_conversation.set_system_message(system_message)
	await initialize(plugin, _assistant_settings, bot_name, models_info)
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
		llm_provider.assistant_role_name,
		llm_provider.tool_role_name
	)
	_conversation.chat_edited.connect(_on_conversation_chat_edited)
	_conversation.chat_appended.connect(_on_conversation_chat_appended)


func _find_llm_provider() -> LLMProviderResource:
	var llm_provider := _assistant_settings.llm_provider
	if llm_provider == null:
		_add_to_chat("Warning: Assistant %s does not have LLM provider. Using the current LLM API selected in the main tab." % _assistant_settings.type_name, Caller.System)
		llm_provider = _plugin.get_current_llm_provider()
	return llm_provider


func _load_capabilities() -> void:
	var llm_provider := _assistant_settings.llm_provider
	tool_toggle_section.visible = false
	reasoning_section.visible = false
	var can_read_capabilities := await _models_info.detect_model_capabilities(_llm, _llm.model)
	if can_read_capabilities:
		_model_capabilities = _models_info.get_model_capabilities(_llm, _llm.model)
		var custom_base_profile:AIToolAccessProfile
		if ResourceLoader.exists(LLMInterface.TOOL_CUSTOM_ACCESS_PATH):
			custom_base_profile = load(LLMInterface.TOOL_CUSTOM_ACCESS_PATH)
		var tool_access:= AIToolAccessProfile.create_from_profiles_in_order([
			LLMInterface.TOOL_DEFAULT_ACCESS_PROFILE,
			custom_base_profile,
			_assistant_settings.tool_access
		])
		_llm.load_capabilities(_model_capabilities, tool_access)
		for c in _model_capabilities:
			match c:
				LLMInterface.Capabilities.Tools:
					if not llm_provider.tool_param_payload_template.is_empty():
						tool_toggle_section.visible = true
						tools_toggle.button_pressed = false
						_has_tools_capability = true
					else:
						AIHubPlugin.print_msg("Tools are not supported yet for API %s." % llm_provider.name)
				LLMInterface.Capabilities.ReasoningLevels:
					if llm_provider.reasoning_levels and llm_provider.reasoning_levels.size() > 1:
						reasoning_section.visible = true
						AIHubPlugin.print_msg("Loading reasoning levels for API %s." % llm_provider.name)
						reasoning_options_btn.clear()
						for level in llm_provider.reasoning_levels:
							var parts := level.split("|")
							var reasoning_key = parts[0].strip_edges()
							reasoning_options_btn.add_item(reasoning_key)
							if parts.size() > 1:
								reasoning_options_btn.set_item_tooltip(reasoning_options_btn.item_count - 1, parts[1].strip_edges())
					else:
						AIHubPlugin.print_msg("Reasoning levels are not supported yet for API %s." % llm_provider.name)
		if reasoning_options_btn.item_count > 0:
			_on_reasoning_options_btn_item_selected(0)
		else:
			_llm.reasoning = ""
		
		if _in_tool_approval_mode:
			tool_approval_input_container.visible = true
		else:
			regular_chat_input_container.visible = true
		error_loading_model_container.visible = false
	else:
		regular_chat_input_container.visible = false
		tool_approval_input_container.visible = false
		error_loading_model_container.visible = true


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
	var context_cleaner_regex = RegEx.new()
	# (?s) enables "dotall" mode where . matches newlines
	context_cleaner_regex.compile("(?s)<{ctx_tag}>.*?</{ctx_tag}>".format({ctx_tag = GD_CTX_TAG}))
	for entry in chat_history:
		if entry.has("role") and entry.has("content"):
			if entry.role == llm_provider.user_role_name:
				var content:String = context_cleaner_regex.sub(entry.content, "").strip_edges()
				_add_to_chat(content, Caller.You)
			elif entry.role == llm_provider.assistant_role_name:
				_add_to_chat(entry.content, Caller.Bot)
			elif entry.role == llm_provider.tool_role_name:
				_add_to_chat(entry.content, Caller.Tool)
	output_window.scroll_to_line(output_window.get_line_count())


func _load_api(llm_provider:LLMProviderResource) -> void:
	_llm = _plugin.new_llm(llm_provider)
	if _llm:
		_llm.context_usage_updated.connect(_refresh_context_usage)
		_llm.model = _assistant_settings.ai_model
		_llm.override_temperature = _assistant_settings.use_custom_temperature
		_llm.temperature = _assistant_settings.custom_temperature
		_llm.context_length = _assistant_settings.context_length
	else:
		AIHubPlugin.print_err("LLM provider failed to initialize. Check the LLM API configuration for it.")


func _refresh_context_usage(max:int, current:int) -> void:
	if max > 0:
		context_progress_bar.visible = true
		context_progress_bar.value = int((float(current) / max) * 100)
		context_progress_bar.tooltip_text = "Context used %d%% (%d/%d)" % [context_progress_bar.value, current, max]
		var estimated_tokens = _conversation.get_estimated_token_size()
		var estimated_current_ratio := float(estimated_tokens) / current
		AIHubPlugin.print_msg("Estimated context tokens %d. Ratio to real: %f" % [estimated_tokens, estimated_current_ratio])
		var warn:bool = current >= max or (estimated_current_ratio >= 1.5 and estimated_tokens > max * 0.8)
		context_warning_icon.visible = warn
		context_progress_bar.tint_progress = COLOR_SICK if warn else COLOR_NORMAL
	else:
		context_progress_bar.visible = false


func _greet() -> void:
	if _assistant_settings.quick_prompts.size() == 0 and not _model_capabilities.has(LLMInterface.Capabilities.Tools):
		var llm_provider := _assistant_settings.llm_provider
		if not llm_provider.tool_param_payload_template.is_empty():
			_add_to_chat("IMPORTANT: The selected model (%s) does not support tool calling. Consider switching to a different model, or configure Quick Prompts with \"legacy response options\" + {CODE} + {CHAT} to enable the assistant to read and write code. Check the plugin’s GitHub page for more information." % _llm.model, Caller.System)
		else:
			_add_to_chat("IMPORTANT: This plugin does not yet support tools for the LLM provider you are using (%s). You could still get the assistant to read and write code by using Quick Prompts \"legacy response options\" + {CODE} + {CHAT}. Check the plugin's GitHub page for more information." % _llm.get_llm_provider().name, Caller.System)
	if not ProjectSettings.get_setting(AIHubPlugin.PREF_SKIP_GREETING, false):
		var greet_prompt:= "In one short sentence say hello and introduce yourself by name."
		_submit_prompt(greet_prompt)


func _input(event: InputEvent) -> void:
	if (prompt_txt.has_focus() or reject_reason_txt.has_focus()) and event.is_pressed() and event is InputEventKey:
		var e:InputEventKey = event
		var is_enter_key := e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER
		var shift_pressed := Input.is_physical_key_pressed(KEY_SHIFT)
		if shift_pressed and is_enter_key:
			if prompt_txt.has_focus():
				prompt_txt.insert_text_at_caret("\n")
			elif reject_reason_txt.has_focus():
				reject_reason_txt.insert_text_at_caret("\n")
		else:
			var ctrl_pressed = Input.is_physical_key_pressed(KEY_CTRL)
			if not ctrl_pressed:
				if is_enter_key:
					if prompt_txt.has_focus() and not prompt_txt.text.is_empty():
						if bot_portrait.is_thinking:
							_abandon_request()
						get_viewport().set_input_as_handled()
						var prompt = prompt_txt.text
						if prompt.contains("{CODE}"):
							var curr_code:String = _find_code_editor().get_selected_text()
							prompt = prompt.replace("{CODE}", curr_code)
						var engineered_prompt:String
						if tools_toggle.button_pressed:
							engineered_prompt = _engineer_prompt(prompt) #only send context when using tools
						else:
							engineered_prompt = prompt
						prompt_txt.text = ""
						_last_prompt_sent = prompt
						_add_to_chat(prompt, Caller.You)
						_submit_prompt(engineered_prompt)
					if reject_reason_txt.has_focus() and not reject_reason_txt.text.is_empty():
						_on_tool_reject_btn_pressed()
		if e.keycode == KEY_UP and prompt_txt.text.is_empty():
			prompt_txt.text = _last_prompt_sent


func _on_qp_button_pressed(qp: AIQuickPromptResource) -> void:
	_last_quick_prompt = qp
	_last_prompt_sent = prompt_txt.text
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
	var godot_context := {}
	var scene_root:= EditorInterface.get_edited_scene_root()
	if scene_root:
		godot_context[GD_CTX_KEY_SCENE] = scene_root.scene_file_path
		var selection := EditorInterface.get_selection()
		if selection and selection.get_selected_nodes().size() > 0:
			var nodes_selected := PackedStringArray()
			for node in selection.get_selected_nodes():
				nodes_selected.append(scene_root.get_path_to(node))
			godot_context[GD_CTX_KEY_NODES] = nodes_selected
	var code_editor_file = AIToolFileUtils.get_current_script_editor_file_path()
	if not code_editor_file.is_empty():
		godot_context[GD_CTX_KEY_SCRIPT] = code_editor_file
		var script_editor:= _plugin.get_editor_interface().get_script_editor()
		var code_editor:TextEdit = script_editor.get_current_editor().get_base_editor()
		godot_context[GD_CTX_KEY_SCRIPT_LENGTH] = code_editor.get_line_count()
		
		var start_selected_line_num := code_editor.get_selection_from_line()
		var end_selected_line_num := code_editor.get_selection_to_line()
		if start_selected_line_num >= end_selected_line_num:
			var selected_code := code_editor.get_selected_text()
			var line_of_code := code_editor.get_line(code_editor.get_caret_line())
			godot_context[GD_CTX_KEY_LINE_NUM] = start_selected_line_num + 1
			godot_context[GD_CTX_KEY_LINE_CONTENT] = line_of_code
			if not selected_code.is_empty():
				godot_context[GD_CTX_KEY_LINE_SECTION] = selected_code
		else:
			var numbered_selection:= PackedStringArray()
			var lines_count := end_selected_line_num - start_selected_line_num + 1
			for line_num in range(start_selected_line_num, end_selected_line_num + 1):
				numbered_selection.append("%d\t\t|%s" % [ line_num + 1, code_editor.get_line(line_num) ])
			godot_context[GD_CTX_KEY_CODE_SELECTION] = numbered_selection
	else:
		godot_context[GD_CTX_KEY_SCRIPT] = "No script open."
	godot_context[GD_CTX_KEY_TOOLS_STATUS] = "Enabled" if _llm.tools_enabled else "Disabled"
	
	var prompt:= "<{ctx_tag}>\n{context}\n</{ctx_tag}>\n\n{prompt}".format({
			ctx_tag = GD_CTX_TAG,
			context = JSON.stringify(godot_context),
			prompt = original
		})
	return prompt


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


func _send_tool_feedback(feedback:String) -> void:
	if bot_portrait.is_thinking:
		_abandon_request()
	bot_portrait.is_thinking = true
	_conversation.add_tool_feedback(feedback)
	var success := _llm.send_chat_request(http_request, _conversation.build())
	if not success:
		_add_to_chat("Something went wrong. Review the details in Godot's Output tab.", Caller.System)


func _abandon_request() -> void:
	if ProjectSettings.get_setting(AIHubPlugin.PREF_AUDIO_HINTS, true):
		error_sound.play()
	http_request.cancel_request()
	bot_portrait.is_thinking = false
	_add_to_chat("Abandoned previous request.", Caller.System)
	#_conversation.forget_last_prompt()
	#prompt_txt.text = _last_prompt_sent


func _handle_thinking(thought:String) -> void:
	var think_target:AIHubPlugin.ThinkingTargets = ProjectSettings.get_setting(AIHubPlugin.PREF_REMOVE_THINK, AIHubPlugin.ThinkingTargets.Output)
	match think_target:
		AIHubPlugin.ThinkingTargets.Chat:
			_add_to_chat(thought, Caller.Thought)
		AIHubPlugin.ThinkingTargets.Output:
			print("[Think start]:\n%s\n[Think end]" % thought)


func _queue_tools(tool_calls:Array[AIToolCall]) -> void:
	AIHubPlugin.print_msg("Queued %d tool call(s)." % tool_calls.size())
	_tool_call_queue = tool_calls
	if not _tool_call_queue.is_empty():
		_read_next_tool_call()


func _read_next_tool_call() -> void:
	var tool_call:AIToolCall = _tool_call_queue[0]
	if _llm.tools_enabled:
		AIHubPlugin.print_msg("Reading call for tool: %s." % tool_call.tool_id)
		var permission := _llm.get_permission_for_tool(tool_call.tool_id)
		AIHubPlugin.print_msg("Tool permission is %s." % AIToolAccess.Permission.find_key(permission))
		
		if permission == AIToolAccess.Permission.Hide:
			AIHubPlugin.print_err("The assistant tried to use an invalid or hidden tool: %s " % tool_call.tool_id)
			_notify_tool_error(tool_call, "The selected tool does not exist or is not available.")
			return
		
		var tool:AITool = _llm.get_tool_instance(tool_call.tool_id)
		if tool:
			var message:String
			var tool_parameters:= tool.get_parameters()
			var param_errors:Array[String] = []
			if tool_call.parameters and tool_call.parameters.size() > 0:
				param_errors = tool.read_parameters(tool_call.parameters)
			if param_errors.is_empty():
				message = "Using tool: [b][color=AAFFAAFF]%s[/color][/b]\nTool code: %s" % [ tool.get_title(), tool.get_function_name() ]
				if tool_parameters and not tool_parameters.is_empty():
					message += "\n\tParameters:"
					for param in tool_parameters:
						if tool_call.parameters.has(param.name):
							if param.type == AIToolParameter.ParameterType.Code:
								message += "\n\t\t–> %s:\n----------------------\n%s\n----------------------" % [param.name, str(tool_call.parameters[param.name])]
							else:
								message += "\n\t\t–> %s: %s" % [param.name, str(tool_call.parameters[param.name])]
						else:
							message += "\n\t\t–> %s: (Default)" % param.name
				if permission != AIToolAccess.Permission.Allow:
					_tool_pending_approval = tool
					_set_approval_mode(true)
					_add_to_chat(message, Caller.Tool)
				else:
					_add_to_chat(message, Caller.Tool)
					_execute_tool(tool)
			else:
				message = "Invalid parameter values for tool %s:" % tool.get_title()
				for error in param_errors:
					message += "\n- %s" % error
				_notify_tool_error(tool_call, message)
		else:
			AIHubPlugin.print_err("Tool %s not found " % tool_call.tool_id)
	else:
		_notify_tool_error(tool_call, "All tools are disabled right now.")


func _set_approval_mode(value:bool) -> void:
	_in_tool_approval_mode = value
	reject_reason_txt.text = ""
	regular_chat_input_container.visible = not value
	tool_approval_input_container.visible = value


func _execute_tool(tool:AITool) -> void:
	var call:AIToolCall = _tool_call_queue.pop_front()
	AIHubPlugin.print_msg("Executing tool %s." % tool.get_function_name())
	var success:bool = await tool.execute()
	if success and tool.get_errors().size() == 0:
		_add_to_chat("Tool %s executed." % tool.get_function_name(), Caller.Tool)
		_send_tool_feedback(tool.get_success_message())
	else:
		_notify_tool_error(call, "Tool %s execution errors:\n%s" % [ tool.get_function_name(), "\n".join(tool.get_errors())] )		


func _notify_tool_error(call:AIToolCall, error_message:String) -> void:
	_add_to_chat("Sending tool feedback to the assistant.", Caller.Tool)
	_tool_call_queue.clear()
	if not call.call_id.is_empty():
		error_message += "\nTool call ID: %s" % call.call_id
	_send_tool_feedback(error_message)


func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	bot_portrait.is_thinking = false
	AIHubPlugin.print_msg("Chat response received. Response code: %d" % response_code)
	if result == 0 and response_code == 200:
		var answer := _llm.read_response(body)
		if answer:
			if not answer.thought.is_empty():
				_handle_thinking(answer.thought)
			var text_answer := answer.text_content
			_conversation.add_assistant_response(answer)
			if not text_answer.is_empty():
				if ProjectSettings.get_setting(AIHubPlugin.PREF_AUDIO_HINTS, true):
					reply_sound.play()
				_bot_answer_handler.handle(text_answer, _last_quick_prompt)
			if answer.tool_calls and answer.tool_calls.size() > 0:
				_queue_tools(answer.tool_calls)
			_llm.check_context_usage(max_context_http_request)
		else:
			if ProjectSettings.get_setting(AIHubPlugin.PREF_AUDIO_HINTS, true):
				error_sound.play()
			AIHubPlugin.print_err("Response: %s" % _llm.get_full_response(body))
			_add_to_chat("An error occurred while processing your last request. Review the details in Godot's Output tab.", Caller.System)
	else:
		AIHubPlugin.print_err("Chat HTTP response:\n\tResult: %d,\n\tResponse Code: %d,\n\tHeaders: %s,\n\tBody: %s" %
			[result, response_code, headers, body.get_string_from_utf8() if body != null else "null"]
		)
		if ProjectSettings.get_setting(AIHubPlugin.PREF_AUDIO_HINTS, true):
			error_sound.play()
		if response_code == 500:
			_add_to_chat("An error occurred at the LLM provider level. Trying again may work.", Caller.System)
		else:
			_add_to_chat("An error occurred while communicating with the assistant. Review the details in Godot's Output tab.", Caller.System)


func escape_bbcode(bbcode_text):
	return bbcode_text.replace("[", "[lb]")


func _add_to_chat(text:String, caller:Caller) -> void:
	var v_scroll_bar := output_window.get_v_scroll_bar()
	v_scroll_bar.value = v_scroll_bar.max_value
	
	match caller:
		Caller.System:
			output_window.push_color(Color(0xFF7700FF))
			output_window.append_text("\n[center]%s[/center]\n" % text)
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
		Caller.Thought:
			output_window.push_indent(1)
			output_window.push_indent(1)
			output_window.push_color(Color(0x888888FF))
			output_window.append_text("\n[b][Think start][/b]\n")
			output_window.push_indent(1)
			output_window.append_text(text)
			output_window.pop()
			output_window.append_text("\n[b][Think end][/b]")
			output_window.pop()
			output_window.pop()
			output_window.pop()
		Caller.Tool:
			output_window.push_indent(1)
			output_window.push_indent(1)
			if _in_tool_approval_mode:
				output_window.push_color(Color(0xCC8888FF))
			else:
				output_window.push_color(Color(0x88CC88FF))
			output_window.append_text("\n[b][Tools start][/b]\n")
			output_window.push_indent(1)
			output_window.append_text(text)
			output_window.pop()
			output_window.append_text("\n[b][Tools end][/b]\n")
			output_window.pop()
			output_window.pop()
			output_window.pop()
	output_window.pop_all()
	
	var auto_scroll_to_bottom: bool = ProjectSettings.get_setting(AIHubPlugin.PREF_SCROLL_BOTTOM, false)
	
	await get_tree().process_frame
	await get_tree().process_frame  # Wait two frames to ensure text and scrollbar are updated
	if caller == Caller.You or caller == Caller.System or auto_scroll_to_bottom:
		v_scroll_bar.value = v_scroll_bar.max_value
	else:
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
		AIHubPlugin.print_err("(Chat) Models HTTP response:\n\tResult: %d,\n\tResponse Code: %d,\n\tHeaders: %s,\n\tBody: %s" %
			[result, response_code, headers, body.get_string_from_utf8() if body != null else "null"]
		)


func _load_models(models: Array[String]) -> void:
	model_options_btn.clear()
	var selected_found := false
	for model in models:
		model_options_btn.add_item(model)
		if model == _llm.model:
			model_options_btn.select(model_options_btn.item_count - 1)
			selected_found = true
	if not selected_found:
		model_options_btn.add_item(_llm.model)
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
	load_assistant_type_resource(false)


func _on_temperature_slider_value_changed(value: float) -> void:
	_llm.temperature = snappedf(temperature_slider.value, 0.001)


func _on_reasoning_options_btn_item_selected(index: int) -> void:
	_llm.reasoning = reasoning_options_btn.text


func _on_tools_toggle_toggled(toggled_on: bool) -> void:
	_llm.tools_enabled = toggled_on
	_set_system_prompt()


func _scroll_output_by_page() -> void:
	var v_scroll_bar := output_window.get_v_scroll_bar()
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


func _on_max_context_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == 0 and response_code == 200:
		_llm.read_max_context_http_response(body)
	else:
		AIHubPlugin.print_err("(Chat) Max context HTTP response:\n\tResult: %d,\n\tResponse Code: %d,\n\tHeaders: %s,\n\tBody: %s" %
			[result, response_code, headers, body.get_string_from_utf8() if body != null else "null"]
		)


func _on_tool_approve_btn_pressed() -> void:
	_add_to_chat("Approved", Caller.You)
	var tool_to_execute := _tool_pending_approval
	_tool_pending_approval = null
	_execute_tool(tool_to_execute)
	_set_approval_mode(false)


func _on_tool_reject_btn_pressed() -> void:
	_add_to_chat("Rejected", Caller.You)
	var reject_message := "The user rejected the tool execution. "
	if not reject_reason_txt.text.is_empty():
		reject_message += "User feedback:\n%s" % reject_reason_txt.text
	_notify_tool_error(_tool_call_queue[0], reject_message)
	_set_approval_mode(false)


func _on_retry_read_model_btn_pressed() -> void:
	load_assistant_type_resource(output_window.get_parsed_text().is_empty())


func _on_tool_cancel_btn_pressed() -> void:
	_tool_call_queue.clear()
	_conversation.add_tool_feedback("The user cancelled the execution.")
	var fake_assistant_response:= AIAssistantResponse.new()
	fake_assistant_response.text_content = ""
	_conversation.add_assistant_response(fake_assistant_response)
	prompt_txt.text = _last_prompt_sent
	_set_approval_mode(false)
