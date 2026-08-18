class_name ProceduralPlayerNavigation
extends NavigationAgent3D

signal auto_navigation_started(target: Vector3, forced: bool)
signal auto_navigation_cancelled
signal auto_navigation_completed
signal auto_navigation_failed(reason: String)

enum NavigationMode { NONE, INTERRUPTIBLE, FORCED }

@export_group("Input de Cancelamento")
@export var move_left_action: StringName = &"MoveLeft"
@export var move_right_action: StringName = &"MoveRight"
@export var move_up_action: StringName = &"MoveUp"
@export var move_down_action: StringName = &"MoveDown"

@export_group("Seguranca de Navegacao")
@export_range(0.2, 5.0, 0.1) var map_sync_timeout: float = 2.0
@export_range(0.1, 2.0, 0.05) var progress_check_interval: float = 0.25
@export_range(0.01, 1.0, 0.01) var minimum_progress_distance: float = 0.08
@export_range(0.5, 5.0, 0.1) var stuck_timeout: float = 1.25
@export_range(0, 10, 1) var max_repath_attempts: int = 3
@export_range(0.05, 2.0, 0.05) var repath_cooldown: float = 0.25
@export_range(0.5, 5.0, 0.1) var repath_reset_progress_time: float = 1.0
@export var enable_avoidance: bool = true

@onready var _player: CharacterBody3D = get_parent() as CharacterBody3D

var _mode: NavigationMode = NavigationMode.NONE
var _target := Vector3.ZERO
var _move_speed: float = 0.0
var _effective_speed: float = 0.0
var _move_direction := Vector3.ZERO
var _safe_velocity := Vector3.ZERO
var _safe_velocity_valid := false
var _waiting_for_map := false
var _map_wait_elapsed := 0.0
var _progress_check_elapsed := 0.0
var _stuck_elapsed := 0.0
var _stable_progress_elapsed := 0.0
var _repath_cooldown_remaining := 0.0
var _repath_attempts := 0
var _progress_origin := Vector3.ZERO
var _path_grace_remaining := 0.0

func _ready() -> void:
	avoidance_enabled = enable_avoidance
	if not velocity_computed.is_connected(_on_velocity_computed):
		velocity_computed.connect(_on_velocity_computed)

func start_navigation(target: Vector3, mode: NavigationMode, move_speed: float) -> void:
	_mode = mode
	_target = target
	_move_speed = maxf(move_speed, 0.0)
	max_speed = maxf(max_speed, _move_speed)
	_effective_speed = _move_speed
	_reset_navigation_safety()
	if is_instance_valid(_player):
		_progress_origin = _player.global_position
	_waiting_for_map = not _is_navigation_map_ready()
	if not _waiting_for_map:
		_request_path(false)
	auto_navigation_started.emit(target, mode == NavigationMode.FORCED)

func cancel_navigation() -> void:
	if _mode == NavigationMode.NONE: return
	_stop_navigation_state()
	auto_navigation_cancelled.emit()

func update_navigation(delta: float) -> bool:
	if _mode == NavigationMode.NONE: return false
	if not is_instance_valid(_player):
		_fail_navigation("player_invalid")
		return false
	if _mode == NavigationMode.INTERRUPTIBLE and _has_manual_input():
		cancel_navigation()
		return false
	if _waiting_for_map:
		_map_wait_elapsed += delta
		_move_direction = Vector3.ZERO
		_effective_speed = 0.0
		if _is_navigation_map_ready():
			_waiting_for_map = false
			_request_path(false)
		elif _map_wait_elapsed >= map_sync_timeout:
			_fail_navigation("navigation_map_not_ready")
			return false
		return true
	_repath_cooldown_remaining = maxf(_repath_cooldown_remaining - delta, 0.0)
	_path_grace_remaining = maxf(_path_grace_remaining - delta, 0.0)
	if is_navigation_finished() and _path_grace_remaining <= 0.0:
		if is_target_reached() or _player.global_position.distance_to(_target) <= maxf(target_desired_distance, 0.15):
			_finish_navigation()
			return false
		if not _try_repath():
			_fail_navigation("target_unreachable")
		return _mode != NavigationMode.NONE
	var next_position := get_next_path_position()
	var desired_direction := _player.global_position.direction_to(next_position)
	desired_direction.y = 0.0
	if desired_direction.length_squared() > 0.0001:
		desired_direction = desired_direction.normalized()
	else:
		desired_direction = Vector3.ZERO
	_apply_avoidance(desired_direction)
	_update_progress_watchdog(delta)
	return _mode != NavigationMode.NONE

