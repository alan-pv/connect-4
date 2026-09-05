class_name Slot
extends Control

## One hole in the board. It owns nothing and decides nothing: the disc drawn
## here is a copy of what BoardState holds, never a second source of truth.
##
## The whole thing is two rounded rectangles and no art at all. The slot itself
## is a square of board colour; the disc inside it is a square with its corners
## rounded to half its side, which is a circle. An empty hole is that same
## circle painted the colour of the background, so the board reads as a sheet
## with holes punched in it rather than as a grid with gaps.
##
## Two things move independently, so they each get their own channel and never
## fight over one another:
##
##   %Pivot     where the disc is, which is how falling is drawn
##   %Disc      what colour it is and how big, which is how landing is drawn


const COLOR_RED := Color("e5484d")
const COLOR_YELLOW := Color("f5c518")

## The hole with nothing in it: the same colour as the screen behind the board.
const COLOR_EMPTY := Color("121212")

## The sheet the holes are punched in.
const COLOR_BOARD := Color("24306b")

## A disc that is part of a line that just won.
const COLOR_WIN_RING := Color("ffffff")

## How faint the preview of the disc you are about to drop is.
const GHOST_ALPHA := 0.35

## How dim the board goes while it is not taking clicks.
const DIM := Color(0.62, 0.62, 0.62, 1.0)

## How far, as a fraction of the slot, the disc sits in from the edge.
const INSET := 0.14

const DROP_TIME_PER_ROW := 0.055
const DROP_MIN_TIME := 0.16
const POP_TIME := 0.26
const FALL_TIME := 0.22
const WIN_TIME := 0.22
const DIM_TIME := 0.2

var index: int = -1

var disc: int = Disc.Value.NONE

## Set while a preview is showing. It is not a disc: nothing about the game
## knows it exists, and the next set_disc() wipes it.
var _ghost: int = Disc.Value.NONE

var _pivot: Control
var _disc_panel: Panel
var _disc_box: StyleBoxFlat
var _frame_box: StyleBoxFlat
var _frame: Panel

var _anim: Tween
var _move: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	resized.connect(_layout)
	_layout()
	_repaint()


func setup(p_index: int) -> void:
	index = p_index


# ---------------------------------------------------------------------------
# Building
#
# In code rather than in the scene: forty-two of these are made at runtime, and
# a StyleBoxFlat shared between them would let one slot repaint every other.
# ---------------------------------------------------------------------------

func _build() -> void:
	_frame_box = StyleBoxFlat.new()
	_frame_box.bg_color = COLOR_BOARD
	_frame = Panel.new()
	_frame.add_theme_stylebox_override("panel", _frame_box)
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)

	# The disc lives in its own node so that falling (the pivot's position) and
	# landing (the disc's scale) can run as two tweens without cancelling one
	# another out.
	_pivot = Control.new()
	_pivot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pivot)

	_disc_box = StyleBoxFlat.new()
	_disc_box.bg_color = COLOR_EMPTY
	_disc_panel = Panel.new()
	_disc_panel.add_theme_stylebox_override("panel", _disc_box)
	_disc_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pivot.add_child(_disc_panel)


## Rounded to half the side is a circle, and the side changes with the window,
## so both are worked out again every time the slot is resized.
func _layout() -> void:
	var inset := size.x * INSET
	var side := maxf(size.x - inset * 2.0, 1.0)

	_pivot.position = Vector2.ZERO
	_pivot.size = size

	_disc_panel.position = Vector2(inset, inset)
	_disc_panel.size = Vector2(side, side)
	_disc_panel.pivot_offset = Vector2(side, side) * 0.5
	_disc_box.set_corner_radius_all(int(side / 2.0))


## How far the disc has to travel to cross one row.
func pitch() -> float:
	return size.y


# ---------------------------------------------------------------------------
# What is in the hole
# ---------------------------------------------------------------------------

func set_disc(value: int) -> void:
	disc = value
	_ghost = Disc.Value.NONE
	_reset_channels()
	_repaint()


## The disc you would get if you dropped one here: the same colour, faint. Pass
## NONE to take it away again.
func set_ghost(value: int) -> void:
	if disc != Disc.Value.NONE:
		return
	_ghost = value
	_repaint()


static func color_for(value: int) -> Color:
	match value:
		Disc.Value.RED:
			return COLOR_RED
		Disc.Value.YELLOW:
			return COLOR_YELLOW
		_:
			return COLOR_EMPTY


