@tool
class_name NewAIAssistantButton
extends Button

signal chat_created(chat: AIChat)
signal deleted()
signal assistant_type_edit_request(assistant_type:AIAssistantResource)

const AI_CHAT = preload("res://addons/ai_assistant_hub/ai_chat.tscn")
const NAMES: Array[String] = ["Ace", "Bean", "Boss", "Bubs", "Bugger", "Shushi", "Chicky", "Crash",
"Cub", "Daisy", "Dixie", "Doofus", "Doozy", "Dudedorf", "Fuzz", "Gabby", "Gizmo", "Goose", "Hiccup",
"Hobo", "Jinx", "Kix", "Lulu", "Munch", "Nuppy", "Ollie", "Ookie", "Pud", "Punchme", "Pup", 
"Rascal", "Rusty", "Sausy", "Sparky", "Squirro", "Stubby", "Sugar", "Taco", "Tank", "Tater", "Ted",
"Titus", "Toady", "Tweedle", "Winky", "Zippy", "Luffy", "Zoro", "Chopper", "Usop", "Nami", "Robin",
"Juan", "Paco", "Pedro", "Goku", "Vegeta", "Trunks", "Piccolo", "Gohan", "Krillin", "Tenshinhan",
"Bulma", "Oolong", "Yamcha", "Pika", "Buu", "Freezer", "Cell", "L", "Light", "Ryuk", "Misa", "Near",
"Mello", "Rem", "Mike", "Armin", "Hange", "Levi", "Eva", "Erwin", "Conny", "Mikasa",
"Naruto", "Sasuke", "Kakashi", "Tsunade", "Iruka", "Sakura", "Shikamaru", "Obito", "Itadori",
"Fushiguro", "Nobara", "Gojo", "Geto", "Sukuna", "Spike", "Jet", "Faye", "Ed", "Ein", "Julia",
"Jotaro", "Joestar", "Jolyne", "Jonathan", "Giorno", "Dio", "Polnareff", "Kakyoin", "Saitama",
"Genos", "Tenma", "Shinji", "Asuka", "Rei", "Misato", "Tanjiro", "Nezuko", "Inosuke", "Zenitsu",
"Nuppie", "Mippie", "Reppie", "Lippie", "Hapitan", "Nutan", "Lubtan", "Nebitan", 
"Morick", "Keick", "Coswick", "Somack", "Motolar", "Tielar", "Muelar", "Rohealar", 
"Areff", "Sireff", "Ereff", "Greff", "Ireff", "Bireff", "Dereff", "Fureff", 
"Hareff", "Gireff", "Kennet", "Bennet", "Yennet", "Sennet", "Clocpah", "Clocpugh", 
"Clocpooh", "Beevoize", "Beenet", "Beeres", "Beesus", "Sticker", "Stickon", 
"Stickle", "Sticken", "Bomga", "Bompa", "Bompu", "Bomba", "Birsky", "Birfly", 
"Birtack", "Birdain", "Birtross", "Birrair", "Garm", "Stocchu", "Stoccha", "Stoccho", 
"Totten", "Kenapa", "Slap", "Samek", "Clinton", "Colin", "Cary", "Moire", 
"Clapa", "Cloppa", "Clappie", "Clappa", "Ribbid", "Ribbita", "Ribbite", "Ribbito", 
"Clocka", "Clocha", "Cloco", "Clocki", "Hafmargo", "Collper", "C-hopper", "Jackson", 
"Grandie", "Yeppie", "Mappie", "Fuppie", "Euppie", "Estan", "Peatan", "Emick", 
"Satick", "Parick", "Mitick", "Ishilar", "Tomilar", "Mikilar", "Remilar", "Kereff", 
"Mureff", "Oreff", "Rireff", "Nureff", "Pireff", "Arnue", "Charnue", "Culoppe", 
"Meloppe", "Miloppe", "Reloppe", "Putti", "Setti", "Metti", "Jetti", "Betti", 
"Piotti", "Torti", "Torte", "Rulira", "Relira", "Rolira", "Rulero", "Beeta", 
"Hani", "Eren", "Elen", "Ribbitar", "Reba", "Riba", "Roba", "Pokon", 
"Poko", "Pokopi", "Pokopo", "Fila", "Filaa", "Filas", "Filar", "Jerran", 
"Peran", "Meran", "Teran", "Cansy", "Kansy", "Pansy", "Ensy", "Sirea", 
"Mirean", "Slarea", "Sclarean", "Kwappa", "Kiwappa", "Kuwappa", "Kowappa", "Iruka", 
"Kujira", "Shachi", "Mega", "Slime", "Slimy", "Slimer", "Slimest", "Slira", 
"Slire", "Martina", "Milvy", "Elphy", "Sylphy", "Rilphy", "Artan", "Zictan", 
"Snoq", "Mathiq", "Miyaq", "Ajiq", "Dobuq", "Mulaq", "Mailla", "Miulla", 
"Curiph", "Luriph", "Suriph", "Tiriph", "Yuriph", "Beriph", "Wiliph", "Cyliph", 
"Mott", "Dott", "Cloppe", "Sloppe", "Jango", "Hongo", "Dongo", "Batta", 
"Ratta", "Feever", "Peever", "Pitap", "Potap", "Archir", "Archil", "Shuriks", 
"Yuriks", "Byse", "Enethas", "Metorika", "Teratite", "Raddis", "Chaddis", "Maddis", 
"Taddis", "Beetla", "Beetli", "Beotle", "Beetlo", "Karon", "Boron", "Siron", 
"Goron", "Minite", "Monite", "Bunite", "Punite", "Mira", "Reira", "Saira", 
"Taira", "Ruri", "Eri", "Shiri", "Miri", "Yuri", "Chiri", "Seri", "Nari", 
"Mari", "Croire" ]

static var available_names: Array[String]

@onready var popup_menu: PopupMenu = %PopupMenu
@onready var confirmation_dialog: ConfirmationDialog = %ConfirmationDialog

var _plugin:AIHubPlugin
var _data: AIAssistantResource
var _chat: AIChat
var _name: String
var _assistant_type_path: String
var _models_info:AIModelInfoFetcher


func initialize(plugin:AIHubPlugin, assistant_resource: AIAssistantResource, assistant_type_path: String, models_info:AIModelInfoFetcher) -> void:
	_plugin = plugin
	_data = assistant_resource
	_assistant_type_path = assistant_type_path
	_models_info = models_info
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
			_chat.initialize(_plugin, _data, _name, _models_info)
			chat_created.emit(_chat)


func _on_popup_menu_id_pressed(id: int) -> void:
	# Using big numbers because Godot sometimes have bugs giving default values based on position
	match id:
		100:  #  Edit
			var res = ResourceLoader.load(_assistant_type_path)
			#EditorInterface.edit_resource(res)  - we don't encourage editing it in the inspector anymore, since we want to propagate changes automatically
			assistant_type_edit_request.emit(res)
		200:  # Delete
			confirmation_dialog.show()


func _on_confirmation_dialog_confirmed() -> void:
	DirAccess.remove_absolute(_assistant_type_path)
	EditorInterface.get_resource_filesystem().scan()
	deleted.emit()
