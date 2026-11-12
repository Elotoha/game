class_name LapTracker
extends RefCounted
## Ordered quarter gates prevent counting a lap by reversing over the line.
var gate := 1
var laps := 0
var elapsed := 0.0
var best := 0.0
var last_progress := 0.0
func step(dt: float, progress: float, on_road: bool) -> void:
	elapsed += dt
	if not on_road:
		return
	if gate < 4 and progress >= gate * 0.25 and progress < gate * 0.25 + 0.08:
		gate += 1
	if gate == 4 and last_progress > 0.90 and progress < 0.10:
		laps += 1
		if best == 0 or elapsed < best:
			best = elapsed
		elapsed = 0.0
		gate = 1
	last_progress = progress