func _repaint() -> void:
	if _disc_box == null:
		return
	if disc != Disc.Value.NONE:
		_disc_box.bg_color = color_for(disc)
		_disc_box.set_border_width_all(0)
		return
	if _ghost != Disc.Value.NONE:
		_disc_box.bg_color = color_for(_ghost).lerp(COLOR_EMPTY, 1.0 - GHOST_ALPHA)
		_disc_box.set_border_width_all(0)
		return
	_disc_box.bg_color = COLOR_EMPTY
	_disc_box.set_border_width_all(0)


# ---------------------------------------------------------------------------
# Animation
#
# Every one of these is awaited by the board, which is awaited by the turn
# loop, so a move is not over until it has finished being watched.
# ---------------------------------------------------------------------------

## The disc arriving from above. `rows` is how many rows it fell through, so a
## disc into an empty column takes visibly longer than one onto a full pile.
func play_drop(rows: int) -> void:
	if _pivot == null:
		return
	var distance := pitch() * float(rows + 1)
	var seconds := maxf(DROP_MIN_TIME, DROP_TIME_PER_ROW * float(rows + 1))

	_kill(_move)
	_pivot.position.y = -distance
	_move = create_tween()
	# Falling speeds up on the way down and stops dead, the way a disc hitting
	# a pile does. BOUNCE would have it climb back out of the slot.
	_move.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_move.tween_property(_pivot, "position:y", 0.0, seconds)
	await _move.finished
	_squash()


## The disc being pulled out from underneath. It drops out of the bottom of the
## board and shrinks away; the slot is left empty.
func play_pop_out() -> void:
	if _pivot == null or disc == Disc.Value.NONE:
		return
	_kill(_move)
	_kill(_anim)
	_move = create_tween().set_parallel(true)
	_move.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_move.tween_property(_pivot, "position:y", pitch() * 0.9, POP_TIME)
	_move.tween_property(_disc_panel, "scale", Vector2(0.4, 0.4), POP_TIME)
	_move.tween_property(_disc_panel, "modulate:a", 0.0, POP_TIME)
	await _move.finished
	set_disc(Disc.Value.NONE)


## This disc has just moved down one row because the column collapsed under it.
## Set the colour first, then call this: it starts a row high and settles.
func play_fall() -> void:
	if _pivot == null:
		return
	_kill(_move)
	_pivot.position.y = -pitch()
	_move = create_tween()
	_move.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_move.tween_property(_pivot, "position:y", 0.0, FALL_TIME)
	await _move.finished


## Part of a line that just won. The ring stays until the board is cleared.
func play_win() -> void:
	if _disc_panel == null:
		return
	_kill(_anim)
	_anim = create_tween()
	_anim.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim.tween_property(_disc_panel, "scale", Vector2(1.18, 1.18), WIN_TIME)
	_anim.parallel().tween_method(_ring, 0.0, 1.0, WIN_TIME)
	_anim.tween_property(_disc_panel, "scale", Vector2.ONE, WIN_TIME * 0.7)
	await _anim.finished


## How lit the whole slot is, on a tween of its own so it never fights the
## disc's. self_modulate and not modulate: this is the slot, not the disc.
func set_dim(value: bool) -> void:
	var target := DIM if value else Color.WHITE
	if self_modulate.is_equal_approx(target):
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "self_modulate", target, DIM_TIME)


func _ring(amount: float) -> void:
	if _disc_box == null:
		return
	_disc_box.border_color = COLOR_WIN_RING
	_disc_box.set_border_width_all(roundi(amount * maxf(size.x * 0.07, 2.0)))


## A landing disc squashes and comes back. Small enough to be felt rather than
## seen, which is the point: it happens on every single turn.
func _squash() -> void:
	_kill(_anim)
	_anim = create_tween()
	_anim.set_trans(Tween.TRANS_QUAD)
	_anim.tween_property(_disc_panel, "scale", Vector2(1.12, 0.88), 0.06)
	_anim.tween_property(_disc_panel, "scale", Vector2.ONE, 0.12)
	await _anim.finished


## Puts the disc back where a fresh slot would have it. Called whenever the
## contents change, so an animation interrupted halfway never leaves a disc
## floating between two rows.
func _reset_channels() -> void:
	_kill(_anim)
	_kill(_move)
	if _pivot == null:
		return
	_pivot.position = Vector2.ZERO
	_disc_panel.scale = Vector2.ONE
	_disc_panel.modulate.a = 1.0
	_disc_box.set_border_width_all(0)


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
