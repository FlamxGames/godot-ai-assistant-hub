@tool
class_name AIHubStats
extends HTTPRequest

const STATS_URL:= "https://abacus.jasoncameron.dev/hit/godotaihub/"

# If you are extending this plugin adding a new LLM provider API, you DON'T need to extend this
var _api_list = [ "ollama_api", "gemini_api", "jan_api", "ollamaturbo_api", "openrouter_api", "openwebui_api", "xai_api"]
var _versions_list = [ "1.8.3" ]


func gather(apis_used:Dictionary) -> void:
	var plugin_data = ConfigFile.new()
	var err = plugin_data.load(AIHubPlugin.PLUGIN_DATA_PATH)
	if err == Error.OK:
		var plugin_version :String = plugin_data.get_value("general","last_used_version")
		var last_used :int = plugin_data.get_value("general","last_stats_time", 0)
		var curr_time := int(Time.get_unix_time_from_system())
		
		if curr_time - last_used > 72000:
			plugin_data.set_value("general","last_stats_time",int(Time.get_unix_time_from_system()))
			plugin_data.save(AIHubPlugin.PLUGIN_DATA_PATH)
			await _count("start")
			
			if _versions_list.has(plugin_version):
				await _count(plugin_version)
			else:
				await _count("Other version")

			var other_godot_version := true
			var godot_version: Dictionary = Engine.get_version_info()
			if godot_version.major == 4:
				if godot_version.minor >= 0 and godot_version.minor <= 16:
					other_godot_version = false
					await _count("godot_%d.%d" % [godot_version.major, godot_version.minor])
			if other_godot_version:
				await _count("godot_other")
			
			for entry in apis_used.keys():
				if _api_list.has(entry):
					await _count(entry)
				else:
					await _count("Other API")
	else:
		AIHubPlugin.print_err("Error while gathering anonymous usage stats. Please report on GitHub so we can keep the project stable and well‑maintained.\n\tError: Plugin data not found.")


func _count(metric:String) -> void:
	var error := request(STATS_URL + _get_code(metric))
	if error != OK:
		AIHubPlugin.print_err("Error while gathering anonymous usage stats. Please report on GitHub so we can keep the project stable and well‑maintained.\n\tMetric:%s\n\tError: %s" % [metric, error])
	else:
		await request_completed


func _http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != 0 or response_code != 200:
		AIHubPlugin.print_msg("Error while gathering anonymous usage stats. Please report on GitHub so we can keep the project stable and well‑maintained.\nHTTP response:\n\tResult: %d,\n\tResponse Code: %d,\n\tHeaders: %s,\n\tBody: %s" %
			[result, response_code, headers, body.get_string_from_utf8() if body != null else "null"]
		)


func _get_code(metric:String) -> String:
	return metric.sha256_text().substr(10,20)
