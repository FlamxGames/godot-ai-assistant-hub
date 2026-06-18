extends AITool

var _code_editor:TextEdit
var _file_path:String
var _new_content:String
var _replace_start_line:int
var _replace_end_line:int
var _rationale:String
var _replaced_code:String


func execute() -> bool:
	_file_path = _parameter_values.get("file_path", "")
	_new_content = _parameter_values.get("new_content", "")
	_replace_start_line = _parameter_values.get("replace_start_line", 0)
	_replace_end_line = _parameter_values.get("replace_end_line", 0)
	_rationale = _parameter_values.get("rationale", "")

	var valid := await _validate_parameters()
	if not valid:
		return false

	# Perform replacement
	_code_editor.select(_replace_start_line - 1, 0, _replace_end_line - 1, _code_editor.get_line(_replace_end_line - 1).length())
	_replaced_code = _code_editor.get_selected_text()
	_code_editor.insert_text_at_caret(_new_content)

	var execution_id := _register_undo()
	var new_code_with_context := _read_result()

	_success_message = "Code replaced.\nExecution Id:%s\nReview the code state after this change is correct:\n" % execution_id
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

	if _replace_start_line < 1 or _replace_start_line > _code_editor.get_line_count():
		_errors.append("Start line is invalid.")

	if _replace_end_line < 1:
		_errors.append("End line is invalid.")

	if _replace_start_line > _replace_end_line:
		_errors.append("Start line cannot be greater than end line.")

	# Clamp end line to file size if needed
	var line_count = _code_editor.get_line_count()
	if _replace_end_line > line_count:
		_replace_end_line = line_count

	if _errors.size() > 0:
		return false
	return true


func _read_result() -> PackedStringArray:
	var new_content_lines := _new_content.split("\n")
	var new_content_end_line := _replace_start_line + new_content_lines.size() - 1
	var file_lines := _code_editor.text.split("\n")

	var margin := 5
	var start_line := _replace_start_line - margin
	var end_line := new_content_end_line + margin

	if start_line < 1:
		start_line = 1
	if end_line > file_lines.size():
		end_line = file_lines.size()

	var numbered_code := PackedStringArray()
	var omit_start := _replace_start_line + margin
	var omit_end := new_content_end_line - margin

	var omit_added:= false
	for line_num in range(start_line, end_line + 1):
		if line_num > omit_start and line_num < omit_end:
			# Omit lines in the middle to keep output short
			if not omit_added:
				omit_added = true
				numbered_code.append("--- omitted lines (%d-%d) ---\n" % [omit_start + 1, omit_end - 1])
			continue
		if line_num == _replace_start_line:
			numbered_code.append("--- replace start ---\n")
		numbered_code.append("%d\t\t|%s\n" % [ line_num, file_lines[line_num - 1] ])
		if line_num == new_content_end_line:
			numbered_code.append("--- replace end ---\n")

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
	var new_content_end_line = _replace_start_line + new_content_lines.size() - 1
	var start_matches = _code_editor.get_line(_replace_start_line - 1).strip_edges() == new_content_lines[0].strip_edges()
	var end_matches = _code_editor.get_line(new_content_end_line - 1).strip_edges() == new_content_lines[new_content_lines.size() -1].strip_edges()
	if start_matches and end_matches:
		_code_editor.select(_replace_start_line - 1, 0, new_content_end_line - 1, _code_editor.get_line(new_content_end_line - 1).length())
		_code_editor.delete_selection()
		_code_editor.insert_text_at_caret(_replaced_code)
		_success_message = "Code successfully restored."
		return true
	else:
		_errors.append("Tried to undo replace_code but the code does not match anymore.")
		return false
