extends Node

## Editor entry point: open tests/tests.tscn and press F6.


func _ready() -> void:
	TestRunner.run_all()
