class_name Move
extends RefCounted

## A turn in Pop Out: either a disc dropped into a column, or your own disc
## pulled out from under it.
##
## Everything above this class passes moves around as a single int — the
## `code`. That is not decoration: a Player answers `picked(code)`, and the
## network relays that same int and nothing else. One number per turn is what
## keeps `players/`, `net/` and the whole online layer from ever having to know
## that this game has two kinds of move.
##
##     column 0..6      dropping into that column
##     column 7..13     popping the bottom disc out of column (code - COLUMNS)


enum Kind {
	DROP, ## A disc falls in from the top and lands on the pile.
	POP,  ## Your own disc leaves from the bottom; the column drops one row.
}

## Anything outside 0..MOVE_COUNT-1 is not a move at all.
const MOVE_COUNT := BoardState.COLUMNS * 2

var kind: int = Kind.DROP

var column: int = 0


func _init(p_kind: int = Kind.DROP, p_column: int = 0) -> void:
	kind = p_kind
	column = p_column


## The single int this move travels as.
func code() -> int:
	return column if kind == Kind.DROP else column + BoardState.COLUMNS


static func drop(column: int) -> Move:
	return Move.new(Kind.DROP, column)


static func pop(column: int) -> Move:
	return Move.new(Kind.POP, column)


## The other direction. Codes arrive from the network and from the bot, so an
## unusable one comes back as a move on a column that does not exist rather
## than crashing whoever asked.
static func from_code(code: int) -> Move:
	if not is_code(code):
		return Move.new(Kind.DROP, -1)
	if code < BoardState.COLUMNS:
		return Move.new(Kind.DROP, code)
	return Move.new(Kind.POP, code - BoardState.COLUMNS)


static func is_code(code: int) -> bool:
	return code >= 0 and code < MOVE_COUNT


static func drop_code(column: int) -> int:
	return column


static func pop_code(column: int) -> int:
	return column + BoardState.COLUMNS


func is_drop() -> bool:
	return kind == Kind.DROP


func is_pop() -> bool:
	return kind == Kind.POP


func _to_string() -> String:
	return "%s(%d)" % ["drop" if is_drop() else "pop", column]
