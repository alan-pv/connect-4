class_name GameState
extends RefCounted

## The source of truth for the match: the board, whose turn it is and how many
## rounds each player has won.


signal turn_changed(player_index: int)

signal score_changed(player_index: int, score: int)

const PLAYER_COUNT := 2

var config: GameConfig

var board: BoardState

## Rounds won, one entry per player.
var scores: Array[int] = []

var current_player: int = 0

## 0 before the first round starts.
var round_number: int = 0


func setup(p_config: GameConfig) -> void:
	config = p_config
	board = BoardState.new()
	scores = []
	scores.resize(PLAYER_COUNT)
	scores.fill(0)
	current_player = 0
	round_number = 0


# Who is who
# ---------------------------------------------------------------------------

func disc_for_player(player_index: int) -> int:
	return Disc.Value.RED if player_index == 0 else Disc.Value.YELLOW


func player_for_disc(disc: int) -> int:
	return 0 if disc == Disc.Value.RED else 1


func current_disc() -> int:
	return disc_for_player(current_player)


func opponent_of(player_index: int) -> int:
	return (player_index + 1) % PLAYER_COUNT


## Who is ahead once the match is over. -1 when the scores are level.
func match_winner() -> int:
	if scores[0] > scores[1]:
		return 0
	if scores[1] > scores[0]:
		return 1
	return -1


## True once somebody has won enough rounds to take the match.
func is_match_over() -> bool:
	if config == null:
		return false
	for score in scores:
		if score >= config.rounds_to_win:
			return true
	return false


# Legality

## True when the current player may play that move right now.
func can_play(code: int) -> bool:
	return not is_match_over() and is_legal(board, current_disc(), code, config.pop_out)


## Every move the current player has. The bot searches this, and a player left
## with an empty one has been stalemated.
func legal_moves() -> Array[int]:
	return moves_for(board, current_disc(), config.pop_out)


## The same question about any board, so the bot can ask it of a position it is
## only imagining. Static: it never touches the live match.
static func is_legal(p_board: BoardState, disc: int, code: int, pop_out: bool) -> bool:
	if not Move.is_code(code):
		return false
	var move := Move.from_code(code)
	if move.is_pop():
		return pop_out and p_board.can_pop(move.column, disc)
	return p_board.can_drop(move.column)


## Every legal move code for a colour on a board, drops before pops.
static func moves_for(p_board: BoardState, disc: int, pop_out: bool) -> Array[int]:
	var codes: Array[int] = []
	for column in p_board.columns_to_drop():
		codes.append(Move.drop_code(column))
	if pop_out:
		for column in p_board.columns_to_pop(disc):
			codes.append(Move.pop_code(column))
	return codes


# Playing
# ---------------------------------------------------------------------------

## Plays the current player's move and reports what happened.
func play(code: int) -> MoveResult:
	var result := MoveResult.new()
	if not can_play(code):
		return result

	var move := Move.from_code(code)
	var disc := current_disc()
	var rival := Disc.opponent(disc)

	result.code = code
	result.kind = move.kind
	result.column = move.column
	result.disc = disc

	if move.is_drop():
		result.index = board.drop(move.column, disc)
	else:
		# Read before the board changes: once the column has fallen there is
		# nothing at the bottom to point at any more.
		result.index = BoardState.bottom_index(move.column)
		result.fallen = board.pop(move.column, disc)

	if not result.is_valid():
		return result

	# Both colours are asked, and in that order it does not matter which moved:
	# a pop settles six slots at once and either of them may have finished.
	result.line = GameRules.winning_slots(board, disc)
	result.rival_line = GameRules.winning_slots(board, rival)

	if result.is_win():
		_award(current_player)
		return result
	if result.is_own_goal():
		_award(opponent_of(current_player))
		return result
	# A shared win is nobody's: the round ends level and no score moves.
	if result.is_shared_win():
		return result

	var next := opponent_of(current_player)
	# Stalemate, not a full board: in Pop Out a full board can still be played
	# on, and a board with room can still leave somebody with nothing legal.
	if moves_for(board, disc_for_player(next), config.pop_out).is_empty():
		result.is_draw = true
		return result

	current_player = next
	turn_changed.emit(current_player)
	return result


## Clears everything a round owns and hands the opening move to somebody. The
## scores belong to the match, not to the round, so they are left alone.
func start_round(starting_player: int) -> void:
	board = BoardState.new()
	round_number += 1
	current_player = starting_player
	turn_changed.emit(starting_player)


func _award(player_index: int) -> void:
	scores[player_index] += 1
	score_changed.emit(player_index, scores[player_index])
