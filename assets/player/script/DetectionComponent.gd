class_name ProceduralDetectionComponent
extends Node

signal detection_changed(current_value: float)
signal fully_detected

@export var max_detection: float = 100.0
@export var interval: float = 1.0
@export var heal_rate: float = 5.0

var current_detection: float = 100.0
var _heal_timer: Timer

func _ready() -> void:
	current_detection = max_detection
	
	_heal_timer = Timer.new()
	_heal_timer.wait_time = interval
	_heal_timer.one_shot = false
	_heal_timer.timeout.connect(_on_heal_timer_timeout)
	add_child(_heal_timer)

func apply_detection(amount: float) -> void:
	if amount <= 0.0:
		return

	current_detection = clampf(current_detection - amount, 0.0, max_detection)
	detection_changed.emit(current_detection)

	if current_detection <= 0.0:
		_heal_timer.stop()
		fully_detected.emit()
	else:
		if _heal_timer.is_stopped():
			_heal_timer.start()

func _on_heal_timer_timeout() -> void:
	if current_detection < max_detection:
		current_detection = clampf(current_detection + heal_rate, 0.0, max_detection)
		detection_changed.emit(current_detection)
		
		if current_detection >= max_detection:
			_heal_timer.stop()
