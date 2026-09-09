class_name PlayerScoreEntry
extends PanelContainer

## One player on the scoreboard: their colour, their name and their rounds.


const SWATCH_SIZE := 22

const ACTIVE_SCALE := 1.06
const IDLE_ALPHA := 0.45
const FADE_TIME := 0.15

@onready var _swatch: Panel = %Swatch
@onready var _name_label: Label = %NameLabel
@onready var _score_label: Label = %ScoreLabel

var is_active: bool = false


func _ready() -> void:
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func setup(player_name: String, color: Color, score: int = 0) -> void:
	_name_label.text = player_name
	set_color(color)
	set_score(score)


## The disc this player drops, drawn as the disc itself: a square with its
## corners rounded to half its side. Its own StyleBoxFlat, or the two entries
## would share one and both end up the same colour.
func set_color(color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(SWATCH_SIZE / 2.0))
	_swatch.add_theme_stylebox_override("panel", box)
	_swatch.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)


func set_score(score: int) -> void:
	_score_label.text = str(score)


func set_active(value: bool, animate: bool = true) -> void:
	if is_active == value and animate:
		return
	is_active = value

	if not animate:
		modulate.a = 1.0 if value else IDLE_ALPHA
		scale = Vector2.ONE * (ACTIVE_SCALE if value else 1.0)
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0 if value else IDLE_ALPHA, FADE_TIME)
	tween.tween_property(self, "scale", Vector2.ONE * (ACTIVE_SCALE if value else 1.0), FADE_TIME)
