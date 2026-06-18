class_name AIToolValueParser

const ERROR_VALUE := "ERROR_VALUE"

var _errors:= PackedStringArray()
var _target_object:Object
var _created_resources:Dictionary # property name : resource object


func _init(target:Object) -> void:
	_target_object = target


func get_errors() -> PackedStringArray:
	return _errors


func get_created_resources() -> Dictionary:
	return _created_resources


func parse_prop_value_map(root_node:Node, prop_value_map:Dictionary, do_values_map:Dictionary, undo_values_map:Dictionary) -> bool:
	_errors.clear()
	var node_scanner := AIToolPropertyScanner.new()
	node_scanner.scan(_target_object)
	for property in prop_value_map.keys(): # property name : value
		if not property.contains("."): # skip embedded resource properties, another parser object is required for those
			if node_scanner.has_property_value(property):
				var type := node_scanner.get_property_type(property)
				var old_value = _target_object.get(property)
				undo_values_map[property] = old_value # for undo tool
				if str(prop_value_map[property]) == "<NULL>":
					do_values_map[property] = null
				else:
					if type == TYPE_OBJECT and (node_scanner.is_property_node_object(property) or node_scanner.is_property_resource_object(property)):
						if node_scanner.is_property_node_object(property):
							var path:String = prop_value_map[property]
							if not root_node.has_node(path):
								_errors.append("Node '%s' not found in scene." % path)
								return false
							do_values_map[property] = root_node.get_node(path)
						else: #if node_scanner.is_property_resource_object(property):
							var res:Resource
							var value:String = prop_value_map[property]
							if value.begins_with("NEW:"):
								var res_class := value.lstrip("NEW:").strip_edges()
								res = _create_new_resource(res_class)
								_created_resources[property] = res
							else:
								res = ResourceLoader.load(value)
							if res == null:
								_errors.append("Resource '%s' could not be created or loaded." % value)
								return false
							do_values_map[property] = res
					else:
						var value = _parse_variant_from_string(prop_value_map[property], type)
						if value is String and value == AIToolValueParser.ERROR_VALUE:
							_errors.append("Value [ %s ] could not be parsed to the type of property %s." % [ prop_value_map[property], property])
							return false
						do_values_map[property] = value
			else:
				_errors.append("It does not contain property %s." % property)
				return false
	return true


