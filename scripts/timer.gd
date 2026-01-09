class_name LabelTimer
extends Label

@export var active: bool = true
var time_s: float = 0.0

func _process(delta: float) -> void:
	if not active:
		return
	time_s += delta
	
	var hours = floor(time_s / 60/60)
	var minutes = fmod(floor(time_s / 60), 60)
	var seconds = fmod(floor(time_s), 60)
	self.text = ""
	if hours >= 1:
		self.text += "%d:" % hours
	self.text += "%02d:" % minutes
	self.text += "%02d" % seconds
