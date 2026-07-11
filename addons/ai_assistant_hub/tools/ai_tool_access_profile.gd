@tool
## An instance of this resource contains access and options configuration for tools.
## This is used in:
## 1. The default configurations at res://addons/ai_assistant_hub/tools/permission_profiles/ .
## 2. At the assistant type resources, to save specific overrides to the permissions per agent.
## 3. At quick prompt level, to save specific permissions to use in quick prompts.
class_name AIToolAccessProfile
extends Resource

## Permissions dictionary description
## Key: AIToolResource
## Value: AIToolAccess
## |-- usage_permission:Permission (enum)
## |-- option_values:Dictionary (see description in AIToolAccess)
@export var permissions:Dictionary

@export var global_option_values:Dictionary = {}


static func create_from_profiles_in_order(profiles:Array[AIToolAccessProfile]) -> AIToolAccessProfile:
	var new_profile:= AIToolAccessProfile.new()
	for other_profile in profiles:
		if other_profile:
			for key in other_profile.permissions.keys():
				new_profile.permissions[key] = AIToolAccess.clone(other_profile.permissions[key])
			new_profile.global_option_values.merge(other_profile.global_option_values, true)
	return new_profile


func reset() -> void:
	permissions = {}


func has_tool(tool:AIToolResource) -> bool:
	return permissions.has(tool)


func remove_tool(tool:AIToolResource) -> void:
	permissions.erase(tool)


func get_tool_permission(tool:AIToolResource) -> AIToolAccess.Permission:
	var entry:AIToolAccess = permissions[tool]
	return entry.usage_permission


func set_tool_permission(tool:AIToolResource, permission:AIToolAccess.Permission) -> void:
	var entry:AIToolAccess = permissions.get_or_add(tool, AIToolAccess.new())
	entry.usage_permission = permission


func get_tool_option_values(tool:AIToolResource) -> Dictionary:
	var entry:AIToolAccess = permissions[tool]
	return entry.option_values


func set_tool_option_values(tool:AIToolResource, option_values:Dictionary) -> void:
	permissions[tool].option_values = option_values


func get_global_option_values() -> Dictionary:
	return global_option_values


func set_global_option_values(option_values:Dictionary) -> void:
	global_option_values = option_values.duplicate()
