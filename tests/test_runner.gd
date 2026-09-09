class_name TestRunner
extends RefCounted

## Runs every suite and prints one line per file.


const SUITES := [
	preload("res://tests/test_disc.gd"),
	preload("res://tests/test_move.gd"),
	preload("res://tests/test_board_state.gd"),
	preload("res://tests/test_game_rules.gd"),
	preload("res://tests/test_game_state.gd"),
]


## True when everything passed.
static func run_all() -> bool:
	var total_checks := 0
	var total_failures := 0

	print("")
	print("---------------- tests ----------------")

	for suite_script: Script in SUITES:
		var suite: MiniTest = suite_script.new()
		var suite_name: String = suite_script.resource_path.get_file().get_basename()
		var failures := suite.run()
		total_checks += suite.checks
		total_failures += failures.size()

		if failures.is_empty():
			print("PASS  %-20s %d checks" % [suite_name, suite.checks])
		else:
			print("FAIL  %-20s %d of %d checks" % [suite_name, failures.size(), suite.checks])
			for failure in failures:
				print("        %s" % failure)

	print("---------------------------------------")
	print("%d checks, %d failures" % [total_checks, total_failures])
	print("")
	return total_failures == 0
