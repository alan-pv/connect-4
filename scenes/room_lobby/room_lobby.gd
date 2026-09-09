extends Control

## The waiting room: who is here, the match the host is putting together, the
## chat, and the button that freezes it all and sends it to the other player.
##
## Only the host decides anything. What they choose is broadcast as a `setup`
## payload so the guest can see the match they are about to play — a preview and
## nothing more: what gets played is the config that travels with the start.


## The outline of the ready button, and the tag beside a name in the list.
const READY_GREEN := Color(0.24, 0.78, 0.44)

const READY_STATES := ["normal", "hover", "pressed", "focus"]

@onready var _title: Label = %Title
@onready var _code_label: Label = %CodeLabel
@onready var _seat_list: VBoxContainer = %SeatList
@onready var _host_box: VBoxContainer = %HostBox
@onready var _infinite_toggle: CheckButton = %InfiniteToggle
@onready var _rounds_spin: SpinBox = %RoundsSpin
@onready var _summary_label: Label = %SummaryLabel
@onready var _status_label: Label = %StatusLabel
@onready var _leave_button: Button = %LeaveButton
@onready var _ready_button: Button = %ReadyButton
@onready var _start_button: Button = %StartButton

## The match as this client understands it. The host fills it from its own
## controls; the guest from the setup the host sends.
var _pop_out: bool = false
var _marks: int = 3
var _rounds: int = 3

## True from the moment we hand the match over, so a room update arriving during
## the fade cannot send us anywhere else.
var _leaving: bool = false


func _ready() -> void:
	if not Rooms.in_room():
		SceneSwitcher.go_to(SceneSwitcher.ONLINE_MENU, false)
		return

	# The whole chat, in the corner, wired to the relay: three files that have
	# never heard of tic tac toe.
	RoomChat.spawn(self)

	_leave_button.pressed.connect(_on_leave_pressed)
	_ready_button.toggled.connect(_on_ready_toggled)
	_start_button.pressed.connect(_on_start_pressed)
	_infinite_toggle.toggled.connect(func(_on: bool) -> void: _refresh())
	_rounds_spin.value_changed.connect(func(_v: float) -> void: _refresh())

	Rooms.updated.connect(func(_room: Dictionary) -> void: _refresh())
	Rooms.left.connect(_on_room_left)
	Rooms.failed.connect(_on_room_failed)
	Net.payload_received.connect(_on_payload)

	if Rooms.is_host():
		_seed_from_last_match()
	else:
		# Walking in after a match, nothing about the room has changed, so no
		# update is coming to carry the host's settings along with it. Ask.
		Rooms.send({"t": OnlineMatch.T_SETUP, "ask": true})

	_paint_ready_button(false)
	_refresh()


func _intro_config() -> Dictionary:
	return {"labels": false, "buttons": true, "panels": false}


## The match that was just played is the one most likely to be played again.
func _seed_from_last_match() -> void:
	var last := GameSettings.last_online_setup
	# Read once: a room created later starts from the defaults again.
	GameSettings.last_online_setup = {}
	if last.is_empty():
		return
	_infinite_toggle.button_pressed = bool(last.get("pop_out", false))
	_rounds_spin.value = int(last.get("rounds", 3))


# ---------------------------------------------------------------- view


func _refresh() -> void:
	if _leaving or not Rooms.in_room():
		return

	var room := Rooms.current
	var members: Array = room.get("members", [])
	var host := Rooms.is_host()

	_title.text = str(room.get("title", "Room"))
	_code_label.text = "Code %s" % str(room.get("id", "—"))

	if host:
		_pop_out = _infinite_toggle.button_pressed
		_rounds = int(_rounds_spin.value)

	_rebuild_seat_list(members)

	_host_box.visible = host
	_ready_button.visible = not host
	_start_button.visible = host
	_summary_label.text = _summary_text()

	if not host:
		_say("")
		return

	_broadcast_setup()

	var config := _build_config()
	var error := config.validation_error()
	var enough := members.size() >= GameConfig.PLAYER_COUNT
	var everyone_ready := Rooms.everyone_ready()
	_start_button.disabled = not error.is_empty() or not enough or not everyone_ready

	if not error.is_empty():
		_say(error)
	elif not enough:
		_say("Waiting for the other player to join.")
	elif not everyone_ready:
		_say("Waiting for them to be ready.")
	else:
		_say("")


## The same sentence on both screens, so what the host is building is never a
## surprise to the player about to play it.
func _summary_text() -> String:
	var mode := "Pop Out" if _pop_out else "Classic"
	return "%s · first to %d rounds" % [mode, _rounds]


func _rebuild_seat_list(members: Array) -> void:
	for child in _seat_list.get_children():
		child.queue_free()

	var host := Rooms.is_host()
	for member in members:
		var id := int(member.get("id", 0))
		var is_me := id == Net.my_peer_id
		var is_ready: bool = member.get("ready", false)
		var row := _build_seat_row(
			str(member.get("name", "Player")),
			"Host" if member.get("host", false) else ("Ready" if is_ready else "Waiting"),
			is_me,
			READY_GREEN if is_ready else Color("#b2b2b278")
		)
		# Only the host can throw anybody out, and never themselves.
		if host and not is_me:
			row.add_child(_build_kick_button(id, str(member.get("name", "Player"))))
		_seat_list.add_child(row)

	if members.size() < GameConfig.PLAYER_COUNT:
		_seat_list.add_child(_build_seat_row(
			"Empty seat", "Waiting", false, Color("#b2b2b278")
		))


