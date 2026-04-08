@tool
class_name AssistantToolSelection

var _plugin:EditorPlugin
var _code_editor:TextEdit
var _selected_script: Script
var _selected_code: String
var _selected_code_first_line: String
var _selected_code_last_line: String
var _selected_code_line_start: int
var _selected_code_line_start_column: int
var _selected_code_line_end: int
var _selected_code_line_end_column: int


func _init(plugin:EditorPlugin) -> void:
	_plugin = plugin


func get_selection() -> String:
	var script_editor:= _plugin.get_editor_interface().get_script_editor()
	_code_editor = script_editor.get_current_editor().get_base_editor()
	
	_selected_script = script_editor.get_current_script()
	_selected_code = _code_editor.get_selected_text()
	if _selected_code.strip_edges(true, true).length() == 0:
		var curr_line = _code_editor.get_caret_line()
		_code_editor.select(curr_line, 0, curr_line, line(curr_line).length())
		_selected_code = _code_editor.get_selected_text().strip_edges(true, true)
	
	if not _selected_code.is_empty():
		#Make sure we don't start or end with empty lines, as that makes difficult to find the code again
		var first_not_empty = line(first_line()).strip_edges(true, false)
		while first_not_empty.is_empty() and first_line() + 1 <= last_line():
			_code_editor.select(first_line() + 1, 0, last_line(), last_column())
			first_not_empty = line(first_line()).strip_edges(true, false)
		
		var last_not_empty = line(last_line()).strip_edges(false, true)
		while last_not_empty.is_empty() and last_line() - 1 >= first_line():
			_code_editor.select(first_line(), first_column(), last_line() - 1, line(last_line()-1).length())
			last_not_empty = line(last_line()).strip_edges(false, true)
		
		_selected_code = _code_editor.get_selected_text()
		_selected_code_line_start = first_line()
		_selected_code_line_start_column = first_column()
		_selected_code_line_end = last_line()
		_selected_code_line_end_column = last_column()
		_selected_code_first_line = line(_selected_code_line_start)
		_selected_code_last_line = line(_selected_code_line_end)
	return _selected_code


func line(i:int) -> String:
	return _code_editor.get_line(i)


func first_line() -> int:
	return _code_editor.get_selection_from_line()


func first_column() -> int:
	return _code_editor.get_selection_from_column()


func last_line() -> int:
	return _code_editor.get_selection_to_line()


func last_column() -> int:
	return _code_editor.get_selection_to_column()


func forget_selection() -> void:
	_selected_script = null


# Attempts to select the original line range previously used and returns true on success.
func back_to_selection() -> bool:
	if _selected_code.is_empty():
		return false
	
	#double check the script to edit is still open, if it's not, open it
	var curr_script:Script = EditorInterface.get_script_editor().get_current_script()
	if curr_script != _selected_script:
		AIHubPlugin.print_msg("The script for the original request was: %s" % _selected_script.resource_path)
		AIHubPlugin.print_msg("The script currently opened is: %s" % curr_script.resource_path)
		AIHubPlugin.print_msg("AI Assistant Hub: Opening %s" % _selected_script.resource_path)
		EditorInterface.edit_script(_selected_script)
		forget_selection()
	
	var script_editor:= EditorInterface.get_script_editor()
	var code_editor:TextEdit = script_editor.get_current_editor().get_base_editor()
	var curr_selection: String = code_editor.get_selected_text()
	if _selected_code != curr_selection:
		AIHubPlugin.print_msg("AI Assistant Hub: The selection changed. Finding: %s" % _selected_code_first_line)
		var search_start:Vector2i = code_editor.search(_selected_code_first_line, TextEdit.SearchFlags.SEARCH_MATCH_CASE, 0, 0)
		if search_start.x == -1:
			return false
		else:
			AIHubPlugin.print_msg("First line found. Finding: %s" % _selected_code_last_line)
			var original_line_diff = _selected_code_line_end - _selected_code_line_start
			var search_end:Vector2i = code_editor.search(_selected_code_last_line, TextEdit.SearchFlags.SEARCH_MATCH_CASE, search_start.y + original_line_diff, 0)
			if search_end.x == -1:
				return false
			else:
				AIHubPlugin.print_msg("Last line found.")
				var line_diff = search_end.y - search_start.y
				if original_line_diff == line_diff:
					code_editor.select(search_start.y, _selected_code_line_start_column, search_end.y, _selected_code_line_end_column)
				else:
					return false
	return true
