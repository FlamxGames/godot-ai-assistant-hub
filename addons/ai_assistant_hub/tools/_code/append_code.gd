extends AITool

var _code_editor:TextEdit
var _insert_at_eof:bool

# Parameters
var _file_path:String
var _new_content:String
var _append_line:int
var _rationale:String

func execute() -> bool:
	_file_path = _parameter_values.get("file_path", "")
	_new_content = _parameter_values.get("new_content", "")
	_append_line = _parameter_values.get("append_line", 0)
	_rationale = _parameter_values.get("rationale", "")
	
	_new_content = _new_content.trim_suffix("\n")
	
	var valid := await _validate_parameters()
	if not valid:
		return false
	
	if _insert_at_eof:
		var last_line := _code_editor.get_line_count() - 1
		_code_editor.deselect()
		_code_editor.insert_text("\n%s\n" % _new_content, last_line, _code_editor.get_line(last_line).length())

	else:
		var existing_start_line_content := _code_editor.get_line(_append_line - 1).strip_edges()
		_code_editor.set_caret_line(_append_line - 1)
		_code_editor.set_caret_column(0)
		_code_editor.deselect()
		if existing_start_line_content.is_empty():
			_code_editor.insert_text_at_caret("%s" % _new_content)
		else:
			_code_editor.insert_text_at_caret("%s\n" % _new_content)
	
	var new_code_with_context := _read_result()
	
	var execution_id := _register_undo()
	_success_message = "Code inserted.\nExecution Id:%s\nReview the code state after this change is correct:\n" % execution_id
	for line in new_code_with_context:
		_success_message += line
	return true


func _validate_parameters() -> bool:
	var allowed_paths:PackedStringArray = _read_option("allowed_paths")
	var prohibited_paths:PackedStringArray = _read_option("prohibited_paths")
	var prohibited_files:PackedStringArray = _read_option("prohibited_files")
	var banned_code_lines:String = _read_option("banned_code")

	if _file_path == "":
		_errors.append("No file_path was supplied.")
		return false
	
	# Validate file path against allowed and prohibited lists
	if not AIToolFileUtils.validate_allowed_paths(_file_path, allowed_paths, _errors, true):
		return false
	if not AIToolFileUtils.validate_prohibited_paths(_file_path, prohibited_paths, _errors, true):
		return false

	for f in prohibited_files:
		if _file_path == f:
			_errors.append("The file is protected, you cannot edit it.")
			return false
	
	if not _new_content.is_empty() and banned_code_lines != "":
		var banned_parts := banned_code_lines.split("\n")
		for part in banned_parts:
			part = part.strip_edges()
			if not part.is_empty() and _new_content.find(part) != -1:
				_errors.append("Banned keyword defined by the user detected in new content: '%s'." % part)
				return false
	
	var success := await AIToolFileUtils.open_file_in_code_editor(_file_path, _errors)
	if not success:
		return false
	
	_code_editor = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	if _code_editor == null:
		_errors.append("Error while trying to get the code editor.")
		return false
	
	if _append_line > _code_editor.get_line_count():
		_insert_at_eof = true
	if _append_line < 1:
		_errors.append("Start line is invalid.")
		return false
	return true


func _read_result() -> PackedStringArray:
	var new_content_lines = _new_content.split("\n")
	var file_lines = _code_editor.text.split("\n")
	
	var margin := 5
	var start_line := _append_line - margin
	var append_end_line := _append_line + new_content_lines.size()-1
	var end_line := append_end_line + margin
	if start_line < 1:
		start_line = 1
	if end_line > file_lines.size():
		end_line = file_lines.size()

	var omit_start := _append_line + margin
	var omit_end := _append_line + new_content_lines.size()-1 - margin

	var numbered_code := PackedStringArray()
	var omit_msg_required:= true
	for line_num in range(start_line, end_line + 1): #This loop is 1-based
		if line_num > omit_start and line_num < omit_end:
			if omit_msg_required:
				numbered_code.append("--- omitted lines (%d-%d) ---\n" % [omit_start + 1, omit_end - 1])
				omit_msg_required = false
			continue
		if line_num == _append_line:
			numbered_code.append("--- append start ---\n")
		numbered_code.append("%d\t\t|%s\n" % [ line_num, file_lines[line_num - 1] ])
		if line_num == append_end_line:
			numbered_code.append("--- append end ---\n")
	return numbered_code


func undo() -> bool:
	var success := await AIToolFileUtils.open_file_in_code_editor(_file_path, _errors)
	if not success:
		return false
		
	_code_editor = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	if _code_editor == null:
		_errors.append("Error while trying to get the code editor.")
		return false
	
	var new_content_lines = _new_content.split("\n")
	var append_end_line := _append_line + new_content_lines.size()-1
	var start_matches = _code_editor.get_line(_append_line - 1).strip_edges() == new_content_lines[0].strip_edges()
	var end_matches = _code_editor.get_line(append_end_line - 1).strip_edges() == new_content_lines[new_content_lines.size() -1].strip_edges()
	if start_matches and end_matches:
		_code_editor.select(_append_line - 1, 0, append_end_line - 1, _code_editor.get_line(append_end_line - 1).length())
		_code_editor.delete_selection()
		_code_editor.remove_line_at(_code_editor.get_caret_line())
		_success_message = "Code successfully undone."
		return true
	else:
		_errors.append("Tried to undo append_code but the code does not match anymore.")
		return false