# Tries to create a value of the correct type based on the provided value string and type
func _parse_variant_from_string(value_string: String, target_type: Variant.Type) -> Variant:
	match target_type:
		TYPE_BOOL:
			if value_string.to_lower() == "true":
				return true
			if value_string.to_lower() == "false":
				return false
				
		TYPE_INT:
			if value_string.is_valid_int():
				return int(value_string)
				
		TYPE_FLOAT:
			if value_string.is_valid_float():
				return float(value_string)
				
		TYPE_STRING:
			return value_string
		
		TYPE_VECTOR2: 
			var parts := _get_comma_separated_values(value_string)
			if parts.size() == 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
				return Vector2(float(parts[0]), float(parts[1]))
				
		TYPE_VECTOR2I: 
			var parts := _get_comma_separated_values(value_string)
			if _validate_int_parts(parts, 2):
				return Vector2i(int(parts[0]), int(parts[1]))
				
		TYPE_RECT2, TYPE_RECT2I: 
			var data := _parse_bracketed_format(value_string)
			if data.has("P") and data.has("S"):
				return Rect2(data["P"][0], data["P"][1], data["S"][0], data["S"][1])
				
		TYPE_VECTOR3: 
			var parts := _get_comma_separated_values(value_string)
			if _validate_float_parts(parts, 3):
				return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
				
		TYPE_VECTOR3I: 
			var parts := _get_comma_separated_values(value_string)
			if _validate_int_parts(parts, 3):
				return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
				
		TYPE_TRANSFORM2D: 
			var data := _parse_bracketed_format(value_string)
			if data.has("X") and data.has("Y") and data.has("O") and data.size() == 3:
				return Transform2D(Vector2(data["X"][0], data["X"][1]),
								Vector2(data["Y"][0], data["Y"][1]),
								Vector2(data["O"][0], data["O"][1]))
								
		TYPE_VECTOR4: 
			var parts := _get_comma_separated_values(value_string)
			if _validate_float_parts(parts, 4):
				return Vector4(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
			
		TYPE_VECTOR4I: 
			var parts := _get_comma_separated_values(value_string)
			if _validate_int_parts(parts, 4):
				return Vector4i(int(parts[0]), int(parts[1]), int(parts[2]), int(parts[3]))
		
		TYPE_PLANE:
			var data := _parse_bracketed_format(value_string)
			if data.has("N") and data.has("D") and data.size() == 2:
				return Plane(Vector3(data["N"][0], data["N"][1], data["N"][2]), data["D"][0])
			
		TYPE_QUATERNION: 
			var parts := _get_comma_separated_values(value_string)
			if _validate_float_parts(parts, 4):
				return Quaternion(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
				
		TYPE_AABB: 
			var data := _parse_bracketed_format(value_string)
			if data.has("P") and data.has("S") and data.size() == 2:
				return AABB(Vector3(data["P"][0], data["P"][1], data["P"][2]), Vector3(data["S"][0], data["S"][1], data["S"][2]))
			
		TYPE_BASIS: 
			var data := _parse_bracketed_format(value_string)
			if data.has("X") and data.has("Y") and data.has("Z") and data.size() == 3:
				return Basis(Vector3(data["X"][0], data["X"][1], data["X"][2]),
						Vector3(data["Y"][0], data["Y"][1], data["Y"][2]),
						Vector3(data["Z"][0], data["Z"][1], data["Z"][2]))
			
		TYPE_TRANSFORM3D: 
			var data := _parse_bracketed_format(value_string)
			if data.has("X") and data.has("Y") and data.has("Z") and data.has("O") and data.size() == 4:
				return Transform3D(Vector3(data["X"][0], data["X"][1], data["X"][2]),
						Vector3(data["Y"][0], data["Y"][1], data["Y"][2]),
						Vector3(data["Z"][0], data["Z"][1], data["Z"][2]),
						Vector3(data["O"][0], data["O"][1], data["O"][2]))
			
		TYPE_PROJECTION: 
			value_string = value_string.replace("\n",",")
			var parts := _get_comma_separated_values(value_string)
			if parts.size() == 16:
				return Projection(
					Vector4(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3])),
					Vector4(float(parts[4]), float(parts[5]), float(parts[6]), float(parts[7])),
					Vector4(float(parts[8]), float(parts[9]), float(parts[10]), float(parts[11])),
					Vector4(float(parts[12]), float(parts[13]), float(parts[14]), float(parts[15])))
					
		TYPE_COLOR: 
			var parts := _get_comma_separated_values(value_string)
			if _validate_float_parts(parts, 4):
				return Color(float(parts[0]), float(parts[1]), float(parts[2]), float(parts[3]))
			
		TYPE_STRING_NAME: 
			return StringName(value_string)
			
		TYPE_NODE_PATH: 
			return NodePath(value_string)
			
		TYPE_DICTIONARY: 
			#This only supports limited types of dictionaries, is there a better way?
			var json := JSON.new()
			var error := json.parse(value_string)
			if error == OK and json.data is Dictionary:
				return json.data
		
		TYPE_ARRAY: 
			var json := JSON.new()
			var error := json.parse(value_string)
			if error == OK and json.data is Array:
				return json.data
			
		TYPE_PACKED_BYTE_ARRAY: 
			var json := JSON.new()
			var error := json.parse(value_string)
			if error == OK and json.data is Array:
				var arr := PackedByteArray()
				for item in json.data:
					if item is int or item is float:
						arr.append(int(item))
				if arr.size() == json.data.size():
					return arr
		
		TYPE_PACKED_INT32_ARRAY: 
			var json := JSON.new()
			var error := json.parse(value_string)
			if error == OK and json.data is Array:
				var arr := PackedInt32Array()
				for item in json.data:
					if item is int or item is float:
						arr.append(int(item))
				if arr.size() == json.data.size():
					return arr
		
		TYPE_PACKED_INT64_ARRAY: 
			var json := JSON.new()
			var error := json.parse(value_string)
			if error == OK and json.data is Array:
				var arr := PackedInt64Array()
				for item in json.data:
					if item is int or item is float:
						arr.append(int(item))
				if arr.size() == json.data.size():
					return arr
		
		TYPE_PACKED_FLOAT32_ARRAY: 
			var json := JSON.new()
			var error := json.parse(value_string)
			if error == OK and json.data is Array:
				var arr := PackedFloat32Array()
				for item in json.data:
					if item is int or item is float:
						arr.append(float(item))
				if arr.size() == json.data.size():
					return arr
		
		TYPE_PACKED_FLOAT64_ARRAY: 
			var json := JSON.new()
			var error := json.parse(value_string)
			if error == OK and json.data is Array:
				var arr := PackedFloat64Array()
				for item in json.data:
					if item is int or item is float:
						arr.append(float(item))
				if arr.size() == json.data.size():
					return arr

		TYPE_PACKED_STRING_ARRAY: 
			var json := JSON.new()
			var error := json.parse(value_string)
			if error == OK and json.data is Array:
				var arr := PackedStringArray()
				for item in json.data:
					if item is String:
						arr.append(str(item))
				if arr.size() == json.data.size():
					return arr
		
		TYPE_PACKED_VECTOR2_ARRAY: 
			var arr := _parse_array_of_vectors(value_string, func(x, y): return Vector2(x, y))
			if arr.size() > 0:
				return arr
		
		TYPE_PACKED_VECTOR3_ARRAY: 
			var arr := _parse_array_of_vectors(value_string, func(x, y, z): return Vector3(x, y, z))
			if arr.size() > 0:
				return arr
		
		TYPE_PACKED_COLOR_ARRAY: 
			var arr := _parse_array_of_vectors(value_string, func(r, g, b, a): return Color(r, g, b, a))
			if arr.size() > 0:
				return arr
		
		TYPE_PACKED_VECTOR4_ARRAY: 
			var arr := _parse_array_of_vectors(value_string, func(x, y, z, w): return Vector4(x, y, z, w))
			if arr.size() > 0:
				return arr
			
	return ERROR_VALUE


