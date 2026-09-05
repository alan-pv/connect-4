extends MiniTest

## Gravity, and the one invariant everything leans on: no holes under a disc.

const RED := Disc.Value.RED
const YELLOW := Disc.Value.YELLOW
const NONE := Disc.Value.NONE


func test_a_new_board_is_empty() -> void:
	var board := BoardState.new()
	eq(board.cells.size(), BoardState.CELL_COUNT, "slot count")
	for column in BoardState.COLUMNS:
		eq(board.height_of(column), 0, "column %d starts empty" % column)
	is_false(board.is_full(), "an empty board is not full")


func test_a_disc_lands_on_the_bottom_row() -> void:
	var board := BoardState.new()
	var index := board.drop(3, RED)
	eq(index, BoardState.index_of(BoardState.ROWS - 1, 3), "the lowest slot of column 3")
	eq(board.disc_at(index), RED, "and it is red")
	eq(board.height_of(3), 1, "one disc high")


func test_discs_stack_upwards_with_no_gaps() -> void:
	var board := BoardState.new()
	for i in BoardState.ROWS:
		var index := board.drop(0, RED if i % 2 == 0 else YELLOW)
		eq(BoardState.row_of(index), BoardState.ROWS - 1 - i, "disc %d sits one row higher" % i)
	eq(board.height_of(0), BoardState.ROWS, "the column is full")
	is_false(board.can_drop(0), "and refuses another")
	eq(board.drop(0, RED), -1, "a refused drop lands nowhere")


func test_a_full_board_is_full() -> void:
	var board := BoardState.new()
	for column in BoardState.COLUMNS:
		for _row in BoardState.ROWS:
			board.drop(column, RED)
	is_true(board.is_full(), "every column is full")
	is_true(board.columns_to_drop().is_empty(), "and none can be dropped into")


func test_you_may_only_pop_your_own_colour() -> void:
	var board := BoardState.new()
	board.drop(2, RED)
	is_true(board.can_pop(2, RED), "red may pop its own disc")
	is_false(board.can_pop(2, YELLOW), "yellow may not")
	is_false(board.can_pop(5, RED), "nor may anyone pop an empty column")


func test_a_pop_drops_the_column_one_row() -> void:
	var board := BoardState.new()
	board.drop(1, RED)      # bottom
	board.drop(1, YELLOW)
	board.drop(1, RED)      # top of the pile
	var moved := board.pop(1, RED)

	eq(board.height_of(1), 2, "the column is one shorter")
	eq(board.bottom_disc(1), YELLOW, "what was second is now bottom")
	eq(board.disc_at(BoardState.index_of(BoardState.ROWS - 2, 1)), RED, "and red sits on top of it")
	eq(moved.size(), 2, "two discs actually moved")


func test_a_pop_only_reports_slots_that_held_a_disc() -> void:
	var board := BoardState.new()
	board.drop(4, YELLOW)
	var moved := board.pop(4, YELLOW)
	is_true(moved.is_empty(), "the only disc in the column left; nothing fell")
	eq(board.height_of(4), 0, "and the column is empty")


func test_a_refused_pop_changes_nothing() -> void:
	var board := BoardState.new()
	board.drop(0, RED)
	var before := board.cells.duplicate()
	var moved := board.pop(0, YELLOW)
	is_true(moved.is_empty(), "nothing moved")
	eq(board.cells, before, "and the board is untouched")


func test_a_pop_never_leaves_a_hole() -> void:
	var board := BoardState.new()
	board.drop(6, RED)
	board.drop(6, RED)
	board.drop(6, YELLOW)
	board.drop(6, RED)
	board.pop(6, RED)
	# Every filled slot must have a filled slot underneath it.
	for row in range(0, BoardState.ROWS - 1):
		var here := board.disc_at(BoardState.index_of(row, 6))
		var below := board.disc_at(BoardState.index_of(row + 1, 6))
		if here != NONE:
			is_true(below != NONE, "row %d is resting on something" % row)


func test_clone_is_independent() -> void:
	var board := BoardState.new()
	board.drop(3, RED)
	var copy := board.clone()
	copy.drop(3, YELLOW)
	eq(board.height_of(3), 1, "the original did not move")
	eq(copy.height_of(3), 2, "the copy did")
