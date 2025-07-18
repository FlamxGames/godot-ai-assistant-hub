@tool
class_name BotPortrait
extends Control

const PORTRAITS_BASE := preload("res://addons/ai_assistant_hub/graphics/portraits/portraits_base.png")
const PORTRAIT_AMOUNT_X := 3
const PORTRAIT_AMOUNT_Y := 3
const SCALE := 3 # given the images are 16px but we are displaying them 48px, this is used to move the face when thinking

@onready var portrait_base: TextureRect = %PortraitBase
@onready var portrait_mouth: TextureRect = %PortraitMouth
@onready var portrait_eyes: TextureRect = %PortraitEyes
@onready var portrait_thinking: TextureRect = %PortraitThinking
@onready var bot_cancel: Button = %BotCancel

var _think_tween:Tween

func set_random() -> void:
	var tex_size := PORTRAITS_BASE.get_size()
	var portrait_size := Vector2i(tex_size.x / PORTRAIT_AMOUNT_X, tex_size.y / PORTRAIT_AMOUNT_Y)
	_select_random_region(portrait_base)
	_select_random_region(portrait_mouth)
	_select_random_region(portrait_eyes)


func _select_random_region(image:TextureRect) -> void:
	var x_rand := randi_range(0, PORTRAIT_AMOUNT_X - 1)
	var y_rand := randi_range(0, PORTRAIT_AMOUNT_Y - 1)
	var base_atlas: AtlasTexture = image.texture.duplicate()
	image.texture = base_atlas
	base_atlas.region = Rect2(x_rand*16,y_rand*16,16,16)


var is_thinking:= false:
	set(value):
		is_thinking = value
		if _think_tween != null and _think_tween.is_running():
			_think_tween.stop()
		portrait_thinking.visible = is_thinking
		bot_cancel.visible = is_thinking
		if is_thinking:
			portrait_eyes.position.x = SCALE
			portrait_eyes.position.y = -SCALE
			portrait_mouth.position = portrait_eyes.position
			_thinking_anim()
		else:
			portrait_eyes.position = Vector2.ZERO
			portrait_mouth.position = Vector2.ZERO
			self.rotation_degrees = 0


func _thinking_anim() -> void:
	while is_thinking:
		_think_tween = create_tween()
		_think_tween.tween_property(self, "rotation_degrees", -12, 1)
		_think_tween.tween_property(self, "rotation_degrees", 12, 1)
		await _think_tween.finished
	self.rotation_degrees = 0
	var complete = create_tween()
	complete.tween_property(self, "scale", Vector2(1.2, 1.2), 0.05)
	complete.tween_property(self, "scale", Vector2(1, 1), 0.05)
