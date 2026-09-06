class_name Board
extends VBoxContainer

## The board on screen: forty-two slots, a row of buttons above them to drop
## into and a row below to pop out of. It knows nothing about turns, rules or
## scores — it translates move codes into things you can watch, and clicks back
## into move codes.
##
##     game.gd -> board.drop(result) / board.pop(result)     something to watch
##     board   -> move_requested(code)                       somebody clicked
##
## Which buttons are live is not decided here either. `show_moves(state)` asks
## the state what is legal and lights exactly those, so the one place that
## knows the rules of Pop Out stays the one place that knows them.
##
## A VBoxContainer rather than a bare Control so the three rows report one
## minimum size upwards: the screen can then simply centre it, and hiding the
## pop row closes the gap it leaves behind instead of stranding it.


## Somebody asked to play a move. Whether they are allowed to is the turn
## loop's business, not this one's.
signal move_requested(code: int)

const SLOT_SIZE := 72
const SEPARATION := 0
const BUTTON_HEIGHT := 42

## Buttons point the way the disc travels.
const DROP_GLYPH := "v"
const POP_GLYPH := "^"

@onready var _drop_row: HBoxContainer = %DropRow
@onready var _pop_row: HBoxContainer = %PopRow
@onready var _grid: GridContainer = %Grid

var _slots: Array[Slot] = []
var _drop_buttons: Array[Button] = []
var _pop_buttons: Array[Button] = []

## Whose disc a hover preview should be drawn in. NONE while nobody is to move.
var _preview_disc: int = Disc.Value.NONE

## The slot a preview is currently showing in, so it can be taken away again
## without searching for it.
var _preview_slot: int = -1


func build() -> void:
	_clear_children()

	_grid.columns = BoardState.COLUMNS
	_grid.add_theme_constant_override("h_separation", SEPARATION)
	_grid.add_theme_constant_override("v_separation", SEPARATION)
	_drop_row.add_theme_constant_override("separation", SEPARATION)
	_pop_row.add_theme_constant_override("separation", SEPARATION)

	for i in BoardState.CELL_COUNT:
		var slot := Slot.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		# add_child BEFORE setup: the nodes a Slot builds do not exist until it
		# is in the tree, and everything after this touches them.
		_grid.add_child(slot)
		slot.setup(i)
		_slots.append(slot)

	for column in BoardState.COLUMNS:
		var drop_button := _build_column_button(DROP_GLYPH, "Drop into column %d" % (column + 1))
		drop_button.pressed.connect(_on_button_pressed.bind(Move.drop_code(column)))
		drop_button.mouse_entered.connect(_on_drop_hovered.bind(column))
		drop_button.mouse_exited.connect(_clear_preview)
		drop_button.focus_entered.connect(_on_drop_hovered.bind(column))
		drop_button.focus_exited.connect(_clear_preview)
		_drop_row.add_child(drop_button)
		_drop_buttons.append(drop_button)

		var pop_button := _build_column_button(POP_GLYPH, "Pop your disc out of column %d" % (column + 1))
		pop_button.pressed.connect(_on_button_pressed.bind(Move.pop_code(column)))
		_pop_row.add_child(pop_button)
		_pop_buttons.append(pop_button)


## Pop Out off means the bottom row of buttons is not disabled but gone: a row
## of controls that can never do anything is a question the player has to keep
## answering for themselves.
func set_pop_out(enabled: bool) -> void:
	_pop_row.visible = enabled


func _build_column_button(glyph: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = glyph
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(SLOT_SIZE, BUTTON_HEIGHT)
	button.focus_mode = Control.FOCUS_NONE
	return button


# ---------------------------------------------------------------------------
# What is on the board
# ---------------------------------------------------------------------------

func get_slot(index: int) -> Slot:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]


## Redraws every slot from a BoardState, with no animation at all. Used between
## rounds and as the way back to a known good picture if anything drifts.
func sync(state_board: BoardState) -> void:
	_clear_preview()
	for i in _slots.size():
		_slots[i].set_disc(state_board.disc_at(i))


func clear_board() -> void:
	_clear_preview()
	for slot in _slots:
		slot.set_disc(Disc.Value.NONE)


# ---------------------------------------------------------------------------
# What can be clicked
# ---------------------------------------------------------------------------

## Nothing at all. Called while a move is being animated and while the bot or
## the other player is thinking.
func set_interactive(value: bool) -> void:
	if not value:
		_preview_disc = Disc.Value.NONE
		_clear_preview()
	for button in _drop_buttons:
		button.disabled = not value
	for button in _pop_buttons:
		button.disabled = not value
	for slot in _slots:
		slot.set_dim(not value)


