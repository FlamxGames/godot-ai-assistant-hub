extends AITool


func execute() -> bool:
	var root = EditorInterface.get_base_control()
	await root.get_tree().process_frame
	EditorInterface.save_all_scenes()
	_success_message = "Saved."
	await root.get_tree().process_frame
	return true
