class_name MiniTest
extends RefCounted

## A test framework in about forty lines. No plugin, no dependencies.
##
## To add a suite: make a file that extends MiniTest, give it methods whose
## names start with test_, and list the file in tests/test_runner.gd.
##
## The core is testable at all because it never mentions a node type. The day a
## `Control` sneaks into core/, these files stop being runnable.


var failures: PackedStringArray = PackedStringArray()
var checks: int = 0

var _current: String = ""


## Runs every test_ method in this object and returns the failures.
func run() -> PackedStringArray:
	failures.clear()
	checks = 0
	for method in get_method_list():
		var method_name: String = method.get("name", "")
		if method_name.begins_with("test_"):
			_current = method_name
			call(method_name)
	return failures


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append("%s  %s" % [_current, message])


func eq(actual: Variant, expected: Variant, message: String = "") -> void:
	check(actual == expected, "%s expected %s, got %s" % [message, expected, actual])


func is_true(condition: bool, message: String = "") -> void:
	check(condition, "%s expected true" % message)


func is_false(condition: bool, message: String = "") -> void:
	check(not condition, "%s expected false" % message)
