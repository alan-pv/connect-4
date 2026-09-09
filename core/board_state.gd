class_name BoardState
extends RefCounted

## The seven by six grid and the gravity that holds it together.


const COLUMNS := 7
const ROWS := 6
const CELL_COUNT := COLUMNS * ROWS

## One Disc.Value per slot, CELL_COUNT of them.
var cells: Array[int] = []


func _init() -> void:
	reset()


## Empties the whole grid.
func reset() -> void:
	cells.resize(CELL_COUNT)
	cells.fill(Disc.Value.NONE)


# Coordinates
# ---------------------------------------------------------------------------

static func is_inside(index: int) -> bool:
	return index >= 0 and index < CELL_COUNT


static func is_column(column: int) -> bool:
	return column >= 0 and column < COLUMNS


static func index_of(row: int, column: int) -> int:
	return row * COLUMNS + column


static func row_of(index: int) -> int:
	return index / COLUMNS


static func column_of(index: int) -> int:
	return index % COLUMNS


static func top_index(column: int) -> int:
	return index_of(0, column)


static func bottom_index(column: int) -> int:
	return index_of(ROWS - 1, column)


## Every slot of a column, top first. The order matters: a pop walks it from
## the bottom up, and the board animates it from the top down.
static func column_indices(column: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not is_column(column):
		return out
	for row in ROWS:
		out.append(index_of(row, column))
	return out


# Reading
# ---------------------------------------------------------------------------

## What is sitting in a slot. Never crashes: the bot reads indices it computed.
func disc_at(index: int) -> int:
	return cells[index] if is_inside(index) else Disc.Value.NONE


func is_free(index: int) -> bool:
	return is_inside(index) and cells[index] == Disc.Value.NONE


## How many discs are stacked in a column, 0 to ROWS.
func height_of(column: int) -> int:
	if not is_column(column):
		return 0
	var height := 0
	for row in ROWS:
		if cells[index_of(row, column)] != Disc.Value.NONE:
			height += 1
	return height


## The row a disc dropped now would come to rest on, or -1 if the column is
## full. Gravity, in one line: it lands on top of whatever is already there.
func landing_row(column: int) -> int:
	var height := height_of(column)
	return -1 if height >= ROWS else ROWS - 1 - height


## The same answer as a slot index, or -1.
func landing_index(column: int) -> int:
	var row := landing_row(column)
	return -1 if row < 0 else index_of(row, column)


## The disc at the bottom of a column: the one Pop Out would take out.
func bottom_disc(column: int) -> int:
	return disc_at(bottom_index(column))


func can_drop(column: int) -> bool:
	return is_column(column) and height_of(column) < ROWS


## You may only ever pop your own disc, which is the whole tension of the mode:
## the column you most want to collapse is usually not one you can touch.
func can_pop(column: int, disc: int) -> bool:
	return is_column(column) and disc != Disc.Value.NONE and bottom_disc(column) == disc


func columns_to_drop() -> Array[int]:
	var out: Array[int] = []
	for column in COLUMNS:
		if can_drop(column):
			out.append(column)
	return out


func columns_to_pop(disc: int) -> Array[int]:
	var out: Array[int] = []
	for column in COLUMNS:
		if can_pop(column, disc):
			out.append(column)
	return out


func is_full() -> bool:
	for column in COLUMNS:
		if can_drop(column):
			return false
	return true


# Writing

## Drops a disc into a column and answers the slot it landed in, or -1 when the
## column was full.
func drop(column: int, disc: int) -> int:
	var index := landing_index(column)
	if index < 0 or disc == Disc.Value.NONE:
		push_warning("BoardState: nothing can be dropped into column %d." % column)
		return -1
	cells[index] = disc
	return index


## Takes the bottom disc out of a column and lets everything above it fall one
## row. Answers the slots whose contents moved, top first, so the board knows
## what to animate; an empty array means the pop was refused.
func pop(column: int, disc: int) -> PackedInt32Array:
	var moved := PackedInt32Array()
	if not can_pop(column, disc):
		push_warning("BoardState: column %d has no %s to pop." % [column, Disc.to_debug_char(disc)])
		return moved

	# Bottom upwards: each slot takes what was above it before that one is
	# read again. Walking the other way would smear one disc down the column.
	for row in range(ROWS - 1, 0, -1):
		var above := index_of(row - 1, column)
		if cells[above] != Disc.Value.NONE:
			moved.append(above)
		cells[index_of(row, column)] = cells[above]
	cells[index_of(0, column)] = Disc.Value.NONE

	moved.reverse()
	return moved


## An independent copy, for the bot to try a move on.
func clone() -> BoardState:
	var copy := BoardState.new()
	copy.cells = cells.duplicate()
	return copy


func _to_string() -> String:
	var lines := PackedStringArray()
	for row in ROWS:
		var slots := PackedStringArray()
		for column in COLUMNS:
			slots.append(Disc.to_debug_char(cells[index_of(row, column)]))
		lines.append(" ".join(slots))
	return "\n".join(lines)
