class_name GameConfig
extends Resource

## The settings of a match and their validation.


const PLAYER_COUNT := 2

## Long enough for any name the lobby lets somebody type.
const MAX_NAME_LENGTH := 16

const MIN_ROUNDS := 1
const MAX_ROUNDS := 9

enum Opponent {
	BOT,   ## One human against the machine.
	HUMAN, ## Two people, on the same device or on two of them.
}

@export var opponent: Opponent = Opponent.BOT

@export var player_names: PackedStringArray = PackedStringArray(["You", "Bot"])

@export_group("The twist")

## Pop Out. When it is on, a turn can also be spent pulling one of your own
## discs out from the bottom row, and everything stacked above it falls a row.
## Off, this is the game everybody already knows.
@export var pop_out: bool = true

@export_group("Match")

## Rounds a player must win to take the match.
@export_range(1, 9, 1) var rounds_to_win: int = 3

@export_group("Bot")

@export var difficulty_id: StringName = &"normal"

## Seconds the bot pretends to think before playing.
@export_range(0.0, 2.0, 0.05) var bot_think_time: float = 0.45

## 0.0 plays at random, 1.0 plays as well as it can.
@export_range(0.0, 1.0, 0.05) var bot_skill: float = 0.8

@export_group("Online")

## True once the match is driven by the network. Read by game.gd to decide
## where moves come from; nothing in core/ cares.
@export var online: bool = false

## Which device owns each seat. All zeros offline. A seat owned by the referee
## while the match is online is a seat a bot took over.
@export var peer_ids: PackedInt32Array = PackedInt32Array([0, 0])


func owner_of(player_index: int) -> int:
	if player_index < 0 or player_index >= peer_ids.size():
		return 0
	return peer_ids[player_index]


func is_valid() -> bool:
	return validation_error() == ""


func validation_error() -> String:
	if player_names.size() != PLAYER_COUNT:
		return "A match needs exactly two players."
	if rounds_to_win < MIN_ROUNDS or rounds_to_win > MAX_ROUNDS:
		return "A match is between %d and %d rounds long." % [MIN_ROUNDS, MAX_ROUNDS]
	return ""


func clone() -> GameConfig:
	return duplicate(true) as GameConfig


func to_dict() -> Dictionary:
	return {
		"names": Array(player_names),
		"pop": pop_out,
		"rounds": rounds_to_win,
		"skill": bot_skill,
		"think": bot_think_time,
		"peers": Array(peer_ids),
	}


## Rebuilds a config from the wire. Every field arrives from another client, so
## every one of them is clamped into a range this build can actually play.
static func from_dict(data: Dictionary) -> GameConfig:
	var config := GameConfig.new()
	config.opponent = Opponent.HUMAN
	config.online = true

	var names := PackedStringArray()
	for entry in Array(data.get("names", [])).slice(0, PLAYER_COUNT):
		names.append(str(entry).substr(0, MAX_NAME_LENGTH))
	while names.size() < PLAYER_COUNT:
		names.append("Player %d" % (names.size() + 1))
	config.player_names = names

	config.pop_out = bool(data.get("pop", true))
	config.rounds_to_win = clampi(int(data.get("rounds", 3)), MIN_ROUNDS, MAX_ROUNDS)
	config.bot_skill = clampf(float(data.get("skill", 0.8)), 0.0, 1.0)
	config.bot_think_time = clampf(float(data.get("think", 0.45)), 0.0, 2.0)

	var peers := PackedInt32Array()
	for entry in Array(data.get("peers", [])).slice(0, PLAYER_COUNT):
		peers.append(int(entry))
	while peers.size() < PLAYER_COUNT:
		peers.append(0)
	config.peer_ids = peers

	return config


func _to_string() -> String:
	var mode := "pop out" if pop_out else "classic"
	var rival := "vs bot" if opponent == Opponent.BOT else "two players"
	return "GameConfig(%s, %s, first to %d)" % [rival, mode, rounds_to_win]
