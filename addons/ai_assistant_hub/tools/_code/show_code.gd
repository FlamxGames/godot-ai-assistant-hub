extends AITool

var _code_editor:TextEdit

var _file_path:String
var _no_selection:bool

func execute() -> bool:
	_file_path = _parameter_values.get("file_path", "")
	var from_line:int = _parameter_values.get("from_line", -1)
	var to_line:int = _parameter_values.get("to_line", -1)
	_no_selection = from_line == -1 and to_line == -1
	
	var allowed_paths:PackedStringArray = _read_option("allowed_paths")
	var prohibited_paths:PackedStringArray = _read_option("prohibited_paths")
	
	if _file_path == "":
		_errors.append("No file_path was supplied.")
		return false
	
	# Validate file path against allowed and prohibited lists
	if not AIToolFileUtils.validate_allowed_paths(_file_path, allowed_paths, _errors, true):
		return false
	if not AIToolFileUtils.validate_prohibited_paths(_file_path, prohibited_paths, _errors, true):
		return false
	
	var success := await AIToolFileUtils.open_file_in_code_editor(_file_path, _errors)
	if not success:
		return false
	
	_code_editor = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	if _code_editor == null:
		_errors.append("Error while trying to get the code editor.")
		return false
	
	if _no_selection:
		_success_message = "Opened %s" % _file_path
	else:
		if from_line != -1:
			if not _validate_line_number(from_line):
				_errors.append("The selected from_line is invalid.")
				return false
		
		if to_line == -1 or to_line > _code_editor.get_line_count():
			to_line = _code_editor.get_line_count()
		elif not _validate_line_number(to_line):
			_errors.append("The selected to_line is invalid.")
			return false
		
		if from_line > to_line:
			_errors.append("The selected from_line is greater than to_line.")
			return false
		
		_code_editor.select(from_line -1, 0, to_line - 1, _code_editor.get_line(to_line - 1).length())
		_code_editor.scroll_vertical = _code_editor.get_scroll_pos_for_line(from_line - 1)
		_success_message = "Opened %s and highlighted content:\n```%s```" % [ _file_path, _code_editor.get_selected_text() ]
	return true


func _validate_line_number(line_number:int) -> bool:
	return line_number <= _code_editor.get_line_count() and line_number >= 1
