extends MiniTest

## The lines, and the Pop Out corner case tic tac toe never had.

const RED := Disc.Value.RED
const YELLOW := Disc.Value.YELLOW


func test_there_are_sixty_nine_lines_on_a_seven_by_six_board() -> void:
	# 24 across, 21 down, 12 each way on the diagonals.
	eq(GameRules.all_lines().size(), 69, "lines of four")


func test_every_line_is_four_slots_on_the_board() -> void:
	for line in GameRules.all_lines():
		eq(line.size(), GameRules.WIN_LENGTH, "a line is four long")
		for index in line:
			is_true(BoardState.is_inside(index), "slot %d is on the board" % index)


func test_four_across_wins() -> void:
	var board := BoardState.new()
	for column in 4:
		board.drop(column, RED)
	is_true(GameRules.has_won(board, RED), "red has four across the bottom")
	is_false(GameRules.has_won(board, YELLOW), "yellow has not")


func test_four_down_wins() -> void:
	var board := BoardState.new()
	for _i in 4:
		board.drop(2, YELLOW)
	is_true(GameRules.has_won(board, YELLOW), "yellow has four in a column")


func test_a_diagonal_wins() -> void:
	var board := BoardState.new()
	# A staircase: one red on top of an increasing pile of yellow.
	for column in 4:
		for _filler in column:
			board.drop(column, YELLOW)
		board.drop(column, RED)
	is_true(GameRules.has_won(board, RED), "red climbs the staircase")


func test_three_is_not_four() -> void:
	var board := BoardState.new()
	for column in 3:
		board.drop(column, RED)
	is_false(GameRules.has_won(board, RED), "three across is not a win")
	eq(GameRules.winner(board), Disc.Value.NONE, "and nobody has won")


func test_a_line_broken_by_the_other_colour_is_not_a_win() -> void:
	var board := BoardState.new()
	board.drop(0, RED)
	board.drop(1, RED)
	board.drop(2, YELLOW)
	board.drop(3, RED)
	is_false(GameRules.has_won(board, RED), "the run is interrupted")


func test_a_win_reports_every_slot_of_the_line() -> void:
	var board := BoardState.new()
	for column in 4:
		board.drop(column, RED)
	var slots := GameRules.winning_slots(board, RED)
	eq(slots.size(), 4, "four slots light up")
	for column in 4:
		is_true(slots.has(BoardState.index_of(BoardState.ROWS - 1, column)),
			"column %d is in the line" % column)


func test_both_colours_winning_at_once_is_nobody_winning() -> void:
	var board := BoardState.new()
	for column in 4:
		board.drop(column, RED)
	for column in 4:
		board.drop(column, YELLOW)
	is_true(GameRules.has_won(board, RED), "red has a line")
	is_true(GameRules.has_won(board, YELLOW), "so does yellow")
	is_true(GameRules.is_shared_win(board), "which is a shared win")
	eq(GameRules.winner(board), Disc.Value.NONE, "and there is no single winner")


## A real drawn board, searched for rather than guessed at: forty-two discs,
## twenty-one each, and not one line of four anywhere on it. Written top row
## first, and filled by dropping, so it is a position gravity could reach.
const DRAWN_BOARD := [
	"RRRYRRY",
	"YYRRYYR",
	"RRYYRRR",
	"YYRYYYR",
	"YYYRRRY",
	"RYRYYYR",
]


func test_a_full_board_with_no_line_is_a_draw() -> void:
	var board := _fill(DRAWN_BOARD)
	is_true(board.is_full(), "the board is full")
	is_false(GameRules.has_won(board, RED), "red has no line")
	is_false(GameRules.has_won(board, YELLOW), "yellow has no line")
	is_false(GameRules.is_shared_win(board), "and it is not a shared win either")
	is_true(GameRules.is_draw(board), "so it is a draw")


func test_lines_through_a_slot_all_contain_it() -> void:
	for index in [0, 3, 24, BoardState.CELL_COUNT - 1]:
		var found := GameRules.lines_through(index)
		is_false(found.is_empty(), "slot %d sits on at least one line" % index)
		for line: PackedInt32Array in found:
			is_true(line.has(index), "every line through %d contains it" % index)


## Builds a board from rows written top first, by dropping into columns from
## the bottom up. Anything gravity could not produce would not be a fair test.
func _fill(rows: Array) -> BoardState:
	var board := BoardState.new()
	for column in BoardState.COLUMNS:
		for row in range(BoardState.ROWS - 1, -1, -1):
			var letter: String = str(rows[row])[column]
			board.drop(column, RED if letter == "R" else YELLOW)
	return board
