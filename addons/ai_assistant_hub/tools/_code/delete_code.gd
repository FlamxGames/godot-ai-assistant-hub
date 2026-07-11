extends AITool

var _code_editor:TextEdit
var _file_path:String
var _delete_start_line:int
var _delete_end_line:int
var _rationale:String
var _deleted_code:String


func execute() -> bool:
	_file_path = _parameter_values.get("file_path", "")
	_delete_start_line = _parameter_values.get("delete_start_line", 0)
	_delete_end_line = _parameter_values.get("delete_end_line", 0)
	_rationale = _parameter_values.get("rationale", "")

	# Validate parameters and make sure the script is loaded
	var valid := await _validate_parameters()
	if not valid:
		return false

	# Delete the selected range
	_code_editor.select(_delete_start_line - 1, 0, _delete_end_line - 1, _code_editor.get_line(_delete_end_line - 1).length())
	_deleted_code = _code_editor.get_selected_text()
	_code_editor.delete_selection()
	_code_editor.remove_line_at(_code_editor.get_caret_line())

	var execution_id := _register_undo()
	var new_code_with_context := _read_result()

	var num_lines := _delete_end_line - _delete_start_line + 1
	_success_message = "Deleted %d lines.\nExecution Id:%s\nReview the code state after this change is correct:\n" % [ num_lines, execution_id ]
	for line in new_code_with_context:
		_success_message += line

	return true


func _validate_parameters() -> bool:
	if _file_path == "":
		_errors.append("No file_path was supplied.")
		return false

	# Validate file path against allowed and prohibited lists
	if not AIToolFileUtils.validate_allowed_paths(_file_path, _read_option("allowed_paths"), _errors, true):
		return false
	if not AIToolFileUtils.validate_prohibited_paths(_file_path, _read_option("prohibited_paths"), _errors, true):
		return false
	
	for f in _read_option("prohibited_files"):
		if _file_path == f:
			_errors.append("The file is protected, you cannot edit it.")
			return false

	# Ensure the target script is loaded
	var success := await AIToolFileUtils.open_file_in_code_editor(_file_path, _errors)
	if not success:
		return false

	_code_editor = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	if _code_editor == null:
		_errors.append("Error while trying to get the code editor.")
		return false

	# Validate line numbers
	if _delete_start_line < 1 or _delete_start_line > _code_editor.get_line_count():
		_errors.append("Start line is invalid.")
	if _delete_end_line < 1:
		_errors.append("End line is invalid.")
	if _delete_start_line > _delete_end_line:
		_errors.append("Start line cannot be greater than end line.")

	# Clamp end line to file size if needed
	var line_count = _code_editor.get_line_count()
	if _delete_end_line > line_count:
		_delete_end_line = line_count

	if _errors.size() > 0:
		return false
	return true


func _read_result() -> PackedStringArray:
	var file_lines := _code_editor.text.split("\n")

	var margin := 5
	var start_line := _delete_start_line - margin
	var end_line := _delete_start_line + margin

	if start_line < 1:
		start_line = 1
	if end_line > file_lines.size():
		end_line = file_lines.size()

	var numbered_code := PackedStringArray()

	for line_num in range(start_line, end_line + 1):
		if line_num == _delete_start_line:
			numbered_code.append("--- the deleted code was here ---\n")
		numbered_code.append("%d\t\t|%s\n" % [ line_num, file_lines[line_num - 1] ])

	return numbered_code


func undo() -> bool:
	var success := await AIToolFileUtils.open_file_in_code_editor(_file_path, _errors)
	if not success:
		return false

	_code_editor = EditorInterface.get_script_editor().get_current_editor().get_base_editor()
	if _code_editor == null:
		_errors.append("Error while trying to get the code editor.")
		return false
	
	# Restore the deleted code
	_code_editor.deselect()
	_code_editor.insert_text("%s\n" % _deleted_code, _delete_start_line - 1, 0)

	_success_message = "Code successfully restored."
	return true
