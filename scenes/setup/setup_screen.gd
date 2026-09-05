extends Control

## Builds the GameConfig for the next match and parks it in GameSettings.


## The bot difficulties, as data. Drop another .tres in resources/difficulties/
## and add it here; no other file needs to change.
const DIFFICULTY_PATHS := [
	"res://resources/difficulties/easy.tres",
	"res://resources/difficulties/normal.tres",
	"res://resources/difficulties/hard.tres",
]

@onready var _opponent_option: OptionButton = %OpponentOption
@onready var _difficulty_row: Control = %DifficultyRow
@onready var _difficulty_option: OptionButton = %DifficultyOption
@onready var _pop_out_toggle: CheckButton = %PopOutToggle
@onready var _rounds_slider: HSlider = %RoundsSlider
@onready var _rounds_value: Label = %RoundsValue
@onready var _error_label: Label = %ErrorLabel
@onready var _start_button: Button = %StartButton
@onready var _back_button: Button = %BackButton

var _difficulties: Array[DifficultyPreset] = []


func _ready() -> void:
	_load_difficulties()

	_opponent_option.clear()
	_opponent_option.add_item("Against the bot")
	_opponent_option.add_item("Two players, one device")

	_opponent_option.item_selected.connect(func(_i: int) -> void: _refresh())
	_difficulty_option.item_selected.connect(func(_i: int) -> void: _refresh())
	_pop_out_toggle.toggled.connect(func(_on: bool) -> void: _refresh())
	_rounds_slider.value_changed.connect(func(_v: float) -> void: _refresh())
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(func() -> void: SceneSwitcher.go_back())

	_select_last_difficulty()
	_refresh()
	_start_button.grab_focus()


## The whole panel arrives as one piece: a form full of independently bouncing
## rows reads as noise.
func _intro_config() -> Dictionary:
	return {"labels": false, "buttons": true, "panels": false}


func _load_difficulties() -> void:
	_difficulties.clear()
	_difficulty_option.clear()
	for path: String in DIFFICULTY_PATHS:
		var preset := load(path) as DifficultyPreset
		if preset == null:
			push_error("Could not load the difficulty at %s" % path)
			continue
		_difficulties.append(preset)
		_difficulty_option.add_item(preset.display_name)


func _select_last_difficulty() -> void:
	for i in _difficulties.size():
		if _difficulties[i].id == GameSettings.last_difficulty_id:
			_difficulty_option.select(i)
			return


func _selected_difficulty() -> DifficultyPreset:
	var index := _difficulty_option.selected
	if index < 0 or index >= _difficulties.size():
		return null
	return _difficulties[index]


## Hides what does not apply and refuses to start on a configuration the core
## would reject. The rows are wrapped in their own containers because hiding a
## node takes it out of the layout, which is what makes the panel close up.
func _refresh() -> void:
	var against_bot := _opponent_option.selected == 0
	_difficulty_row.visible = against_bot

	_rounds_value.text = str(int(_rounds_slider.value))

	var config := _build_config()
	var error := config.validation_error()
	_error_label.text = error
	_error_label.visible = error != ""
	_start_button.disabled = error != ""


func _build_config() -> GameConfig:
	var config := GameConfig.new()
	var against_bot := _opponent_option.selected == 0

	if against_bot:
		config.opponent = GameConfig.Opponent.BOT
		config.player_names = PackedStringArray(["You", "Bot"])
	else:
		config.opponent = GameConfig.Opponent.HUMAN
		config.player_names = PackedStringArray(["Player 1", "Player 2"])

	config.pop_out = _pop_out_toggle.button_pressed
	config.rounds_to_win = int(_rounds_slider.value)

	var preset := _selected_difficulty()
	if preset != null:
		preset.apply_to(config)
	return config


func _on_start_pressed() -> void:
	var config := _build_config()
	if not config.is_valid():
		_error_label.text = config.validation_error()
		_error_label.visible = true
		return
	GameSettings.last_difficulty_id = config.difficulty_id
	GameSettings.start_new_game(config)
	SceneSwitcher.go_to(SceneSwitcher.GAME)
