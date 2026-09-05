extends SceneTree

## Headless entry point:  godot --headless --script res://tests/run_tests.gd
## Exits with 1 when something failed, so it can be wired into a hook one day.


func _initialize() -> void:
	var ok := TestRunner.run_all()
	quit(0 if ok else 1)
