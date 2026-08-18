extends StaticBody3D

const PLAYER_GROUP := &"procedural_training_player"
const MISSION_CONTROLLER_GROUP := &"procedural_training_mission_controller"

@onready var default_visual: Node3D = $VisualRoot/DefaultVisual
@onready var visual_root: Node3D = $VisualRoot
@onready var status_light: MeshInstance3D = $StatusLight

var _unlocked: bool = false
var _player_in_range: Node3D
var _runtime_visual: Node3D

func _ready() -> void:
	_update_visual_state()

func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range == null or not is_instance_valid(_player_in_range):
		return
	if not event.is_action_pressed("Interact"):
		return
	var mission_controller := get_tree().get_first_node_in_group(MISSION_CONTROLLER_GROUP)
	if mission_controller != null and mission_controller.has_method("request_exit"):
		mission_controller.call("request_exit", self, _player_in_range)

func set_unlocked(unlocked: bool) -> void:
	_unlocked = unlocked
	_update_visual_state()

func is_unlocked() -> bool:
	return _unlocked

func set_visual_scene(scene: PackedScene) -> bool:
	if scene == null:
		return false
	var instance := scene.instantiate()
	if not (instance is Node3D):
		if instance != null:
			instance.free()
		return false
	if _runtime_visual != null and is_instance_valid(_runtime_visual):
		_runtime_visual.queue_free()
	_runtime_visual = instance as Node3D
	visual_root.add_child(_runtime_visual)
	default_visual.hide()
	return true

func _update_visual_state() -> void:
	if status_light == null:
		return
	var material := status_light.material_override as StandardMaterial3D
	if material == null:
		return
	var color := Color(0.12, 1.0, 0.24) if _unlocked else Color(1.0, 0.08, 0.03)
	material.albedo_color = color
	material.emission = color

func _on_interaction_area_body_entered(body: Node3D) -> void:
	if body.is_in_group(PLAYER_GROUP):
		_player_in_range = body

func _on_interaction_area_body_exited(body: Node3D) -> void:
	if body == _player_in_range:
		_player_in_range = null
