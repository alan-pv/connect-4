class_name Disc
extends RefCounted

## The three things a slot can hold, as plain ints with a name.


enum Value {
	NONE, ## An empty slot.
	RED,
	YELLOW,
}


## The rival of a disc, or NONE for anything that has no rival.
static func opponent(disc: int) -> int:
	if disc == Value.RED:
		return Value.YELLOW
	if disc == Value.YELLOW:
		return Value.RED
	return Value.NONE


## The name a HUD or a results screen puts on a colour.
static func to_name(disc: int) -> String:
	match disc:
		Value.RED:
			return "Red"
		Value.YELLOW:
			return "Yellow"
		_:
			return ""


## Handy in error messages and in the board's _to_string().
static func to_debug_char(disc: int) -> String:
	match disc:
		Value.RED:
			return "R"
		Value.YELLOW:
			return "Y"
		_:
			return "."