func get_move_direction() -> Vector3:
	return _move_direction

func get_move_speed() -> float:
	return _effective_speed

func is_navigating() -> bool:
	return _mode != NavigationMode.NONE

func is_forced() -> bool:
	return _mode == NavigationMode.FORCED

func _apply_avoidance(desired_direction: Vector3) -> void:
	var desired_velocity := desired_direction * _move_speed
	if avoidance_enabled:
		velocity = desired_velocity
		if _safe_velocity_valid:
			var horizontal_safe := Vector3(_safe_velocity.x, 0.0, _safe_velocity.z)
			if horizontal_safe.length_squared() > 0.0001:
				_effective_speed = minf(horizontal_safe.length(), _move_speed)
				_move_direction = horizontal_safe.normalized()
				return
		_move_direction = desired_direction
		_effective_speed = _move_speed if desired_direction != Vector3.ZERO else 0.0
		return
	_move_direction = desired_direction
	_effective_speed = _move_speed if desired_direction != Vector3.ZERO else 0.0

func _update_progress_watchdog(delta: float) -> void:
	_progress_check_elapsed += delta
	if _progress_check_elapsed < progress_check_interval: return
	var elapsed := _progress_check_elapsed
	_progress_check_elapsed = 0.0
	var current_position := _player.global_position
	var horizontal_delta := Vector2(current_position.x - _progress_origin.x, current_position.z - _progress_origin.z).length()
	_progress_origin = current_position
	if horizontal_delta >= minimum_progress_distance:
		_stuck_elapsed = 0.0
		_stable_progress_elapsed += elapsed
		if _stable_progress_elapsed >= repath_reset_progress_time:
			_repath_attempts = 0
		return
	_stable_progress_elapsed = 0.0
	if current_position.distance_to(_target) <= maxf(target_desired_distance, 0.15): return
	_stuck_elapsed += elapsed
	if _stuck_elapsed >= stuck_timeout and _repath_cooldown_remaining <= 0.0:
		if not _try_repath():
			_fail_navigation("stuck")

func _try_repath() -> bool:
	if _repath_attempts >= max_repath_attempts: return false
	_repath_attempts += 1
	_request_path(true)
	return true

func _request_path(is_repath: bool) -> void:
	if not _is_navigation_map_ready():
		_waiting_for_map = true
		_map_wait_elapsed = 0.0
		return
	target_position = _target
	_move_direction = Vector3.ZERO
	_effective_speed = 0.0
	_safe_velocity = Vector3.ZERO
	_safe_velocity_valid = false
	_stuck_elapsed = 0.0
	_progress_check_elapsed = 0.0
	_stable_progress_elapsed = 0.0
	_progress_origin = _player.global_position
	_path_grace_remaining = 0.15
	if is_repath:
		_repath_cooldown_remaining = repath_cooldown

func _is_navigation_map_ready() -> bool:
	var map_rid := get_navigation_map()
	return map_rid.is_valid() and NavigationServer3D.map_get_iteration_id(map_rid) > 0

func _has_manual_input() -> bool:
	return Input.get_vector(move_left_action, move_right_action, move_up_action, move_down_action).length_squared() > 0.01

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if _mode == NavigationMode.NONE: return
	_safe_velocity = safe_velocity
	_safe_velocity_valid = true

func _finish_navigation() -> void:
	_stop_navigation_state()
	auto_navigation_completed.emit()

func _fail_navigation(reason: String) -> void:
	_stop_navigation_state()
	auto_navigation_failed.emit(reason)

func _stop_navigation_state() -> void:
	_mode = NavigationMode.NONE
	_move_speed = 0.0
	_effective_speed = 0.0
	_move_direction = Vector3.ZERO
	_safe_velocity = Vector3.ZERO
	_safe_velocity_valid = false
	_waiting_for_map = false
	if avoidance_enabled:
		velocity = Vector3.ZERO

func _reset_navigation_safety() -> void:
	_move_direction = Vector3.ZERO
	_safe_velocity = Vector3.ZERO
	_safe_velocity_valid = false
	_waiting_for_map = false
	_map_wait_elapsed = 0.0
	_progress_check_elapsed = 0.0
	_stuck_elapsed = 0.0
	_stable_progress_elapsed = 0.0
	_repath_cooldown_remaining = 0.0
	_repath_attempts = 0
	_path_grace_remaining = 0.0
