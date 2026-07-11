@tool
class_name AIToolUndoQueue

const max_queue_size := 20


class AIToolUndoQueueEntry:
	var tool:AITool
	var execution_id:String
	
	func _init(execution_id:String, tool:AITool) -> void:
		self.execution_id = execution_id
		self.tool = tool
		
	func _to_string() -> String:
		return "[ ID: %s , Tool: %s ]" % [ execution_id, tool.get_function_name() ]


var _queue:Array[AIToolUndoQueueEntry] = []


func add_entry(execution_id:String, tool:AITool) -> void:
	var entry := AIToolUndoQueueEntry.new(execution_id, tool)
	_queue.append(entry)
	if _queue.size() > max_queue_size:
		_queue.pop_front()


func pop_entry(execution_id:String) -> AITool:
	if _queue.size() < 1:
		return null
	var last_entry := _queue[_queue.size() - 1]
	if last_entry.execution_id == execution_id:
		return _queue.pop_back().tool
	return null


func get_queue_string() -> String:
	return str(_queue)
