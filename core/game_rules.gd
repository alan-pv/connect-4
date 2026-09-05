class_name GameRules
extends RefCounted

## The rulebook: which slots win, and when a round has nothing left in it.
## Static and pure, so it can be tested without opening a scene.


## How many in a row it takes.
const WIN_LENGTH := 4

## Built once and reused: the sixty-nine lines never change.
static var _lines: Array[PackedInt32Array] = []

## Slot index -> the lines that pass through it. The only reason it exists is
## speed: after a move, only the lines touching the slots that changed can have
## become complete, and the bot asks that question tens of thousands of times.
static var _through: Dictionary = {}


## Every run of four that wins a round: across, down, and both diagonals.
static func all_lines() -> Array[PackedInt32Array]:
	if _lines.is_empty():
		_build()
	return _lines


## The lines that pass through one slot, as plain PackedInt32Arrays.
##
## Untyped on the way out on purpose: a Dictionary stores Variant, so a typed
## array put into one does not come back typed, and promising
## `Array[PackedInt32Array]` here would fail on the return rather than at the
## call. Read it with `for line: PackedInt32Array in ...`.
static func lines_through(index: int) -> Array:
	if _lines.is_empty():
		_build()
	return _through.get(index, [])


## Every line `disc` has completed. Usually none or one — but a pop drops a
## whole column at once and can finish two or three in the same move, and the
## board is going to want to light all of them up.
static func winning_lines(board: BoardState, disc: int) -> Array[PackedInt32Array]:
	var found: Array[PackedInt32Array] = []
	if disc == Disc.Value.NONE:
		return found
	for line in all_lines():
		if _is_complete(board, line, disc):
			found.append(line)
	return found


## Every slot in every line `disc` has completed, each one listed once. This is
## what the board highlights: one flat set of slots, however many lines the
## move happened to finish.
static func winning_slots(board: BoardState, disc: int) -> PackedInt32Array:
	var slots := PackedInt32Array()
	for line in winning_lines(board, disc):
		for index in line:
			if not slots.has(index):
				slots.append(index)
	return slots


## The first line `disc` has completed, or an empty array. Enough to answer
## "has this player won?" without collecting the rest.
static func winning_line(board: BoardState, disc: int) -> PackedInt32Array:
	if disc == Disc.Value.NONE:
		return PackedInt32Array()
	for line in all_lines():
		if _is_complete(board, line, disc):
			return line
	return PackedInt32Array()


static func has_won(board: BoardState, disc: int) -> bool:
	return not winning_line(board, disc).is_empty()


## Whoever owns a line right now, or NONE.
##
## Careful with this one in Pop Out: a pop can complete a line for *both*
## players at the same time, and then there is no single winner. Ask
## `is_shared_win()` before trusting the answer.
static func winner(board: BoardState) -> int:
	var red := has_won(board, Disc.Value.RED)
	var yellow := has_won(board, Disc.Value.YELLOW)
	if red and yellow:
		return Disc.Value.NONE
	if red:
		return Disc.Value.RED
	if yellow:
		return Disc.Value.YELLOW
	return Disc.Value.NONE


## The Pop Out corner case, and the reason this game needs a rule tic tac toe
## never did: pulling a disc out from under a column drops six slots at once,
## and the four it completes may not all be yours. Nobody takes a round they
## only won by handing the other player one at the same instant, so it is a
## draw — the same verdict either player would want if the colours were swapped.
static func is_shared_win(board: BoardState) -> bool:
	return has_won(board, Disc.Value.RED) and has_won(board, Disc.Value.YELLOW)


## True when the board is full and nobody owns a line. In Pop Out a full board
## is not the end of anything by itself — there are still discs to pull out
## from underneath — so GameState asks whether a move exists, not this.
static func is_draw(board: BoardState) -> bool:
	return board.is_full() and winner(board) == Disc.Value.NONE and not is_shared_win(board)


static func _is_complete(board: BoardState, line: PackedInt32Array, disc: int) -> bool:
	for index in line:
		if board.cells[index] != disc:
			return false
	return true


## The four directions, each walked WIN_LENGTH slots from every starting point
## that still fits on the grid.
static func _build() -> void:
	_lines = []
	_through = {}

	const DIRECTIONS := [
		Vector2i(1, 0),  # across
		Vector2i(0, 1),  # down
		Vector2i(1, 1),  # down and to the right
		Vector2i(1, -1), # up and to the right
	]

	for row in BoardState.ROWS:
		for column in BoardState.COLUMNS:
			for step: Vector2i in DIRECTIONS:
				var line := _line_from(row, column, step)
				if not line.is_empty():
					_lines.append(line)

	for line in _lines:
		for index in line:
			if not _through.has(index):
				_through[index] = []
			_through[index].append(line)


## One line of WIN_LENGTH slots, or nothing when it would run off the grid.
static func _line_from(row: int, column: int, step: Vector2i) -> PackedInt32Array:
	var line := PackedInt32Array()
	for i in WIN_LENGTH:
		var r := row + step.y * i
		var c := column + step.x * i
		if r < 0 or r >= BoardState.ROWS or c < 0 or c >= BoardState.COLUMNS:
			return PackedInt32Array()
		line.append(BoardState.index_of(r, c))
	return line
