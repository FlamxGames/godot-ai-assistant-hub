class_name AIToolGodotUtils

static func get_variant_type_name(variant_type: Variant.Type) -> String:
	match variant_type:
		TYPE_NIL: return "Nil"
		TYPE_BOOL: return "Bool"
		TYPE_INT: return "Int"
		TYPE_FLOAT: return "Float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR2I: return "Vector2i"
		TYPE_RECT2: return "Rect2"
		TYPE_RECT2I: return "Rect2i"
		TYPE_VECTOR3: return "Vector3"
		TYPE_VECTOR3I: return "Vector3i"
		TYPE_TRANSFORM2D: return "Transform2D"
		TYPE_VECTOR4: return "Vector4"
		TYPE_VECTOR4I: return "Vector4i"
		TYPE_PLANE: return "Plane"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_AABB: return "AABB"
		TYPE_BASIS: return "Basis"
		TYPE_TRANSFORM3D: return "Transform3D"
		TYPE_PROJECTION: return "Projection"
		TYPE_COLOR: return "Color"
		TYPE_STRING_NAME: return "StringName"
		TYPE_NODE_PATH: return "NodePath"
		TYPE_RID: return "RID"
		TYPE_OBJECT: return "Object"
		TYPE_CALLABLE: return "Callable"
		TYPE_SIGNAL: return "Signal"
		TYPE_DICTIONARY: return "Dictionary"
		TYPE_ARRAY: return "Array"
		TYPE_PACKED_BYTE_ARRAY: return "PackedByteArray"
		TYPE_PACKED_INT32_ARRAY: return "PackedInt32Array"
		TYPE_PACKED_INT64_ARRAY: return "PackedInt64Array"
		TYPE_PACKED_FLOAT32_ARRAY: return "PackedFloat32Array"
		TYPE_PACKED_FLOAT64_ARRAY: return "PackedFloat64Array"
		TYPE_PACKED_STRING_ARRAY: return "PackedStringArray"
		TYPE_PACKED_VECTOR2_ARRAY: return "PackedVector2Array"
		TYPE_PACKED_VECTOR3_ARRAY: return "PackedVector3Array"
		TYPE_PACKED_COLOR_ARRAY: return "PackedColorArray"
		TYPE_PACKED_VECTOR4_ARRAY: return "PackedVector4Array"
		_: return "Unknown"


static func get_hint_name(hint: PropertyHint) -> String:
	match hint:
		PROPERTY_HINT_NONE: return "None"
		PROPERTY_HINT_RANGE: return "Range"
		PROPERTY_HINT_ENUM: return "Enum"
		PROPERTY_HINT_ENUM_SUGGESTION: return "EnumSuggestion"
		PROPERTY_HINT_EXP_EASING: return "ExpEasing"
		PROPERTY_HINT_LINK: return "Link"
		PROPERTY_HINT_FLAGS: return "Flags"
		PROPERTY_HINT_LAYERS_2D_RENDER: return "Layers2DRender"
		PROPERTY_HINT_LAYERS_2D_PHYSICS: return "Layers2DPhysics"
		PROPERTY_HINT_LAYERS_2D_NAVIGATION: return "Layers2DNavigation"
		PROPERTY_HINT_LAYERS_3D_RENDER: return "Layers3DRender"
		PROPERTY_HINT_LAYERS_3D_PHYSICS: return "Layers3DPhysics"
		PROPERTY_HINT_LAYERS_3D_NAVIGATION: return "Layers3DNavigation"
		PROPERTY_HINT_LAYERS_AVOIDANCE: return "LayersAvoidance"
		PROPERTY_HINT_FILE: return "File"
		PROPERTY_HINT_DIR: return "Dir"
		PROPERTY_HINT_GLOBAL_FILE: return "GlobalFile"
		PROPERTY_HINT_GLOBAL_DIR: return "GlobalDir"
		PROPERTY_HINT_RESOURCE_TYPE: return "ResourceType"
		PROPERTY_HINT_MULTILINE_TEXT: return "MultilineText"
		PROPERTY_HINT_EXPRESSION: return "Expression"
		PROPERTY_HINT_PLACEHOLDER_TEXT: return "PlaceholderText"
		PROPERTY_HINT_COLOR_NO_ALPHA: return "ColorNoAlpha"
		PROPERTY_HINT_OBJECT_ID: return "ObjectId"
		PROPERTY_HINT_TYPE_STRING: return "TypeString"
		PROPERTY_HINT_NODE_PATH_TO_EDITED_NODE: return "NodePathToEditedNode"
		PROPERTY_HINT_OBJECT_TOO_BIG: return "ObjectTooBig"
		PROPERTY_HINT_NODE_PATH_VALID_TYPES: return "NodePathValidTypes"
		PROPERTY_HINT_SAVE_FILE: return "SaveFile"
		PROPERTY_HINT_GLOBAL_SAVE_FILE: return "GlobalSaveFile"
		PROPERTY_HINT_INT_IS_OBJECTID: return "IntIsObjectId"
		PROPERTY_HINT_INT_IS_POINTER: return "IntIsPointer"
		PROPERTY_HINT_ARRAY_TYPE: return "ArrayType"
		PROPERTY_HINT_LOCALE_ID: return "LocaleId"
		PROPERTY_HINT_LOCALIZABLE_STRING: return "LocalizableString"
		PROPERTY_HINT_NODE_TYPE: return "NodeType"
		PROPERTY_HINT_HIDE_QUATERNION_EDIT: return "HideQuaternionEdit"
		PROPERTY_HINT_PASSWORD: return "Password"
		PROPERTY_HINT_MAX: return "Max"
		_: return "Unknown"


