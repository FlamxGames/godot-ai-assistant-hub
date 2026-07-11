@tool
class_name AIToolOption
extends Resource

enum OptionType { Int, Float, Boolean, StringLine, StringMultiLine, ArrayOfProjectDir, ArrayOfProjectFiles }

@export var id:String
@export var name:String
@export var description:String
@export var type:OptionType
@export var allow_null:bool


func get_default_value() -> Variant:
	match type:
		OptionType.Int, OptionType.Float: return 0
		OptionType.Boolean: return false
		OptionType.StringLine, OptionType.StringMultiLine: return ""
		OptionType.ArrayOfProjectDir, OptionType.ArrayOfProjectFiles: return []
		_: return null


static func get_array_from_multiline_string(multiline:String) -> PackedStringArray:
	var arr:= PackedStringArray()
	if not multiline.is_empty():
		arr = multiline.split("\n")
		for i in arr.size():
			arr[i] = arr[i].strip_escapes().strip_edges()
	return arr