func _build_seat_row(seat_name: String, tag: String, is_me: bool, tag_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = "%s%s" % [seat_name, " (you)" if is_me else ""]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)

	var state := Label.new()
	state.text = tag
	state.add_theme_font_size_override("font_size", 14)
	state.add_theme_color_override("font_color", tag_color)
	row.add_child(state)

	return row


func _build_kick_button(peer_id: int, seat_name: String) -> Button:
	var button := Button.new()
	button.text = "Kick"
	button.tooltip_text = "Remove %s from the room" % seat_name
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(func() -> void: Rooms.kick(peer_id))
	return button


## Green while you are ready. The label is always what pressing it does, so
## "Ready" means "get ready" and it turns into "Not ready" once you are.
func _paint_ready_button(is_ready: bool) -> void:
	_ready_button.text = "Not ready" if is_ready else "Ready"

	for state in READY_STATES:
		if not is_ready:
			_ready_button.remove_theme_stylebox_override(state)
			continue
		var box := _ready_button.get_theme_stylebox(state).duplicate() as StyleBoxFlat
		if box == null:
			continue
		box.border_color = READY_GREEN
		_ready_button.add_theme_stylebox_override(state, box)

	if is_ready:
		_ready_button.add_theme_color_override("font_pressed_color", READY_GREEN)
		_ready_button.add_theme_color_override("font_hover_pressed_color", READY_GREEN)
	else:
		_ready_button.remove_theme_color_override("font_pressed_color")
		_ready_button.remove_theme_color_override("font_hover_pressed_color")


func _say(text: String) -> void:
	_status_label.text = text


# ---------------------------------------------------------------- the match


## Builds the match from the room: the two people in join order. Every seat
## carries the peer that owns it, which is what lets the referee tell a legal
## move from somebody playing out of turn.
func _build_config() -> GameConfig:
	var config := GameConfig.new()
	config.opponent = GameConfig.Opponent.HUMAN
	config.online = true

	var names := PackedStringArray()
	var peers := PackedInt32Array()
	for member in Rooms.members():
		names.append(str(member.get("name", "Player")))
		peers.append(int(member.get("id", 0)))
	while names.size() < GameConfig.PLAYER_COUNT:
		names.append("Player %d" % (names.size() + 1))
		peers.append(0)
	config.player_names = names
	config.peer_ids = peers

	config.pop_out = _pop_out
	config.rounds_to_win = _rounds
	return config


## Host -> everyone: the match as it stands. Sent on every change and on every
## room update, so somebody who just walked in sees it without having to ask.
func _broadcast_setup() -> void:
	Rooms.send({
		"t": OnlineMatch.T_SETUP,
		"pop_out": _pop_out,
		"marks": _marks,
		"rounds": _rounds,
	})


func _on_start_pressed() -> void:
	if not Rooms.is_host():
		return
	var config := _build_config()
	if not config.is_valid():
		_say(config.validation_error())
		return

	_leaving = true
	# The payload first, so it is on its way before the room closes to newcomers.
	OnlineMatch.broadcast_start(config)
	Rooms.start_match()
	SceneSwitcher.go_to(SceneSwitcher.GAME, false)


func _on_payload(from_id: int, payload: Dictionary) -> void:
	if _leaving:
		return
	var kind := str(payload.get("t", ""))
	var asking := bool(payload.get("ask", false))

	# The one thing the host listens for: somebody arriving and asking what is
	# on the table. Everything else in the lobby travels host -> everyone.
	if Rooms.is_host():
		if kind == OnlineMatch.T_SETUP and asking:
			_broadcast_setup()
		return

	if from_id != Rooms.host_id() or asking:
		return

	match kind:
		OnlineMatch.T_SETUP:
			_pop_out = bool(payload.get("pop_out", false))
			_marks = clampi(int(payload.get("marks", 3)), 2, 4)
			_rounds = clampi(int(payload.get("rounds", 3)), 1, 9)
			_infinite_toggle.button_pressed = _pop_out
			_rounds_spin.value = _rounds
			_refresh()
		OnlineMatch.T_START:
			if not OnlineMatch.accept_start(payload):
				_say("The host started a match this build cannot play.")
				return
			_leaving = true
			SceneSwitcher.go_to(SceneSwitcher.GAME, false)


func _on_ready_toggled(value: bool) -> void:
	_paint_ready_button(value)
	Rooms.set_ready(value)


func _on_leave_pressed() -> void:
	_leaving = true
	Rooms.leave()
	SceneSwitcher.go_to(SceneSwitcher.ONLINE_MENU, false)


## Being thrown out arrives here exactly like the room closing: the reason is
## the only difference, and the online menu shows it.
func _on_room_left(_reason: String) -> void:
	if _leaving:
		return
	_leaving = true
	SceneSwitcher.go_to(SceneSwitcher.ONLINE_MENU, false)


func _on_room_failed(_code: String, message: String) -> void:
	_say(message)
