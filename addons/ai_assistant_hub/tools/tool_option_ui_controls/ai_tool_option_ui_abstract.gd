@tool
class_name AIToolOptionUIAbstract
extends Control

var _option:AIToolOption


func initialize(_option:AIToolOption, _value) -> void:
	pass


func get_value() -> Variant:
	return null


func is_valid() -> bool:
	return false


func get_option_id() -> String:
	return _option.id
