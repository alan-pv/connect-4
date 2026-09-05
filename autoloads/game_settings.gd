extends Node

## Settings and match data that survive a scene change. The setup screen or the
## room lobby writes `config`, game.gd reads it, and the results screen reads
## `last_result`. Nobody passes arguments between scenes.


var config: GameConfig

## Filled in by game.gd right before jumping to the results screen.
## Keys: "scores", "names", "winner", "rounds_played", "seconds".
var last_result: Dictionary = {}

var last_difficulty_id: StringName = &"normal"

## What other players see in the lobby. Kept here so it survives the trip
## between the online menu, the room and the match.
var player_name: String = "Player"

## The match that was just played online, so the room it was played in can
## offer the same one again. The lobby reads it once and clears it.
var last_online_setup: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start_new_game(new_config: GameConfig) -> void:
	config = new_config
	last_result = {}


## Same thing for a match that arrives from the network: the config was decided
## in the lobby, and the game scene only reads it.
func start_online_game(new_config: GameConfig) -> void:
	new_config.online = true
	config = new_config
	last_result = {}


func player_count() -> int:
	return GameConfig.PLAYER_COUNT