func _create_new_resource(res_class:String) -> Resource:
	var dynamic_class_loader := GDScript.new()
	dynamic_class_loader.set_source_code("static func eval(): return " + res_class)
	var error := dynamic_class_loader.reload()
	if error != OK:
		_errors.append("Failed to load class: %s. Error: %s" % [res_class, error_string(error)])
		return null
	# Instantiate the resource
	var res = dynamic_class_loader.eval().new()
	if not (res is Resource):
		_errors.append("%s is not a valid Resource class." % res_class)
		return null
	return res


func _validate_float_parts(parts:PackedStringArray, expected_count:int) -> bool:
	if parts.size() != expected_count:
		return false
	for part in parts:
		if not part.is_valid_float():
			return false
	return true


func _validate_int_parts(parts:PackedStringArray, expected_count:int) -> bool:
	if parts.size() != expected_count:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
	return true


func _get_comma_separated_values(value_string: String) -> PackedStringArray:
	var arr := value_string.strip_edges().trim_prefix("[").trim_suffix("]").trim_prefix("(").trim_suffix(")").split(",")
	for i in arr.size():
		arr[i] = arr[i].strip_edges()
	return arr


func _parse_bracketed_format(value_string: String) -> Dictionary:
	# Parse format: [P: (x, y), S: (w, h)], [N: (1.1, 2.1, 3.1), D: 4.1], etc.
	# Returns dictionary with letter keys and array of numbers as values
	value_string = value_string.lstrip("[").rstrip("]").strip_edges()
	#replace internal vector commas with pipes
	var replacing_commas:= false
	for i in value_string.length():
		if value_string[i] == "(":
			replacing_commas = true
		if value_string[i] == ")":
			replacing_commas = false
		if replacing_commas and value_string[i] == ",":
			value_string[i] = "|"
	
	var result := Dictionary()
	var lines := value_string.split(",")
	
	for line in lines:
		line = line.strip_edges()
		if line.is_empty():
			continue
		var parts := line.split(":")
		if parts.size() >= 2:
			var key := parts[0].strip_edges()
			var value_part := parts[1].strip_edges()
			
			var coords_array := []
			var coords_str := value_part.lstrip("(").rstrip(")")
			var coords := coords_str.split("|")
			for coord in coords:
				coord = coord.strip_edges()
				if coord.is_valid_float() or coord.is_valid_int():
					coords_array.append(float(coord) if coord.is_valid_float() else int(coord))
			
			result[key] = coords_array
	return result

func _parse_array_of_vectors(value_string: String, vector_constructor: Callable) -> Array:
	# Parse format: [(2, 5), (4, 10)] or similar arrays of vectors
	# Returns array of Vector2/Vector3/Vector4 or ERROR_VALUE if invalid
	value_string = value_string.lstrip("[").rstrip("]").strip_edges()
	var replacing_commas := false
	var components := []
	
	for i in value_string.length():
		if value_string[i] == "(":
			replacing_commas = true
		if value_string[i] == ")":
			replacing_commas = false
		if replacing_commas and value_string[i] == ",":
			value_string[i] = "|"
	
	var arr := []
	var lines := value_string.split(",")
	for line in lines:
		line = line.strip_edges().lstrip("(").rstrip(")")
		if line.is_empty():
			continue
		var coords_str := line
		var coords := coords_str.split("|")
		for coord in coords:
			coord = coord.strip_edges()
			if coord.is_valid_float() or coord.is_valid_int():
				components.append(float(coord) if coord.is_valid_float() else int(coord))
		
		if components.size() > 0:
			arr.append(vector_constructor.callv(components))
			components = []
	
	return arr
