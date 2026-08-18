extends Camera3D

const CAMERA_GROUP := &"procedural_training_camera"

@export_category("Alvos da Câmera")
@export var default_target: Marker3D

@export_category("Configurações de Transição")
@export var follow_speed: float = 12.0
@export var transition_duration: float = 0.3

var current_target: Marker3D
var is_transitioning: bool = false

func _ready() -> void:
	add_to_group(CAMERA_GROUP)
	if default_target:
		current_target = default_target
		global_transform = default_target.global_transform

func _process(delta: float) -> void:
	if is_transitioning or current_target == null:
		return
	global_transform = global_transform.interpolate_with(current_target.global_transform, follow_speed * delta)

func set_camera_target(new_target: Marker3D, _sender: Node = null) -> void:
	if new_target == null:
		new_target = default_target
	if new_target == null or current_target == new_target:
		return
	current_target = new_target
	is_transitioning = true
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_transform", current_target.global_transform, transition_duration)
	await tween.finished
	is_transitioning = false
