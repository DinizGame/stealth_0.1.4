class_name ProceduralPlayer
extends CharacterBody3D

@warning_ignore("unused_signal")
signal new_seed

const SPEED: float = 1.7
const RUN_MULTIPLIER: float = 2.0
const SECURITY_DIRECTOR_GROUP := &"procedural_training_security_director"
const PLAYER_GROUP := &"procedural_training_player"

@export_group("Movimento")
@export_range(1.0, 30.0, 0.5) var rotation_speed: float = 12.0
@export_range(1.0, 25.0, 0.5) var anim_smooth_speed: float = 10.0

@export_group("Stealth / Cobertura")
@export_range(0.20, 1.20, 0.05) var crouch_vision_height: float = 0.45
@export_range(0.60, 2.00, 0.05) var standing_vision_height: float = 1.20

@onready var body_slot: Node3D = $BodySlot
@onready var detection_component: ProceduralDetectionComponent = $DetectionComponent
@onready var qte_component: ProceduralQTEComponent = $QTEComponent
@onready var marker_mira: Marker3D = %MarkerMira
@onready var navigation_agent_player: ProceduralPlayerNavigation = $NavigationAgentPlayer

var locker_on: bool = false
var collectible_itens: int = 0
var mode_moving: bool = true
var _movement_locked := false
var _capture_guard: Node
var _capture_phase := 0
var _escort_qte_retry_remaining := 0.0
var _current_locker: Node3D
var grab_immunity_timer: float = 0.0

func _ready() -> void:
	add_to_group(PLAYER_GROUP)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_connect_signals()

func _connect_signals() -> void:
	if detection_component:
		detection_component.fully_detected.connect(_on_fully_detected)
	if qte_component:
		qte_component.primary_escape_success.connect(_on_primary_escape_success)
		qte_component.primary_escape_failed.connect(_on_primary_escape_failed)
		qte_component.escort_escape_success.connect(_on_escort_escape_success)
		qte_component.escort_escape_failed.connect(_on_escort_escape_failed)
	if navigation_agent_player:
		navigation_agent_player.auto_navigation_completed.connect(_on_auto_navigation_completed)
		navigation_agent_player.auto_navigation_failed.connect(_on_auto_navigation_failed)

func _physics_process(delta: float) -> void:
	if grab_immunity_timer > 0.0:
		grab_immunity_timer -= delta
	if not is_on_floor():
		velocity += get_gravity() * delta
	if _capture_phase == 2 and is_instance_valid(_capture_guard):
		_update_escort_escape_opportunity(delta)
	if navigation_agent_player.update_navigation(delta):
		_apply_directional_movement(navigation_agent_player.get_move_direction(), navigation_agent_player.get_move_speed(), delta)
		move_and_slide()
		_atualizar_animacao(delta)
		return
	if _movement_locked:
		velocity = Vector3(0.0, velocity.y, 0.0)
		move_and_slide()
		_atualizar_animacao(delta)
		return
	_processar_movimento(delta)
	move_and_slide()
	_atualizar_animacao(delta)

func _processar_movimento(delta: float) -> void:
	if locker_on:
		velocity = Vector3.ZERO
		return
	marker_mira.position.y = 1.2 if mode_moving else 0.7
	var input_dir := Input.get_vector("MoveLeft", "MoveRight", "MoveUp", "MoveDown")
	var direction := Vector3.ZERO
	var active_cam := get_viewport().get_camera_3d()
	if active_cam:
		var cam_basis := active_cam.global_transform.basis
		var cam_z := Vector3(cam_basis.z.x, 0.0, cam_basis.z.z).normalized()
		var cam_x := Vector3(cam_basis.x.x, 0.0, cam_basis.x.z).normalized()
		direction = (cam_x * input_dir.x + cam_z * input_dir.y).normalized()
	else:
		direction = Vector3(input_dir.x, 0.0, input_dir.y).normalized()
	var speed_multiplier := 1.0
	if body_slot and "speed_state" in body_slot:
		speed_multiplier = body_slot.speed_state
	if Input.is_action_pressed("Run") and mode_moving:
		speed_multiplier *= RUN_MULTIPLIER
	_apply_directional_movement(direction, SPEED * speed_multiplier, delta)

