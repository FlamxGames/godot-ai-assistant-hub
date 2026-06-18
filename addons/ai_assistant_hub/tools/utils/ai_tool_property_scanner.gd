class_name AIToolPropertyScanner

const OTHER_PROPS_GROUP := "Built-ins"

var properties_details := {}:
	get: return properties_details

var properties_list:PackedStringArray:
	get: return properties_list


var _scene_root:Node
var _obect_to_scan:Object
var _property_filter:String
var _banned_properties:PackedStringArray
var _property_dict_by_name:Dictionary
var _property_types_by_name:Dictionary # Stores the name:VariantType mapping (as opposed to the String representation in the dictionary)


func scan(obect_to_scan: Object, property_filter := "", banned_properties := PackedStringArray()) -> void:
	_scene_root = EditorInterface.get_edited_scene_root()
	_obect_to_scan = obect_to_scan
	_property_filter = property_filter
	_banned_properties = banned_properties
	properties_details = _read_properties_by_class()
	properties_list = _filter_and_parse_to_list(properties_details["Root"])


## This is used to read the results back after edition
func scan_and_get_values_list(obect_to_scan: Object, properties:Array) -> PackedStringArray:
	var values_list:= PackedStringArray()
	scan(obect_to_scan)
	for property in properties:
		if has_property_value(property):
			values_list.append("%s = %s" % [property, str(get_property_value(property))])
	return values_list


func has_property_value(property_name:String) -> bool:
	return _property_dict_by_name.has(property_name) and _property_dict_by_name[property_name].has("value")


func get_property_value(property_name:String) -> Variant:
	return _property_dict_by_name[property_name]["value"]


func get_property_type(property_name:String) -> Variant.Type:
	return _property_types_by_name[property_name]


func is_property_node_object(property_name:String) -> bool:
	var dict:Dictionary = _property_dict_by_name[property_name]
	return dict.get("hint") == "NodeType"


func is_property_resource_object(property_name:String) -> bool:
	var dict:Dictionary = _property_dict_by_name[property_name]
	return dict.get("hint") == "ResourceType"


func _is_banned_property(property_name:String) -> bool:
	for entry in _banned_properties:
		if property_name.match(entry):
			return true
	return false


func _filter_and_parse_to_list(group:Array, level:=0, prop_prefix := "") -> PackedStringArray:
	var list := PackedStringArray()
	var to_filter_out := []
	for dict in group:
		if dict.has("name") and dict["name"] is String:
			#This is a property
			var prop_name:String = "%s%s" % [ prop_prefix, dict["name"] ]
			var keep:= false
			var banned := _is_banned_property(prop_name)
			if not banned and (_property_filter.is_empty() or prop_name.match(_property_filter)):
				keep = true
				_property_dict_by_name[prop_name] = dict
				if dict.has("value"):
					list.append("\t%s = %s" % [prop_name, dict["value"]])
				else:
					list.append("\t%s" % [prop_name])
				if dict.has("resource_properties"):
					var res_children = _filter_and_parse_to_list(dict["resource_properties"], level + 1, "%s." % prop_name)
					if res_children.size() > 0:
						keep = true
						list.append_array(res_children)
			if not keep:
				to_filter_out.append(dict)
		else:
			#This is a group, which is a dictionary with one key
			var group_name:String = dict.keys()[0]
			var children := _filter_and_parse_to_list(dict[group_name], level + 1, prop_prefix)
			if children.size() > 0:
				if level == 0:
					if group_name == OTHER_PROPS_GROUP:
						list.append("# %s" % group_name)
					else:
						list.append("# From class %s" % group_name)
				list.append_array(children)
			else:
				to_filter_out.append(dict)
	for elem in to_filter_out:
		group.erase(elem)
	return list


func _read_properties_by_class() -> Dictionary:
	var current_class := _obect_to_scan.get_class()
	
	# 1. Gather all properties active on the instance
	var full_list := _obect_to_scan.get_property_list()
	
	# 2. Build a trackable map of property names
	var pending_properties := {}
	for prop in full_list:
		pending_properties[prop["name"]] = true
	
	var base_array:Array[Dictionary] = []
	var result := { "Root" = base_array }
	
	# 3. Traverse the Custom Script Inheritance hierarchy first (if present)
	var current_script: Script = _obect_to_scan.get_script()
	while current_script != null:
		var script_name := current_script.get_global_name()
		if script_name.is_empty():
			script_name = current_script.resource_path.get_file() # Fallback to source path if class_name wasn't declared
		var script_props := current_script.get_script_property_list()
		var props := _find_properties(script_name, script_props, pending_properties)
		if props.size() > 0:
			base_array.append(props)
		current_script = current_script.get_base_script()
	
	# 4. Traverse up the native C++ engine inheritance tree
	while not current_class.is_empty():
		var class_props := ClassDB.class_get_property_list(current_class, true)
		var props := _find_properties(current_class, class_props, pending_properties)
		if props.size() > 0:
			base_array.append(props)
		current_class = ClassDB.get_parent_class(current_class)
	
	# 5. Clean up leftovers (e.g. metadata, built-ins like script/script_variables)
	if pending_properties.size() > 0:
		var props := _find_properties(OTHER_PROPS_GROUP, full_list, pending_properties)
		if props.size() > 0:
			base_array.append(props)
					
	return result


