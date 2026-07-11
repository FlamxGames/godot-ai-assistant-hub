extends AITool

var _file_path : String
var _start_line : int
var _end_line : int


func execute() -> bool:
	_file_path = _parameter_values.get("file_path", "")
	_start_line = _parameter_values.get("from_line", 1)
	_end_line   = _parameter_values.get("to_line", -1)  # -1 == EOF

	if _file_path == "":
		_errors.append("No file_path was supplied.")
		return false

	# Validate file existence
	if not FileAccess.file_exists(_file_path):
		_errors.append("File does not exist: %s" % _file_path)
		return false

	# Validate line numbers
	if _start_line < 1:
		_errors.append("The selected from_line must be >= 1.")
		return false
	if _end_line != -1 and _end_line < _start_line:
		_errors.append("The selected to_line is less than from_line.")
		return false
	
	var read_from_editor:= false
	var numbered_code := PackedStringArray()
	
	# Decide source: editor or disk
	var config = ConfigFile.new()
	config.load("res://.godot/editor/editor_layout.cfg") # No API to get the path for open script editors, so we need to use this
	var arr_paths:Array = config.get_value("ScriptEditor", "open_scripts")
	var editor_index = arr_paths.find(_file_path)

	if editor_index != -1:
		var script_editor := EditorInterface.get_script_editor()
		
		if script_editor != null:
			var open_script_editors := script_editor.get_open_script_editors()
			#var target_script_editor : ScriptEditorBase = null
			#for editor in open_script_editors: # This stopped working in Godot 4.4
				#if editor.has_meta(&"_edit_res_path"):
					#var editor_path = editor.get_meta(&"_edit_res_path")
					#if editor_path == _file_path:
						#target_script_editor = editor
						#break
			var target_script_editor : ScriptEditorBase = script_editor.get_open_script_editors()[editor_index]
			if target_script_editor:
				var content = target_script_editor.get_base_editor().text.split("\n")

				var line_count = content.size()
				if _end_line == -1:
					_end_line = line_count
				if _end_line > line_count:
					_end_line = line_count

				for line_num in range(_start_line - 1, _end_line):
					numbered_code.append("%d\t\t|%s" % [ line_num + 1, content[line_num] ])
				read_from_editor = true
				AIHubPlugin.print_msg("Read %s from editor." % _file_path)
	
	if not read_from_editor:
		var file := FileAccess.open(_file_path, FileAccess.READ)
		if file == null:
			_errors.append("Could not open file: %s" % _file_path)
			return false

		var current_line = 1
		while not file.eof_reached():
			var line = file.get_line()
			if current_line >= _start_line and (_end_line == -1 or current_line <= _end_line):
				numbered_code.append("%d\t\t|%s" % [current_line, line])
			if _end_line != -1 and current_line >= _end_line:
				break
			current_line += 1
		AIHubPlugin.print_msg("Read %s from disk." % _file_path)

	_success_message = "\n".join(numbered_code)
	AIHubPlugin.print_msg("Read %d lines from %s" % [numbered_code.size(), _file_path])
	return true
