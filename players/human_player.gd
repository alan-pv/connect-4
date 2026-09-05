class_name HumanPlayer
extends Player

## A person: waits for a legal click on the board. Clicks that arrive out of
## turn, or on a move the rules refuse, are ignored.


var _waiting: bool = false
var _state: GameState = null


func request_pick(state: GameState) -> void:
	_state = state
	_waiting = true


func on_move_requested(code: int) -> void:
	if not _waiting:
		return
	if _state == null or not _state.can_play(code):
		return
	_waiting = false
	picked.emit(code)


func cancel_pick() -> void:
	_waiting = false
