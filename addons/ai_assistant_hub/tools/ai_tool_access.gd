@tool
## Used in AIToolAccessProfile to save the permission level and options for each tool.
class_name AIToolAccess
extends Resource

enum Permission { Hide, Ask, Allow }

## Usage permission that controls if an assistant can see or not a tool, and if they can, if they must ask before using it or not
@export var usage_permission:Permission

## Options for the tool.
## Dictionary description:
## Key: String (AIToolOption.id)
## Value: Variant (based on the AIToolOption.type)
@export var option_values:Dictionary


static func clone(to_clone:AIToolAccess) -> AIToolAccess:
	var clone := AIToolAccess.new()
	clone.usage_permission = to_clone.usage_permission
	clone.option_values = to_clone.option_values.duplicate(true)
	return clone
