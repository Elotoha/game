class_name PlayerInput
extends RefCounted
## Future AI controllers can implement the same command / handbrake interface.
var command := Vector3.ZERO
var handbrake := false
var held: Dictionary = {}
func poll() -> void:
	command = Vector3(float(active("right", [KEY_RIGHT, KEY_D])) - float(active("left", [KEY_LEFT, KEY_A, KEY_Q])), float(active("gas", [KEY_UP, KEY_W, KEY_Z])), float(active("brake", [KEY_DOWN, KEY_S])))
	handbrake = active("handbrake", [KEY_SPACE])
func active(action: String, keys: Array) -> bool:
	if held.get(action, false):
		return true
	for key in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false
func clear() -> void:
	held.clear()
	command = Vector3.ZERO
	handbrake = false
