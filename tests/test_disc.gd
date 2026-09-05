extends MiniTest

## The three things a slot can hold.


func test_opponent_swaps_the_two_colours() -> void:
	eq(Disc.opponent(Disc.Value.RED), Disc.Value.YELLOW, "the rival of red")
	eq(Disc.opponent(Disc.Value.YELLOW), Disc.Value.RED, "the rival of yellow")


func test_an_empty_slot_has_no_rival() -> void:
	eq(Disc.opponent(Disc.Value.NONE), Disc.Value.NONE, "the rival of nothing")


func test_names_and_debug_characters() -> void:
	eq(Disc.to_name(Disc.Value.RED), "Red")
	eq(Disc.to_name(Disc.Value.YELLOW), "Yellow")
	eq(Disc.to_name(Disc.Value.NONE), "")
	eq(Disc.to_debug_char(Disc.Value.NONE), ".")
