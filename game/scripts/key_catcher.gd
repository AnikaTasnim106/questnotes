class_name KeyCatcher
extends Node
## Receives key presses even while the game is paused (for overlays).

signal key(keycode: int)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		key.emit((event as InputEventKey).keycode)
