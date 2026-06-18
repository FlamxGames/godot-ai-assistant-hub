## A category that groups tools, allows to display them in an organized fashion with an icon.
class_name AIToolCategory
extends Resource

@export var name:String
@export var icon:Texture2D

static func sort_by_name(a:AIToolCategory, b:AIToolCategory):
	if a.name < b.name:
		return true
	return false
