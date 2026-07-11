@tool
class_name AIToolResource
extends Resource

@export var id:String ## This value identifies a tool uniquely. This is used as the function name.
@export var title:String ## Displayed in tools selection.
@export_multiline var description:String ## Tells the assistants what the tool does.
@export var category:AIToolCategory ## Group the tool belongs to.
@export var parameters:Array[AIToolParameter] ## Tells the assistant the parameters expected to be used when calling the corresponding function.
@export var options:Array[AIToolOption] ## Additional options to limit or customize the usage of a tool.


static func sort_by_title(a:AIToolResource, b:AIToolResource):
	if a.title < b.title:
		return true
	return false


## Create an executable instance of the tool. For options parameter definition see AIToolAccess
func create_instance(option_values:Dictionary, tool_undo_queue:AIToolUndoQueue) -> AITool:
	AIHubPlugin.print_msg("Creating tool instance for: %s" % self.resource_path)
	var dir := self.resource_path.get_base_dir()
	var script_name := self.resource_path.get_file().get_basename()
	var script_path = "%s/%s.gd" % [dir, script_name]
	var script:Resource
	if ResourceLoader.exists(script_path):
		script = load(script_path)
	if script == null:
		AIHubPlugin.print_err("Failed to load tool script: %s" % script_path)
		return null
	var instance:AITool = script.new(self, option_values, tool_undo_queue)
	if instance == null:
		AIHubPlugin.print_err("Failed to instantiate tool from script: %s" % script_path)
		return null # Add this line to ensure a value is always returned
	AIHubPlugin.print_msg("Succeded creating tool instance for: %s" % self.resource_path)
	return instance
