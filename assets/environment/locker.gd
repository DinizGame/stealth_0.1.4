extends StaticBody3D

@export_group("Locker Camera")
@export_range(0.0005, 0.01, 0.0005) var camera_sensitivity: float = 0.002
@export_range(5.0, 60.0, 1.0) var camera_yaw_limit: float = 25.0
@export_range(5.0, 45.0, 1.0) var camera_pitch_limit: float = 12.0

@onready var camera_marker: Marker3D = $Marker3D

var pode_interagir: bool = false
var esta_escondido: bool = false
var player: CharacterBody3D
var _marker_base_rotation: Vector3

func _ready() -> void:
	_marker_base_rotation = camera_marker.rotation

func _unhandled_input(event: InputEvent) -> void:
	if esta_escondido and event is InputEventMouseMotion:
		_rotate_locker_camera(event)
		return
	if not event.is_action_pressed("Interact"):
		return
	if not pode_interagir and not esta_escondido:
		return
	if not esta_escondido and pode_interagir:
		_enter_locker()
	elif esta_escondido:
		_exit_locker()

func _rotate_locker_camera(event: InputEventMouseMotion) -> void:
	var yaw_limit := deg_to_rad(camera_yaw_limit)
	var pitch_limit := deg_to_rad(camera_pitch_limit)
	camera_marker.rotation.y -= event.relative.x * camera_sensitivity
	camera_marker.rotation.x -= event.relative.y * camera_sensitivity
	camera_marker.rotation.y = clamp(camera_marker.rotation.y, _marker_base_rotation.y - yaw_limit, _marker_base_rotation.y + yaw_limit)
	camera_marker.rotation.x = clamp(camera_marker.rotation.x, _marker_base_rotation.x - pitch_limit, _marker_base_rotation.x + pitch_limit)

func _enter_locker() -> void:
	if player == null or not is_instance_valid(player):
		return
	var director := get_tree().get_first_node_in_group(&"procedural_training_security_director")
	if director != null and director.has_method("report_player_entering_locker"):
		director.call("report_player_entering_locker", self, player)
	camera_marker.rotation = _marker_base_rotation
	_set_camera_target(camera_marker)
	esta_escondido = true
	if player.has_method("enter_locker"):
		player.call("enter_locker", self)
	else:
		player.locker_on = true

func _exit_locker() -> void:
	_set_camera_target(null)
	esta_escondido = false
	camera_marker.rotation = _marker_base_rotation
	if player != null and is_instance_valid(player):
		if player.has_method("exit_locker"):
			player.call("exit_locker", self)
		else:
			player.locker_on = false

func force_player_out_for_capture(target: Node3D) -> bool:
	if not esta_escondido or player == null or target != player:
		return false
	_exit_locker()
	return true

func is_hiding_player(target: Node3D) -> bool:
	return esta_escondido and player != null and target == player

func _set_camera_target(target: Marker3D) -> void:
	var camera := get_tree().get_first_node_in_group(&"procedural_training_camera")
	if camera and camera.has_method("set_camera_target"):
		camera.set_camera_target(target, self)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("procedural_training_player"):
		pode_interagir = true
		player = body as CharacterBody3D

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.is_in_group("procedural_training_player"):
		pode_interagir = false