# This is not used, but kept for debugging
static func get_usage_flags_name(flags: PropertyUsageFlags) -> String:
	var flag_names := []
	
	if flags & PROPERTY_USAGE_NONE: flag_names.append("None")
	if flags & PROPERTY_USAGE_STORAGE: flag_names.append("Storage")
	if flags & PROPERTY_USAGE_EDITOR: flag_names.append("Editor")
	if flags & PROPERTY_USAGE_INTERNAL: flag_names.append("Internal")
	if flags & PROPERTY_USAGE_CHECKABLE: flag_names.append("Checkable")
	if flags & PROPERTY_USAGE_CHECKED: flag_names.append("Checked")
	if flags & PROPERTY_USAGE_GROUP: flag_names.append("Group")
	if flags & PROPERTY_USAGE_CATEGORY: flag_names.append("Category")
	if flags & PROPERTY_USAGE_SUBGROUP: flag_names.append("Subgroup")
	if flags & PROPERTY_USAGE_CLASS_IS_BITFIELD: flag_names.append("ClassIsBitfield")
	if flags & PROPERTY_USAGE_NO_INSTANCE_STATE: flag_names.append("NoInstanceState")
	if flags & PROPERTY_USAGE_RESTART_IF_CHANGED: flag_names.append("RestartIfChanged")
	if flags & PROPERTY_USAGE_SCRIPT_VARIABLE: flag_names.append("ScriptVariable")
	if flags & PROPERTY_USAGE_STORE_IF_NULL: flag_names.append("StoreIfNull")
	if flags & PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED: flag_names.append("UpdateAllIfModified")
	if flags & PROPERTY_USAGE_CLASS_IS_ENUM: flag_names.append("ClassIsEnum")
	if flags & PROPERTY_USAGE_NIL_IS_VARIANT: flag_names.append("NilIsVariant")
	if flags & PROPERTY_USAGE_ARRAY: flag_names.append("Array")
	if flags & PROPERTY_USAGE_ALWAYS_DUPLICATE: flag_names.append("AlwaysDuplicate")
	if flags & PROPERTY_USAGE_NEVER_DUPLICATE: flag_names.append("NeverDuplicate")
	if flags & PROPERTY_USAGE_HIGH_END_GFX: flag_names.append("HighEndGFX")
	if flags & PROPERTY_USAGE_NODE_PATH_FROM_SCENE_ROOT: flag_names.append("NodePathFromSceneRoot")
	if flags & PROPERTY_USAGE_RESOURCE_NOT_PERSISTENT: flag_names.append("ResourceNotPersistent")
	if flags & PROPERTY_USAGE_KEYING_INCREMENTS: flag_names.append("KeyingIncrements")
	if flags & PROPERTY_USAGE_EDITOR_INSTANTIATE_OBJECT: flag_names.append("EditorInstantiateObject")
	if flags & PROPERTY_USAGE_EDITOR_BASIC_SETTING: flag_names.append("EditorBasicSetting")
	if flags & PROPERTY_USAGE_READ_ONLY: flag_names.append("ReadOnly")
	if flags & PROPERTY_USAGE_SECRET: flag_names.append("Secret")
	if flags & PROPERTY_USAGE_DEFAULT: flag_names.append("Default")
	if flags & PROPERTY_USAGE_NO_EDITOR: flag_names.append("NoEditor")
	
	if flag_names.is_empty():
		return "None"
	
	if flag_names.size() == 1:
		return flag_names[0]
	
	return "|".join(flag_names)
