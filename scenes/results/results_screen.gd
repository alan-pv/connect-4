extends Control

## Reads GameSettings.last_result and shows how the match went.


@onready var _title_label: Label = %TitleLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _again_button: Button = %AgainButton
@onready var _setup_button: Button = %SetupButton
@onready var _menu_button: Button = %MenuButton

var _was_online: bool = false


func _ready() -> void:
	_was_online = GameSettings.config != null and GameSettings.config.online

	_again_button.pressed.connect(func() -> void: SceneSwitcher.go_to(SceneSwitcher.GAME, false))
	_setup_button.pressed.connect(_on_setup_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)

	_show_result()

	# "Play again" would start a local match with the seats of an online one,
	# and the other player is not here to be asked. Online the rematch is agreed
	# on back in the room, which the referee reopened as the match ended.
	_again_button.visible = not _was_online
	if _was_online:
		Rooms.left.connect(func(_reason: String) -> void: _label_return_button())
		if Rooms.in_room():
			RoomChat.spawn(self, false)
		_label_return_button()
		_setup_button.grab_focus()
	else:
		_again_button.grab_focus()


func _intro_config() -> Dictionary:
	return {"labels": true, "buttons": true, "panels": false}


## The room usually outlives the match, and then this is the way back into it.
func _label_return_button() -> void:
	_setup_button.text = "Back to the room" if Rooms.in_room() else "Back to the rooms"


func _show_result() -> void:
	var result := GameSettings.last_result
	if result.is_empty():
		_title_label.text = "No match yet"
		_score_label.text = ""
		_detail_label.text = ""
		return

	var names: PackedStringArray = result.get("names", PackedStringArray(["Player 1", "Player 2"]))
	var scores: Array = result.get("scores", [0, 0])
	var winner: int = result.get("winner", -1)

	if winner < 0:
		_title_label.text = "Level"
	else:
		_title_label.text = "%s wins" % names[winner]

	_score_label.text = "%s  %d  -  %d  %s" % [names[0], scores[0], scores[1], names[1]]

	var rounds: int = result.get("rounds_played", 0)
	var seconds: float = result.get("seconds", 0.0)
	_detail_label.text = "%d rounds  -  %02d:%02d" % [rounds, int(seconds) / 60, int(seconds) % 60]


func _on_setup_pressed() -> void:
	if _was_online:
		SceneSwitcher.go_to(
			SceneSwitcher.ROOM_LOBBY if Rooms.in_room() else SceneSwitcher.ONLINE_MENU, false
		)
		return
	SceneSwitcher.go_to(SceneSwitcher.SETUP, false)


func _on_menu_pressed() -> void:
	if _was_online:
		Rooms.leave()
		Net.disconnect_from_server()
	SceneSwitcher.go_to(SceneSwitcher.MAIN_MENU, false)
