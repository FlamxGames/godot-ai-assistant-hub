class_name AIQuickPromptResource
extends Resource

enum ResponseTarget { Chat, CodeEditor, OnlyCodeToCodeEditor }
enum CodePlacement { BeforeSelection, AfterSelection, ReplaceSelection }

## This name will be used in the Quick Prompt button.
## Leave it blank for an icon-only display.
@export var action_name: String

## Tell the assistant what you want it to do.
## Use `{CODE}` to insert the code currently selected in the editor.
## Use `{CHAT}` to include the current content of the text prompt.
@export_multiline var action_prompt: String

## Optional icon for the button displayed in the chat window for this Quick Prompt.
@export var icon: Texture2D

## Is set to true, when this Quick Prompt is used the assistant will only be able to access the tools set in tool_access.
@export var limit_tool_access:bool

## The custom tool access for this prompt. When limit_tool_access is set to true, tools not listed here will not be available for the assistant when using this Quick Prompt.
@export var tool_access:AIToolAccessProfile

## Indicates if the answer should be written in the chat or in the code editor.
@export var response_target: ResponseTarget

## Indicates in what part of the Code Editor you want to put the answer (ignored when not writing to the Code Editor).
@export var code_placement: CodePlacement

## Ensures the assistant's response is returned as a GDScript comment.
## If required, adds a # to each line and keeps lines around 80 characters long.
## This is useful to request the generation of inline documentation.
@export var format_response_as_comment: bool
