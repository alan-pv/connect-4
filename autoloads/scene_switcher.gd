extends Node
## Switches screens with an iris transition centered on the click.

const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"
const SETUP := "res://scenes/setup/setup_screen.tscn"
const GAME := "res://scenes/game/game.tscn"
const RESULTS := "res://scenes/results/results_screen.tscn"
const ONLINE_MENU := "res://scenes/online_menu/online_menu.tscn"
const ROOM_LOBBY := "res://scenes/room_lobby/room_lobby.tscn"

const IRIS_SHADER := preload("res://assets/shaders/iris.gdshader")

const CLOSE_TIME := 0.5
const OPEN_TIME := 0.5
const SOFTNESS := 0.005
const IRIS_COLOR := Color("121212")

signal transition_started(target_path: String)
signal transition_finished(target_path: String)

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _mat: ShaderMaterial
var _next_origin: Vector2 = Vector2(0.5, 0.5)
var _has_next_origin: bool = false
var _is_switching: bool = false
var _history: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade_overlay()

func _build_fade_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 128
	add_child(_fade_layer)

	_mat = ShaderMaterial.new()
	_mat.shader = IRIS_SHADER
	_mat.set_shader_parameter("softness", SOFTNESS)
	_mat.set_shader_parameter("tint", IRIS_COLOR)

	_fade_rect = ColorRect.new()
	_fade_rect.material = _mat
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE, or the fade rect swallows every click in the game.
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.visible = false
	_fade_layer.add_child(_fade_rect)

# --- Where the iris opens from -----------------------------------------

## Forces the centre of the next iris, in screen pixels. Keyboard and gamepad
## navigation have no cursor to take it from, so they set it by hand.
func set_next_origin(screen_pos: Vector2) -> void:
	var rect := get_viewport().get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return
	_next_origin = screen_pos / rect
	_has_next_origin = true

func _resolve_origin() -> Vector2:
	if _has_next_origin:
		_has_next_origin = false
		return _next_origin
	var rect := get_viewport().get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return Vector2(0.5, 0.5)
	var uv := get_viewport().get_mouse_position() / rect
	# A pointer outside the window is not a place to open the iris from.
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2(0.5, 0.5)
	return uv

## The radius that reaches the furthest corner from a given centre, so the
## closing iris covers the whole screen whichever corner it started near.
func _max_radius(center: Vector2, aspect: float) -> float:
	var best := 0.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var d: float = ((corner - center) * Vector2(aspect, 1.0)).length()
		best = maxf(best, d)
	return best + SOFTNESS * 2.0

func _aspect() -> float:
	var rect := get_viewport().get_visible_rect().size
	return rect.x / maxf(rect.y, 1.0)

# --- The transition -----------------------------------------------------

func _iris(center: Vector2, closing: bool) -> Tween:
	var aspect := _aspect()
	var r_max := _max_radius(center, aspect)

	_mat.set_shader_parameter("center", center)
	_mat.set_shader_parameter("aspect", aspect)
	_mat.set_shader_parameter("radius", r_max if closing else 0.0)

	_fade_rect.visible = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween := create_tween()
	if closing:
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween.tween_property(_mat, "shader_parameter/radius", 0.0, CLOSE_TIME)
	else:
		tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(_mat, "shader_parameter/radius", r_max, OPEN_TIME)
	return tween

## Starts the iris and waits for it. The close is always awaited, and so is
## the reopen on the paths where the scene never loaded.
func _iris_await(center: Vector2, closing: bool) -> void:
	var tween := _iris(center, closing)
	await tween.finished
	if not closing:
		_fade_rect.visible = false
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func go_to(scene_path: String, record_history: bool = true) -> void:
	if _is_switching:
		return
	_is_switching = true
	transition_started.emit(scene_path)

	if record_history:
		var current := get_tree().current_scene
		if current != null and current.scene_file_path != "":
			_history.append(current.scene_file_path)

	var load_error := ResourceLoader.load_threaded_request(scene_path)
	if load_error != OK:
		push_error("Could not start loading %s (error %d)." % [scene_path, load_error])

	var origin := _resolve_origin()
	await _iris_await(origin, true)

	_mat.set_shader_parameter("radius", 0.0)
	await get_tree().process_frame

	var status := ResourceLoader.load_threaded_get_status(scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(scene_path)

	if status != ResourceLoader.THREAD_LOAD_LOADED:
		push_error("Could not load the scene %s (status %d)." % [scene_path, status])
		await _iris_await(origin, false)
		_is_switching = false
		return

	var packed: PackedScene = ResourceLoader.load_threaded_get(scene_path)
	var error := get_tree().change_scene_to_packed(packed)
	if error != OK:
		push_error("Could not switch to the scene %s (error %d)." % [scene_path, error])
		await _iris_await(origin, false)
		_is_switching = false
		return

	var scene := await _await_scene_ready()
	if scene:
		UiIntro.prepare(scene)

	_mat.set_shader_parameter("radius", 0.0)
	await get_tree().process_frame

	# Started but not awaited yet, so the iris opening and the new screen's
	# intro animation run together instead of one after the other.
	var open_tween := _iris(origin, false)
	if scene:
		UiIntro.play()

	await open_tween.finished
	_fade_rect.visible = false
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_is_switching = false
	transition_finished.emit(scene_path)

func go_back() -> void:
	if _history.is_empty():
		go_to(MAIN_MENU, false)
		return
	var previous: String = _history.pop_back()
	go_to(previous, false)

## change_scene_to_packed() is deferred, so wait until current_scene really
## exists instead of assuming one frame is enough.
func _await_scene_ready() -> Node:
	var tries := 0
	while tries < 30:
		var scene := get_tree().current_scene
		if scene != null and is_instance_valid(scene) and scene.is_node_ready():
			return scene
		await get_tree().process_frame
		tries += 1
	push_error("The scene was not ready in time.")
	return null

func clear_history() -> void:
	_history.clear()

func quit_game() -> void:
	await _iris(_resolve_origin(), true)
	get_tree().quit()
