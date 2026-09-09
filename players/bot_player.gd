class_name BotPlayer
extends Player

## The machine. THIS FILE IS YOURS.
##
## Everything around it is finished and wired: the turn loop asks this seat for
## a move exactly like it asks a person, and whatever comes out of
## `choose_move()` is played. Right now it picks at random, so the game is
## playable from the first run — every mission below replaces a piece of that
## randomness with a reason.
##
## What you are searching, in one paragraph. A position is a BoardState plus
## whose turn it is. A move is an int (see Move): 0..6 drops into that column,
## 7..13 pops the bottom disc out of column code - 7. Playing a move on a copy
## of the board is `board.clone()` and then `drop()` or `pop()` on the copy.
## `GameRules.has_won(board, disc)` says whether a colour has finished a line.
## That is the whole vocabulary — the rest is what you do with it.
##
## Pop Out is what makes this harder than it looks. A pop changes six slots in
## one move, it can complete a line for the OTHER colour, and — unlike a drop —
## it can be undone by the opponent popping the same column back. So the game
## has no natural end: positions repeat, and a search that assumes the board
## only ever fills up will loop forever. That is why MAX_DEPTH exists.


## How far ahead to look. There is no "solve it outright" depth here the way
## there was in tic tac toe: with Pop Out on, a position can come back round.
const MAX_DEPTH := 6

## Far enough above any heuristic score that a win is never traded for shape.
const WIN_SCORE := 100000.0

## Middle columns first. Alpha-beta prunes on the strength of the first move it
## looks at, and in Connect 4 the centre column sits on more winning lines than
## any other, so a search that opens there finishes several times sooner.
const COLUMN_ORDER := [3, 2, 4, 1, 5, 0, 6]

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


# ===========================================================================
# MISSION 1 — choose a move
# ===========================================================================

## Picks the move to play, as a code, or -1 when there is nowhere left.
##
##   ask for every legal move on this board for this colour
##   if there are none:
##       give back -1
##
##   roll a die against `skill`: some of the time, deliberately do not think.
##       that is what makes the easy presets feel careless instead of slow,
##       and it is one line, not a second bot
##
##   shuffle the moves before scoring them, so two moves the search likes
##       equally are not always broken the same way and the bot stops opening
##       every round identically
##
##   keep the best move and the best score seen so far
##   for each move:
##       copy the board
##       play the move on the copy
##       score the copy by handing it to _search(), one ply shallower, with
##           the turn now belonging to the opponent
##       if that score beats the best so far, this is the new best move
##
##   give back the best move
##
## Mind the sign. _search() returns the value of a position FOR YOU, so here
## you always want the biggest number — even though the position you are
## handing it is one where the opponent moves next.
##
## Godot you may not know yet:
##   GameState.moves_for(board, disc, pop_out) -> Array[int]
##                        every legal move code, static, safe to call on a copy
##   BoardState.clone() -> BoardState        an independent copy
##   Move.from_code(code) -> Move            .is_drop(), .is_pop(), .column
##   BoardState.drop(column, disc) -> int    the slot it landed in, or -1
##   BoardState.pop(column, disc)  -> PackedInt32Array   empty if refused
##   Array.shuffle()                         shuffles in place, returns nothing
##   Array.pick_random()                     one element, at random
##   randf()                                 a float from 0.0 to 1.0
##   -INF                                    smaller than any real score
func choose_move(board: BoardState, my_disc: int, pop_out: bool) -> int:
	var moves := GameState.moves_for(board, my_disc, pop_out)
	if moves.is_empty():
		return -1
	
	if randf() > skill:
		return -1
	
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
		var new_value := _search(new_board, my_disc, 0, MAX_DEPTH, INF, -INF, pop_out) #FIX
		if new_value > value:
			value = new_value
			best_move = move
	
	return best_move ## moves.pick_random() if not moves.is_empty() else -1


# ===========================================================================
# MISSION 2 — look ahead
# ===========================================================================

