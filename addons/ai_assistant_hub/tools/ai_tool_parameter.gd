## A parameter used in tool calls. These are mapped to function parameters.
class_name AIToolParameter
extends Resource

enum ParameterType { Int, Float, Boolean, String, Code, StringEnum, Array }

@export var type:ParameterType
@export var name:String
@export var description:String
@export var required:bool
@export_group("StringEnum", "string_enum_")
@export var string_enum_valid_values:Array[String]