func _find_properties(group_name:String, source:Array[Dictionary],
					  pending_properties:Dictionary) -> Dictionary:
	var sections := { # This is a dictionary in order to allow refactoring passing the arrays by reference
		root = [],
		group = [],
		subgroup = [],
		current_section = []
	}
	
	sections.root = []
	sections.current_section = sections.root
	if pending_properties.has(group_name):
		pending_properties.erase(group_name)
	
	var prefix := { group = "", subgroup = "" }
	for prop in source:
		if pending_properties.has(prop["name"]):
			var usage:PropertyUsageFlags = prop["usage"]
			var is_grouping_usage := usage & PROPERTY_USAGE_CATEGORY or usage & PROPERTY_USAGE_GROUP or usage & PROPERTY_USAGE_SUBGROUP
			if is_grouping_usage:
				_read_grouping_property(prop, sections, usage, pending_properties, prefix)
			else:
				_read_regular_property(prop, sections, usage, pending_properties, prefix)
	return { group_name : sections.root }


func _read_grouping_property(prop:Dictionary, sections:Dictionary, usage:PropertyUsageFlags, pending_properties:Dictionary, prefix:Dictionary) -> void:
	var new_target_group = []
	var group_dict := {}
	group_dict[prop["name"]] = new_target_group
	
	if usage & PROPERTY_USAGE_CATEGORY:
		if prop["hint_string"] and not prop["hint_string"].is_empty(): #this indicates this a nested script unnecessary category
			pending_properties.erase(prop["name"])
			return
		sections.group = sections.current_section
		prefix.group = ""
		prefix.subgroup = ""
		sections.root.append(group_dict)
	elif usage & PROPERTY_USAGE_GROUP:
		if prop["hint_string"]:
			prefix.group = str(prop["hint_string"]).split(",", false)[0] #remove potential indentation value
		else:
			prefix.group = ""
		sections.group = new_target_group
		prefix.subgroup = ""
		sections.root.append(group_dict)
	else: #PROPERTY_USAGE_SUBGROUP
		if prop["hint_string"]:
			prefix.subgroup = str(prop["hint_string"]).split(",", false)[0] #remove potential indentation value
		else:
			prefix.subgroup = ""
		sections.subgroup = new_target_group
		sections.group.append(group_dict)
		
	sections.current_section = new_target_group
	pending_properties.erase(prop["name"])


func _read_regular_property(prop:Dictionary, sections:Dictionary, usage:PropertyUsageFlags, pending_properties:Dictionary, prefix:Dictionary) -> void:
	if sections.current_section == sections.subgroup and not prefix.subgroup.is_empty() and not prop["name"].begins_with(prefix.subgroup):
		sections.current_section = sections.group
	if sections.current_section == sections.group and not prefix.group.is_empty() and not prop["name"].begins_with(prefix.group):
		sections.current_section = sections.root
	
	var property := { name = prop["name"] }
	if usage & PROPERTY_USAGE_EDITOR: # The property is exported
		var prop_type:Variant.Type = prop["type"]
		property["type"] = AIToolGodotUtils.get_variant_type_name(prop_type)
		_property_types_by_name[prop["name"]] = prop_type
		
		if prop["class_name"] and not prop["class_name"].is_empty():
			property["class_name"] = prop["class_name"].lstrip("&")
		
		var is_resource = _read_property_value(_obect_to_scan.get(prop["name"]), property, prop_type)
		
		var hint:PropertyHint = prop["hint"]
		if hint != PROPERTY_HINT_NONE:
			property["hint"] = AIToolGodotUtils.get_hint_name(hint)
		
		var hint_string:String = prop["hint_string"]
		if not hint_string.is_empty():
			property["hint_string"] = hint_string
		
		#Append resource properties
		if is_resource and hint == PROPERTY_HINT_RESOURCE_TYPE:
			var res_object:Resource = _obect_to_scan.get(prop["name"])
			if res_object == null:
				var res_path:String = property["value"]
				if ResourceLoader.exists(res_path):
					res_object = ResourceLoader.load(res_path)
			if res_object:
				var res_scanner = AIToolPropertyScanner.new()
				res_scanner.scan(res_object)
				property["resource_properties"] = res_scanner.properties_details["Root"]
				for child_key in res_scanner._property_types_by_name.keys():
					_property_types_by_name["%s:%s" % [prop["name"], child_key]] = res_scanner._property_types_by_name[child_key]
		
		sections.current_section.append(property)
		pending_properties.erase(prop["name"])


## Reads the property and returns true if the value is a resource path
func _read_property_value(value:Variant, property:Dictionary, prop_type:Variant.Type) -> bool:
	if value != null:
		if prop_type == TYPE_OBJECT:
			var the_obect:Object = value
			var _obect_name = the_obect.get("name")
			if _obect_name:
				property["_obect_name"] = _obect_name.lstrip("&")
			property["_obect_class"] = the_obect.get_class()
			if the_obect is Node:
				property["value"] = str(_scene_root.get_path_to(the_obect)).lstrip("^")
			if the_obect is Resource:
				property["value"] = the_obect.resource_path
				return true
		else:
			property["value"] = str(value).lstrip("^").lstrip("&")
	else:
		property["value"] = "<NULL>"
	return false
