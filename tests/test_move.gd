extends MiniTest

## Moves travel as a single int. If this suite breaks, so does the network.


func test_a_drop_is_its_own_column() -> void:
	for column in BoardState.COLUMNS:
		eq(Move.drop(column).code(), column, "drop %d" % column)


func test_a_pop_sits_above_every_drop() -> void:
	for column in BoardState.COLUMNS:
		var code := Move.pop(column).code()
		eq(code, column + BoardState.COLUMNS, "pop %d" % column)
		is_true(code >= BoardState.COLUMNS, "a pop is never mistaken for a drop")


func test_every_code_survives_the_round_trip() -> void:
	for code in Move.MOVE_COUNT:
		var move := Move.from_code(code)
		eq(move.code(), code, "code %d" % code)


func test_the_two_kinds_never_collide() -> void:
	var seen: Array[int] = []
	for column in BoardState.COLUMNS:
		for code in [Move.drop_code(column), Move.pop_code(column)]:
			is_false(seen.has(code), "code %d was already taken" % code)
			seen.append(code)
	eq(seen.size(), Move.MOVE_COUNT, "one code per legal move")


func test_a_code_off_the_end_is_not_a_move() -> void:
	is_false(Move.is_code(-1), "-1")
	is_false(Move.is_code(Move.MOVE_COUNT), "one past the last")
	eq(Move.from_code(99).column, -1, "nonsense decodes to no column")
