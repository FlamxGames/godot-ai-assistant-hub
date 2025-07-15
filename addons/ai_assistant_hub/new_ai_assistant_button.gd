@tool
class_name NewAIAssistantButton
extends Button

signal chat_created(chat: AIChat, assistant_type:AIAssistantResource)

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

var _plugin:AIHubPlugin
var _data: AIAssistantResource
var _chat: AIChat
var _name: String


func initialize(plugin:AIHubPlugin, assistant_resource: AIAssistantResource) -> void:
	_plugin = plugin
	_data = assistant_resource
	text = _data.type_name
	icon = _data.type_icon
	if text.is_empty() and icon == null:
		text = _data.resource_path.get_file().trim_suffix(".tres")
	
	
func _on_pressed() -> void:
	if available_names == null or available_names.size() == 0:
		available_names = NAMES.duplicate()
	available_names.shuffle()
	_name = available_names.pop_back()
	
	_chat = AI_CHAT.instantiate()
	_chat.initialize(_plugin, _data, _name)
	if _data.type_icon == null:
		_chat.name = "%s [%s]" % [text, _name]
	else:
		_chat.name = "%s" % [_name]
	chat_created.emit(_chat, _data)
