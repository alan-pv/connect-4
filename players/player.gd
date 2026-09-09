class_name Player
extends Node

## Common contract for anyone who can take a turn.


signal picked(code: int)

var player_index: int = 0

var display_name: String = "Player"

## The Disc.Value this player plays.
var disc: int = Disc.Value.NONE

var is_human: bool = true


func setup(p_index: int, p_name: String, p_disc: int, _config: GameConfig) -> void:
	player_index = p_index
	display_name = p_name
	disc = p_disc


## Asked once per turn. Answer with the `picked` signal whenever you are ready,
## this frame or ten frames later.
func request_pick(_state: GameState) -> void:
	push_error("%s does not implement request_pick()" % get_class())


## Every click on the board reaches every player. Most of them ignore it.
func on_move_requested(_code: int) -> void:
	pass


## The turn was abandoned: the match was restarted, or the scene is going away.
## Stop waiting, and do not emit picked.
func cancel_pick() -> void:
	pass
