class_name BotPlayer
extends Player

## The machine: alpha-beta minimax over drops and pops.
##
## `skill` decides how often it bothers to think at all, which is what makes
## the easy presets feel careless rather than slow.


## How far ahead to look. There is no "solve it outright" depth here the way
## there was in tic tac toe: with Pop Out on, a position can come back round.
const MAX_DEPTH := 4

## Far enough above any heuristic score that a win is never traded for shape.
const WIN_SCORE := 100000.0

## Middle columns first. Alpha-beta prunes on the strength of the first move it
## looks at, and in Connect 4 the centre column sits on more winning lines than
## any other, so a search that opens there finishes several times sooner.
const COLUMN_ORDER := [3, 2, 4, 1, 5, 0, 6]

## What a line of four is worth with N discs of one colour in it and none of
## the other. It climbs steeply on purpose: three in a row is a threat that has
## to be answered, two is only a shape, and the gap should say so.
const LINE_SCORE: Array[float] = [0.0, 1.0, 10.0, 50.0, 1000.0]

var think_time: float = 0.45

## 0.0 = play at random, 1.0 = play as well as it can.
var skill: float = 0.8

## Bumped on every request and on every cancel. A pick that comes back from its
## await holding an old token knows the world moved on and stays quiet.
var _pick_token: int = 0


func setup(p_index: int, p_name: String, p_disc: int, config: GameConfig) -> void:
	super.setup(p_index, p_name, p_disc, config)
	is_human = false
	if config != null:
		think_time = config.bot_think_time
		skill = config.bot_skill


## The plumbing around your decision, already done. It pauses so the move is
## readable, checks that the turn is still the turn it was asked about, and
## falls back to something legal if `choose_move()` hands back nonsense.
func request_pick(state: GameState) -> void:
	_pick_token += 1
	var token := _pick_token

	if think_time > 0.0:
		await get_tree().create_timer(think_time).timeout
	if token != _pick_token:
		return

	var code := choose_move(state.board, disc, state.config.pop_out)
	if not state.can_play(code):
		if code != -1:
			push_warning("The bot chose %s, which is not legal here." % Move.from_code(code))
		code = _any_legal_move(state)
	if code < 0:
		push_error("The bot found nowhere to play. Is anything ending this round?")
		return
	picked.emit(code)


func cancel_pick() -> void:
	_pick_token += 1


func choose_move(board: BoardState, my_disc: int, pop_out: bool) -> int:
	var moves := GameState.moves_for(board, my_disc, pop_out)
	if moves.is_empty():
		return -1
	
	if randf() > skill:
		return moves.pick_random()
	
	var value := -INF
	var best_move := -1
	moves.shuffle()
	
	for move in moves:
		var new_board := board.clone()
		var new_move := Move.from_code(move)
		if new_move.is_drop():
			new_board.drop(new_move.column, my_disc)
		if new_move.is_pop():
			new_board.pop(new_move.column, my_disc)
		var new_value := _search(new_board, my_disc, Disc.opponent(my_disc), MAX_DEPTH-1, value, INF, pop_out)
		
		if new_value > value:
			value = new_value
			best_move = move
	
	
	return best_move


func _search(board: BoardState, me: int, turn: int, depth: int, alpha: float, beta: float, pop_out: bool) -> float:
	var opponent := Disc.opponent(me)
	var i_win := GameRules.has_won(board, me)
	var opp_win := GameRules.has_won(board, opponent)
	
	if i_win and not opp_win:
		return WIN_SCORE * depth
	if opp_win and not i_win:
		return -WIN_SCORE * depth
	if opp_win and i_win:
		return 0.0
	if depth <= 0:
		return _evaluate(board, me)
	
	var moves := _ordered_moves(board, turn, pop_out)
	if moves.is_empty():
		return 0.0
	
	var my_turn := turn == me
	var best_value := -INF if my_turn else INF
	
	for move in moves:
		var new_board := board.clone()
		var new_move := Move.from_code(move)
		if new_move.is_drop():
			new_board.drop(new_move.column, turn)
		if new_move.is_pop():
			new_board.pop(new_move.column, turn)
		
		if my_turn:
			var new_value := _search(new_board, me, Disc.opponent(turn), depth-1, alpha, beta, pop_out)
			best_value = max(best_value, new_value)
			alpha = max(alpha, new_value)
			if beta <= alpha:
				break

		if not my_turn:
			var new_value := _search(new_board, me, Disc.opponent(turn), depth-1, alpha, beta, pop_out)
			best_value = min(best_value, new_value)
			beta = min(beta, new_value)
			if beta <= alpha:
				break

	return best_value


func _evaluate(board: BoardState, me: int) -> float:
	var opponent := Disc.opponent(me)
	var total := 0.0
	for line: PackedInt32Array in GameRules.all_lines():
		var mine := 0
		var theirs := 0
		for index in line:
			if board.cells[index] == me:
				mine += 1
			elif board.cells[index] == opponent:
				theirs += 1
		# A line both colours have touched is dead: nobody can ever finish it.
		if mine > 0 and theirs > 0:
			continue
		if mine > 0:
			total += LINE_SCORE[mine]
		elif theirs > 0:
			total -= LINE_SCORE[theirs]
	return total


func _ordered_moves(board: BoardState, turn: int, pop_out: bool) -> Array[int]:
	var ordered: Array[int] = []
	for column: int in COLUMN_ORDER:
		if board.can_drop(column):
			ordered.append(Move.drop_code(column))
	if pop_out:
		for column: int in COLUMN_ORDER:
			if board.can_pop(column, turn):
				ordered.append(Move.pop_code(column))
	return ordered


# The safety net. Not part of any mission: it is what keeps a half-written bot
# from hanging the match.
# ---------------------------------------------------------------------------

func _any_legal_move(state: GameState) -> int:
	var moves := state.legal_moves()
	return moves.pick_random() if not moves.is_empty() else -1
