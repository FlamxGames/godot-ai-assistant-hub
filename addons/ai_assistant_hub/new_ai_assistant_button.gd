@tool
class_name NewAIAssistantButton
extends Button

signal chat_created(chat: AIChat)
signal deleted()

const AI_CHAT = preload("res://addons/ai_assistant_hub/ai_chat.tscn")
const NAMES: Array[String] = ["Ace", "Bean", "Boss", "Bubs", "Bugger", "Shushi", "Chicky", "Crash",
"Cub", "Daisy", "Dixie", "Doofus", "Doozy", "Dudedorf", "Fuzz", "Gabby", "Gizmo", "Goose", "Hiccup",
"Hobo", "Jinx", "Kix", "Lulu", "Munch", "Nuppy", "Ollie", "Ookie", "Pud", "Punchme", "Pup", 
"Rascal", "Rusty", "Sausy", "Sparky", "Squirro", "Stubby", "Sugar", "Taco", "Tank", "Tater", "Ted",
"Titus", "Toady", "Tweedle", "Winky", "Zippy", "Luffy", "Zoro", "Chopper", "Usop", "Nami", "Robin",
"Juan", "Paco", "Pedro", "Goku", "Vegeta", "Trunks", "Piccolo", "Gohan", "Krillin", "Tenshinhan",
"Bulma", "Oolong", "Yamcha", "Pika", "Buu", "Freezer", "Cell", "L", "Light", "Ryuk", "Misa", "Near",
"Mello", "Rem", "Eren", "Mike", "Armin", "Hange", "Levi", "Eva", "Erwin", "Conny", "Mikasa",
"Naruto", "Sasuke", "Kakashi", "Tsunade", "Iruka", "Sakura", "Shikamaru", "Obito", "Itadori",
"Fushiguro", "Nobara", "Gojo", "Geto", "Sukuna", "Spike", "Jet", "Faye", "Ed", "Ein", "Julia",
"Jotaro", "Joestar", "Jolyne", "Jonathan", "Giorno", "Dio", "Polnareff", "Kakyoin", "Saitama",
"Genos", "Tenma", "Shinji", "Asuka", "Rei", "Misato", "Tanjiro", "Nezuko", "Inosuke", "Zenitsu" ]

static var available_names: Array[String]

@onready var popup_menu: PopupMenu = %PopupMenu
@onready var confirmation_dialog: ConfirmationDialog = %ConfirmationDialog

var _plugin:AIHubPlugin
var _data: AIAssistantResource
var _chat: AIChat
var _name: String
var _assistant_type_path: String


func initialize(plugin:AIHubPlugin, assistant_resource: AIAssistantResource, assistant_type_path: String) -> void:
	_plugin = plugin
	_data = assistant_resource
	_assistant_type_path = assistant_type_path
	text = _data.type_name
	icon = _data.type_icon
	if text.is_empty() and icon == null:
		text = _data.resource_path.get_file().trim_suffix(".tres")


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_released():
		if event.button_index == MOUSE_BUTTON_RIGHT:
			popup_menu.position = DisplayServer.mouse_get_position()
			popup_menu.show()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if available_names == null or available_names.size() == 0:
				available_names = NAMES.duplicate()
			available_names.shuffle()
			_name = available_names.pop_back()
			
			_chat = AI_CHAT.instantiate()
			_chat.initialize(_plugin, _data, _name)
			chat_created.emit(_chat)


func _on_popup_menu_id_pressed(id: int) -> void:
	# Using big numbers because Godot sometimes have bugs giving default values based on position
	match id:
		100:  #  Edit
			var res = ResourceLoader.load(_assistant_type_path)
			EditorInterface.edit_resource(res)
		200:  # Delete
			confirmation_dialog.show()


func _on_confirmation_dialog_confirmed() -> void:
	DirAccess.remove_absolute(_assistant_type_path)
	EditorInterface.get_resource_filesystem().scan()
	deleted.emit()
