class_name MoveResult
extends RefCounted

## What happened when a move was played. Returned by GameState.play(), and the
## only thing the board is ever animated from.


## The move as it arrived, so nobody has to decode it twice.
var code: int = -1

## A Move.Kind.
var kind: int = Move.Kind.DROP

var column: int = -1

## Which colour moved (a Disc.Value).
var disc: int = Disc.Value.NONE

## A drop: the slot the disc landed in. A pop: the bottom slot it left from.
## -1 means the move was rejected.
var index: int = -1

## A pop only: the slots the surviving discs moved *out of*, top first. Each of
## those discs is now one row lower. Empty for a drop.
var fallen: PackedInt32Array = PackedInt32Array()

## Every slot in every line the mover completed. Empty if they completed none.
var line: PackedInt32Array = PackedInt32Array()

## The same, for the other colour. Only a pop can ever fill this: it drops a
## whole column at once, and what falls into place is not always yours.
var rival_line: PackedInt32Array = PackedInt32Array()

## True when the move left the next player with nowhere to go.
var is_draw: bool = false


func is_valid() -> bool:
	return index >= 0


func is_drop() -> bool:
	return kind == Move.Kind.DROP


func is_pop() -> bool:
	return kind == Move.Kind.POP


## Both colours finished a line in the same move. Nobody takes the round.
func is_shared_win() -> bool:
	return not line.is_empty() and not rival_line.is_empty()


## The mover won it outright.
func is_win() -> bool:
	return not line.is_empty() and rival_line.is_empty()


## The other colour won, off the back of a pop the mover made. It counts, and
## it is the cruellest way to lose in this game.
func is_own_goal() -> bool:
	return line.is_empty() and not rival_line.is_empty()


## Every slot worth lighting up, whoever they belong to.
func highlighted() -> PackedInt32Array:
	var slots := line.duplicate()
	for index_ in rival_line:
		if not slots.has(index_):
			slots.append(index_)
	return slots


## True when this move ended the round, whichever way it went.
func ends_round() -> bool:
	return is_win() or is_own_goal() or is_shared_win() or is_draw


func _to_string() -> String:
	return "MoveResult(%s %s at %d, fell %d, win %s, own goal %s, draw %s)" % [
		Disc.to_debug_char(disc), "drop" if is_drop() else "pop", column,
		fallen.size(), is_win(), is_own_goal(), is_draw,
	]