## What a position is worth to `me`, with `turn` to move. Alpha-beta minimax.
##
##   first, the ways this position is already over:
##       if I have a completed line and the opponent does not -> a win
##       if the opponent has one and I do not                 -> a loss
##       if BOTH of us have one, which a pop can do           -> level, 0.0
##       score a win with the depth left over, so the bot takes the quickest
##           win and the slowest loss instead of dawdling
##
##   if there is no depth left, stop searching and judge the position with
##       _evaluate()
##
##   work out every legal move for whoever is to move
##   if there are none, this position is a stalemate: level, 0.0
##
##   am I the one to move here? then I am looking for the biggest score;
##       otherwise the opponent is, and they are looking for the smallest
##
##   for each move, best first:
##       copy the board, play the move, search one ply deeper with the turn
##           handed over
##       keep the best score for whoever is choosing
##       pull alpha up (when maximising) or beta down (when minimising)
##       if beta has slid under alpha, stop: whoever is above this node in the
##           tree already has something better and will never come down here
##
##   give back the best score
##
## The Pop Out trap, and it is a real one: a pop can be undone by the opponent
## popping the same column straight back, so the search can walk in a circle
## for as long as you let it. `depth` is the only thing stopping it. Never let
## a branch recurse without spending one.
##
## Godot you may not know yet:
##   GameRules.has_won(board, disc) -> bool
##   Disc.opponent(disc) -> int      the other colour
##   maxf(a, b) / minf(a, b)         float max and min
##   INF and -INF                    the starting values for alpha and beta
func _search(board: BoardState, me: int, turn: int, depth: int, alpha: float, beta: float, pop_out: bool) -> float:
	var opponent := Disc.opponent(me)
	var i_win := GameRules.has_won(board, me)
	var opp_win := GameRules.has_won(board, opponent)

	if depth <= 0:
		return _evaluate(board, me)

	if i_win and not opp_win:
		return WIN_SCORE*depth
	if opp_win and not i_win:
		return -WIN_SCORE/depth
	if opp_win and i_win:
		return 0.0
	
	var moves := GameState.moves_for(board, turn, pop_out)
	if moves.is_empty():
		return 0.0
	
	var my_turn := turn == me
	var best_value := -INF if my_turn else INF
	for move in _ordered_moves(board, turn, pop_out):
		var new_board := board.clone()
		var new_move := Move.from_code(move)
		if new_move.is_drop():
			new_board.drop(new_move.column, turn)
		if new_move.is_pop():
			new_board.pop(new_move.column, turn)

		
		if my_turn:
			var new_value := _search(new_board, me, 1+(turn+1)%2, depth-1, 0.0, 0.0, pop_out)
			best_value = max(best_value, new_value)
		if not my_turn:
			var new_value := _search(new_board, opponent,(turn+1)%2, depth-1, 0.0, 0.0, pop_out)
			print((turn+1)%2)
			best_value = min(best_value, new_value)
	
	return best_value


# ===========================================================================
# MISSION 3 — judge a position
# ===========================================================================

## How promising a position looks when there is no more depth to spend.
##
## The shape of it is the same idea as tic tac toe: walk every line of four and
## ask who could still complete it.
##
##   start at zero
##   for every line GameRules knows about:
##       count how many of its four slots are mine, and how many are theirs
##       a line with both colours in it is dead — nobody can ever finish it —
##           so it is worth nothing to either side and you skip it
##       a line with only my discs is worth more the closer it is to four:
##           three is worth far more than two, and two more than one, so the
##           number you add should grow faster than the count does
##       a line with only theirs is worth the same, against you
##
##   consider weighting the centre column: a disc there sits on more lines
##       than a disc on the edge, and it is the cheapest positional idea in
##       the whole game
##
##   give back the total
##
## Once Pop Out is on, think about whether a line resting on discs the OPPONENT
## could pop out from under is really worth as much as one that cannot be moved.
## That is the piece of this evaluation no tic tac toe bot ever needed, and it
## is where a bot that understands this game beats one that does not.
##
## Godot you may not know yet:
##   GameRules.all_lines() -> Array[PackedInt32Array]   every line of four
##   GameRules.WIN_LENGTH                               how many make a line
##   BoardState.column_of(index) -> int
##   board.cells[index]                                 a Disc.Value
func _evaluate(board: BoardState, me: int) -> float:
	var lines := GameRules.all_lines()
	var total_count := 0.0
	for line in lines:
		var count_me := 0.0
		for i in line:
			if board.cells[i] != me:
				count_me -= 1.0/GameRules.WIN_LENGTH
			if board.cells[i] == me:
				count_me += 1.0/GameRules.WIN_LENGTH
			if board.cells[i] != me and count_me > 0:
				count_me = 0
				break
		total_count += count_me
		
	return total_count


# ===========================================================================
# MISSION 4 — order the moves
# ===========================================================================

## The legal moves, most promising first, so alpha-beta has something good to
## prune against from the start.
##
##   walk COLUMN_ORDER rather than 0..6
##   for each of those columns, take the drop if it is legal
##   then, if pops are allowed, the pops in the same order
##
## Whether pops belong before or after the drops is worth measuring rather than
## guessing: in most positions a drop is the move, but a pop that completes a
## line is the strongest move on the board.
##
## Godot you may not know yet:
##   BoardState.can_drop(column) -> bool
##   BoardState.can_pop(column, disc) -> bool
##   Move.drop_code(column) / Move.pop_code(column) -> int
func _ordered_moves(board: BoardState, turn: int, pop_out: bool) -> Array[int]:
	# TODO(you) — mission 4. Until then, legal but in no useful order.
	return GameState.moves_for(board, turn, pop_out)


# ---------------------------------------------------------------------------
# The safety net. Not part of any mission: it is what keeps a half-written bot
# from hanging the match.
# ---------------------------------------------------------------------------

func _any_legal_move(state: GameState) -> int:
	var moves := state.legal_moves()
	return moves.pick_random() if not moves.is_empty() else -1