## Exactly the moves this player has, and nothing else. A pop button that is
## live is a promise that the disc at the bottom of that column is yours.
func show_moves(state: GameState) -> void:
	_preview_disc = state.current_disc()
	for column in BoardState.COLUMNS:
		_drop_buttons[column].disabled = not state.can_play(Move.drop_code(column))
		_pop_buttons[column].disabled = not state.can_play(Move.pop_code(column))
	for slot in _slots:
		slot.set_dim(false)


# ---------------------------------------------------------------------------
# Animation
#
# Both of these are awaited by the turn loop, so the next move cannot be asked
# for until the last one has finished being watched.
# ---------------------------------------------------------------------------

## A disc falling into a column.
func drop(result: MoveResult) -> void:
	var slot := get_slot(result.index)
	if slot == null:
		push_warning("Board: nothing to drop into slot %d." % result.index)
		return
	_clear_preview()
	slot.set_disc(result.disc)
	AudioManager.play_sfx(AudioManager.SFX_DROP)
	await slot.play_drop(BoardState.row_of(result.index))


## A disc leaving from the bottom, and the column collapsing into the gap.
##
## The slots are still showing the board as it was before the pop, which is
## what makes this possible: the colours that have to fall are read off the
## screen rather than recomputed.
func pop(result: MoveResult) -> void:
	var bottom := get_slot(result.index)
	if bottom == null:
		push_warning("Board: nothing to pop out of slot %d." % result.index)
		return
	_clear_preview()

	AudioManager.play_sfx(AudioManager.SFX_POP)
	await bottom.play_pop_out()

	# Read every colour before moving anything: a source slot one row down is
	# somebody else's destination, and half-applied the column would smear.
	var moving: Array[Dictionary] = []
	for from_index in result.fallen:
		var source := get_slot(from_index)
		if source != null:
			moving.append({"to": from_index + BoardState.COLUMNS, "disc": source.disc})
	for from_index in result.fallen:
		var source := get_slot(from_index)
		if source != null:
			source.set_disc(Disc.Value.NONE)

	# They fall together, and only the last one is awaited: a column collapsing
	# one disc at a time would read as six moves instead of one.
	var last: Slot = null
	for entry in moving:
		var target := get_slot(int(entry["to"]))
		if target == null:
			continue
		target.set_disc(int(entry["disc"]))
		last = target
	for entry in moving:
		var target := get_slot(int(entry["to"]))
		if target == null:
			continue
		if target == last:
			await target.play_fall()
		else:
			target.play_fall()


## Lights up every slot of every line that just won. They all start together
## and only the last one is awaited, so the line reads as one gesture.
func highlight(slots: PackedInt32Array) -> void:
	if slots.is_empty():
		return
	for i in slots.size():
		var slot := get_slot(slots[i])
		if slot == null:
			continue
		if i == slots.size() - 1:
			await slot.play_win()
		else:
			slot.play_win()


# ---------------------------------------------------------------------------
# The preview
#
# Where the disc you are about to drop would end up. It is worked out from the
# slots themselves rather than from the state, so the board stays a thing that
# can be looked at without being told anything.
# ---------------------------------------------------------------------------

func _on_drop_hovered(column: int) -> void:
	_clear_preview()
	if _preview_disc == Disc.Value.NONE or _drop_buttons[column].disabled:
		return
	var index := _landing_index(column)
	if index < 0:
		return
	_preview_slot = index
	_slots[index].set_ghost(_preview_disc)


func _clear_preview() -> void:
	if _preview_slot < 0:
		return
	var slot := get_slot(_preview_slot)
	_preview_slot = -1
	if slot != null:
		slot.set_ghost(Disc.Value.NONE)


## The lowest empty slot of a column, read off the board on screen.
func _landing_index(column: int) -> int:
	for row in range(BoardState.ROWS - 1, -1, -1):
		var index := BoardState.index_of(row, column)
		var slot := get_slot(index)
		if slot != null and slot.disc == Disc.Value.NONE:
			return index
	return -1


func _on_button_pressed(code: int) -> void:
	move_requested.emit(code)


func _clear_children() -> void:
	for slot in _slots:
		slot.queue_free()
	for button in _drop_buttons:
		button.queue_free()
	for button in _pop_buttons:
		button.queue_free()
	_slots.clear()
	_drop_buttons.clear()
	_pop_buttons.clear()
	_preview_slot = -1