func _apply_directional_movement(direction: Vector3, move_speed: float, delta: float) -> void:
	if direction != Vector3.ZERO:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		var target_angle := atan2(-direction.x, -direction.z)
		if body_slot:
			body_slot.global_rotation.y = lerp_angle(body_slot.global_rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		velocity.z = move_toward(velocity.z, 0.0, SPEED)

func _atualizar_animacao(delta: float) -> void:
	if body_slot and "move" in body_slot:
		var target_velocity := Vector2(velocity.x, velocity.z).length()
		body_slot.move = lerp(float(body_slot.move), target_velocity, anim_smooth_speed * delta)

func navigate_to_position(target: Vector3, forced: bool = false, move_speed: float = SPEED) -> bool:
	if locker_on: return false
	if _movement_locked and not forced: return false
	var mode := ProceduralPlayerNavigation.NavigationMode.FORCED if forced else ProceduralPlayerNavigation.NavigationMode.INTERRUPTIBLE
	navigation_agent_player.start_navigation(target, mode, move_speed)
	return true

func stop_auto_navigation() -> void:
	navigation_agent_player.cancel_navigation()

func is_auto_navigating() -> bool:
	return navigation_agent_player.is_navigating()

func get_capture_guard() -> Node:
	return _capture_guard if is_instance_valid(_capture_guard) else null

func begin_guard_confrontation(guard: Node, allow_escape: bool) -> bool:
	if grab_immunity_timer > 0.0: return false
	if not is_instance_valid(guard): return false
	if is_instance_valid(_capture_guard) and _capture_guard != guard: return false
	stop_auto_navigation()
	_capture_guard = guard
	_capture_phase = 1
	_escort_qte_retry_remaining = 0.0
	_movement_locked = true
	if allow_escape and qte_component and qte_component.start_primary_escape():
		return true
	if guard.has_method("begin_escort"):
		guard.call_deferred("begin_escort", self)
	return true

func begin_escort_capture(guard: Node, destination: Vector3) -> void:
	if not is_instance_valid(guard): return
	_capture_guard = guard
	_capture_phase = 2
	_escort_qte_retry_remaining = 0.0
	_movement_locked = true
	navigate_to_position(destination, true, SPEED)

func release_from_guard(guard: Node = null) -> void:
	if guard != null and is_instance_valid(_capture_guard) and _capture_guard != guard: return
	if _capture_phase == 2:
		stop_auto_navigation()
	_capture_guard = null
	_capture_phase = 0
	_escort_qte_retry_remaining = 0.0
	_movement_locked = false
	if qte_component and qte_component.is_running():
		qte_component.cancel_qte()

func complete_capture(guard: Node) -> void:
	if is_instance_valid(_capture_guard) and guard != _capture_guard: return
	_trigger_game_over()

func enter_locker(locker: Node3D) -> void:
	stop_auto_navigation()
	_current_locker = locker
	locker_on = true

func exit_locker(locker: Node3D = null) -> void:
	if locker != null and is_instance_valid(_current_locker) and locker != _current_locker: return
	_current_locker = null
	locker_on = false

func is_hidden_from_guards() -> bool: return locker_on and is_instance_valid(_current_locker)
func is_crouching() -> bool: return not mode_moving
func get_target_height() -> float: return crouch_vision_height if is_crouching() else standing_vision_height
func apply_detection(amount: float) -> void: if detection_component: detection_component.apply_detection(amount)

func _update_escort_escape_opportunity(delta: float) -> void:
	if _capture_phase != 2 or not is_instance_valid(_capture_guard) or not qte_component: return
	_escort_qte_retry_remaining = maxf(_escort_qte_retry_remaining - delta, 0.0)
	var can_escape := true
	var director := _get_security_director()
	if director and director.has_method("can_attempt_escort_escape"):
		can_escape = bool(director.call("can_attempt_escort_escape", _capture_guard))
	if qte_component.is_escort_escape_running():
		if not can_escape:
			qte_component.cancel_qte()
			_escort_qte_retry_remaining = 0.35
		return
	if qte_component.is_running() or not can_escape or _escort_qte_retry_remaining > 0.0: return
	qte_component.start_escort_escape()

func _on_primary_escape_success() -> void:
	var guard := _capture_guard
	release_from_guard()
	grab_immunity_timer = 2.5
	if is_instance_valid(guard) and guard.has_method("on_primary_escape_success"):
		guard.call("on_primary_escape_success", self)

func _on_primary_escape_failed() -> void:
	if is_instance_valid(_capture_guard) and _capture_guard.has_method("begin_escort"):
		_capture_guard.call_deferred("begin_escort", self)
	else:
		_trigger_game_over()

func _on_escort_escape_success() -> void:
	var guard := _capture_guard
	release_from_guard()
	grab_immunity_timer = 2.5
	if is_instance_valid(guard) and guard.has_method("on_escort_escape_success"):
		guard.call("on_escort_escape_success", self)

func _on_escort_escape_failed() -> void:
	_escort_qte_retry_remaining = qte_component.escort_retry_delay if qte_component else 1.5

func _on_auto_navigation_completed() -> void:
	if _capture_phase == 2 and is_instance_valid(_capture_guard):
		complete_capture(_capture_guard)

func _on_auto_navigation_failed(reason: String) -> void:
	push_warning("Player: navegacao automatica falhou (%s)." % reason)
	if _capture_phase != 2 or not is_instance_valid(_capture_guard): return
	var guard := _capture_guard
	release_from_guard(guard)
	grab_immunity_timer = 2.5
	if is_instance_valid(guard) and guard.has_method("on_escort_navigation_failed"):
		guard.call("on_escort_navigation_failed", self)

func _on_fully_detected() -> void:
	_trigger_game_over()

func _get_security_director() -> Node:
	if not is_inside_tree(): return null
	return get_tree().get_first_node_in_group(SECURITY_DIRECTOR_GROUP)

func _trigger_game_over() -> void:
	stop_auto_navigation()
	if qte_component and qte_component.is_running(): qte_component.cancel_qte()
	get_tree().paused = true
	%GameOver.show()
	%newgame.grab_focus()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
