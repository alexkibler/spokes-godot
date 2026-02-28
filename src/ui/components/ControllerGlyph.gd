extends HBoxContainer
class_name ControllerGlyph

enum ActionType { ACCEPT, CANCEL, START, AUTOPLAY, DPAD, X, Y, RB, LB, LT, RT }
enum ControllerType { XBOX, PLAYSTATION, SWITCH, GENERIC }

@export var action: ActionType = ActionType.ACCEPT
@export var label_text: String = ""

var _icon: TextureRect
var _label: Label

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	set("theme_override_constants/separation", 8)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(32, 32)
	_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(_icon)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	add_child(_label)

	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_update_visuals()

func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_update_visuals()

func _update_visuals() -> void:
	if not is_inside_tree():
		return
	_label.text = label_text
	var path: String = _get_texture_path()
	_icon.texture = load(path) as Texture2D if not path.is_empty() else null

func _get_controller_type() -> ControllerType:
	var joypads: Array[int] = Input.get_connected_joypads()
	if joypads.is_empty():
		return ControllerType.GENERIC
	var joy_name: String = Input.get_joy_name(joypads[0]).to_lower()
	if "xbox" in joy_name or "xinput" in joy_name:
		return ControllerType.XBOX
	if "playstation" in joy_name or "dualshock" in joy_name or "dualsense" in joy_name \
			or "ps4" in joy_name or "ps5" in joy_name or "ps3" in joy_name:
		return ControllerType.PLAYSTATION
	if "nintendo" in joy_name or "switch" in joy_name or "pro controller" in joy_name:
		return ControllerType.SWITCH
	return ControllerType.XBOX  # Generic fallback uses Xbox glyphs

func _get_texture_path() -> String:
	match _get_controller_type():
		ControllerType.PLAYSTATION:
			return _ps_path()
		ControllerType.SWITCH:
			return _switch_path()
		_:
			return _xbox_path()

func _xbox_path() -> String:
	match action:
		ActionType.ACCEPT:          return "res://assets/glyphs/xbox/A.png"
		ActionType.CANCEL:          return "res://assets/glyphs/xbox/B.png"
		ActionType.X:               return "res://assets/glyphs/xbox/X.png"
		ActionType.Y, ActionType.AUTOPLAY: return "res://assets/glyphs/xbox/Y.png"
		ActionType.START:           return "res://assets/glyphs/xbox/Menu.png"
		ActionType.DPAD:            return "res://assets/glyphs/xbox/Dpad.png"
		ActionType.LB:              return "res://assets/glyphs/xbox/LB.png"
		ActionType.RB:              return "res://assets/glyphs/xbox/RB.png"
		ActionType.LT:              return "res://assets/glyphs/xbox/LT.png"
		ActionType.RT:              return "res://assets/glyphs/xbox/RT.png"
	return ""

func _ps_path() -> String:
	match action:
		ActionType.ACCEPT:          return "res://assets/glyphs/ps/Cross.png"
		ActionType.CANCEL:          return "res://assets/glyphs/ps/Circle.png"
		ActionType.X:               return "res://assets/glyphs/ps/Square.png"
		ActionType.Y, ActionType.AUTOPLAY: return "res://assets/glyphs/ps/Triangle.png"
		ActionType.START:           return "res://assets/glyphs/ps/Options.png"
		ActionType.DPAD:            return "res://assets/glyphs/ps/Dpad.png"
		ActionType.LB:              return "res://assets/glyphs/ps/L1.png"
		ActionType.RB:              return "res://assets/glyphs/ps/R1.png"
		ActionType.LT:              return "res://assets/glyphs/ps/L2.png"
		ActionType.RT:              return "res://assets/glyphs/ps/R2.png"
	return ""

func _switch_path() -> String:
	match action:
		ActionType.ACCEPT:          return "res://assets/glyphs/switch/B.png"
		ActionType.CANCEL:          return "res://assets/glyphs/switch/A.png"
		ActionType.X:               return "res://assets/glyphs/switch/Y.png"
		ActionType.Y, ActionType.AUTOPLAY: return "res://assets/glyphs/switch/X.png"
		ActionType.START:           return "res://assets/glyphs/switch/Plus.png"
		ActionType.DPAD:            return "res://assets/glyphs/switch/Dpad.png"
		ActionType.LB:              return "res://assets/glyphs/switch/LB.png"
		ActionType.RB:              return "res://assets/glyphs/switch/RB.png"
		ActionType.LT:              return "res://assets/glyphs/switch/LT.png"
		ActionType.RT:              return "res://assets/glyphs/switch/RT.png"
	return ""
