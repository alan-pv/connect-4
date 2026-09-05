extends MiniTest

## Turns, scores, and the two ways a Pop Out round can end that no other
## version of this game has.

const RED := Disc.Value.RED
const YELLOW := Disc.Value.YELLOW


func _state(pop_out: bool = true, rounds: int = 3) -> GameState:
	var config := GameConfig.new()
	config.pop_out = pop_out
	config.rounds_to_win = rounds
	var state := GameState.new()
	state.setup(config)
	state.start_round(0)
	return state


func test_red_opens_and_the_turn_passes() -> void:
	var state := _state()
	eq(state.current_player, 0, "player 0 opens")
	eq(state.current_disc(), RED, "and plays red")
	state.play(Move.drop_code(3))
	eq(state.current_player, 1, "the turn passed")
	eq(state.current_disc(), YELLOW, "to yellow")


func test_a_rejected_move_leaves_everything_alone() -> void:
	var state := _state()
	var result := state.play(99)
	is_false(result.is_valid(), "99 is not a move")
	eq(state.current_player, 0, "and nobody lost their turn")


func test_pops_are_illegal_with_pop_out_off() -> void:
	var state := _state(false)
	state.play(Move.drop_code(0))    # red at the bottom of column 0
	state.play(Move.drop_code(1))    # yellow, so it is red's turn again
	is_true(state.can_play(Move.drop_code(0)), "dropping is still fine")
	is_false(state.can_play(Move.pop_code(0)), "but there is nothing to pop with")
	for code in state.legal_moves():
		is_true(code < BoardState.COLUMNS, "every legal move is a drop")


func test_pops_are_legal_with_pop_out_on_and_only_on_your_own_disc() -> void:
	var state := _state(true)
	state.play(Move.drop_code(0))    # red
	state.play(Move.drop_code(1))    # yellow
	is_true(state.can_play(Move.pop_code(0)), "red may pop its own column")
	is_false(state.can_play(Move.pop_code(1)), "but not yellow's")
	eq(state.legal_moves().size(), BoardState.COLUMNS + 1, "seven drops and one pop")


func test_four_in_a_row_takes_the_round() -> void:
	var state := _state()
	for column in 3:
		state.play(Move.drop_code(column))       # red takes columns 0, 1 and 2
		state.play(Move.drop_code(6))            # yellow stacks up out of the way
	var result := state.play(Move.drop_code(3))  # red completes the bottom row

	is_true(result.is_win(), "red won the round")
	is_false(result.is_own_goal(), "on purpose")
	eq(result.line.size(), 4, "four slots light up")
	eq(state.scores[0], 1, "and the score moved")
	eq(state.scores[1], 0, "only for the winner")


## A pop settles a whole column at once, and what falls into place is not
## always yours. Red pulls its own disc out and hands yellow the round.
func test_a_pop_can_hand_the_round_to_the_other_player() -> void:
	var state := _state()
	var board := state.board
	# Column 0, bottom up: red (about to be popped) with a yellow above it.
	board.drop(0, RED)
	board.drop(0, YELLOW)
	# The rest of the bottom row is already yellow.
	for column in [1, 2, 3]:
		board.drop(column, YELLOW)
	state.current_player = 0

	var result := state.play(Move.pop_code(0))

	is_true(result.is_valid(), "the pop was legal")
	is_true(result.is_own_goal(), "yellow got the four, not red")
	is_false(result.is_win(), "so red did not win it")
	eq(state.scores[1], 1, "the round went to yellow")
	eq(state.scores[0], 0, "and not to the player who moved")


## Both colours finish a line in the same move. Nobody takes the round.
func test_a_pop_can_complete_a_four_for_both_at_once() -> void:
	var state := _state()
	var board := state.board
	# Column 0, bottom up: the red that leaves, then yellow, then red.
	board.drop(0, RED)
	board.drop(0, YELLOW)
	board.drop(0, RED)
	# The other three columns already hold yellow under red.
	for column in [1, 2, 3]:
		board.drop(column, YELLOW)
		board.drop(column, RED)
	state.current_player = 0

	# Nothing is won yet: the rows are still mixed.
	is_false(GameRules.has_won(board, RED), "red has no line before the pop")
	is_false(GameRules.has_won(board, YELLOW), "nor does yellow")

	var result := state.play(Move.pop_code(0))

	is_true(result.is_shared_win(), "the column settled into a four each")
	is_false(result.is_win(), "so it is not a win")
	is_false(result.is_own_goal(), "and not a gift either")
	eq(state.scores[0], 0, "nobody scores")
	eq(state.scores[1], 0, "on either side")
	is_true(result.ends_round(), "but the round is over")


func test_the_match_ends_when_somebody_has_enough_rounds() -> void:
	var state := _state(true, 2)
	is_false(state.is_match_over(), "nothing has been won yet")
	state.scores[0] = 2
	is_true(state.is_match_over(), "two rounds takes a first-to-two match")
	eq(state.match_winner(), 0, "and player 0 took it")


func test_a_level_match_has_no_winner() -> void:
	var state := _state()
	state.scores[0] = 1
	state.scores[1] = 1
	eq(state.match_winner(), -1, "level")


func test_starting_a_round_clears_the_board_but_not_the_score() -> void:
	var state := _state()
	state.play(Move.drop_code(3))
	state.scores[0] = 1
	state.start_round(1)
	is_true(state.board.columns_to_drop().size() == BoardState.COLUMNS, "the board is empty")
	eq(state.scores[0], 1, "the score survived")
	eq(state.current_player, 1, "and the other player opens")
