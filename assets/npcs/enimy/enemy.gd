extends CharacterBody3D

@export_group("References")
@export var player: CharacterBody3D
@export var extraction_area: Node3D

@export_group("Movement")
@export var speed: float = 2.5
@export var acceleration: float = 5.0
@export var turn_speed: float = 8.0

@export_group("Vision & Detection")
@export var detection_distance: float = 15.0
@export var field_of_view: float = 90.0
@export var search_duration: float = 3.0
@export var search_spin_speed: float = 2.0

@export_group("Confrontation")
@export var capture_distance: float = 1.8
@export var escort_follow_distance: float = 1.2
@export_range(0.05, 1.0, 0.05) var escort_repath_interval: float = 0.2

@export_group("Escort Coordination")
@export_range(1.5, 8.0, 0.25) var escort_clear_radius: float = 3.0
@export_range(2.0, 10.0, 0.25) var escort_clear_target_distance: float = 4.5
@export_range(0.1, 1.0, 0.05) var escort_clear_repath_interval: float = 0.3

@onready var navigation_agent_enemy: NavigationAgent3D = $NavigationAgentEnemy
@onready var ray_cast: RayCast3D = $RayCast

enum EnemyState { PATROL_WAIT, PATROL_MOVE, CHASING, SEARCHING, LOOKING_AROUND, CONFRONTATION, ESCORTING, CLEARING_ESCORT_PATH }
var current_state: EnemyState = EnemyState.PATROL_WAIT

var search_timer: float = 0.0
var stop_move: bool = false
var grab_cooldown_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _escort_repath_timer: float = 0.0
var _escort_follow_direction := Vector3.FORWARD
var _escort_clear_repath_timer: float = 0.0
var _yielding_to_other_guard := false
var _yield_collision_ignored := false

func _ready() -> void:
	add_to_group("enemy")
	navigation_agent_enemy.avoidance_enabled = true
	navigation_agent_enemy.radius = 0.5
	navigation_agent_enemy.velocity_computed.connect(_on_velocity_computed)

func _physics_process(delta: float) -> void:
	if grab_cooldown_timer > 0.0:
		grab_cooldown_timer -= delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	if not is_instance_valid(player):
		if not stop_move:
			move_and_slide()
		return
	if _is_player_controlled_by_other_guard():
		_process_escort_clearance(delta)
		move_and_slide()
		return
	if _yielding_to_other_guard:
		_finish_escort_clearance()
	if current_state == EnemyState.ESCORTING:
		_escort_process(delta)
		move_and_slide()
		return
	if current_state != EnemyState.CONFRONTATION and not stop_move and grab_cooldown_timer <= 0.0:
		if global_position.distance_to(player.global_position) <= capture_distance:
			if _has_clear_line_of_sight(player.global_position):
				_trigger_confrontation()
				return
	if current_state == EnemyState.CONFRONTATION:
		_enemy_confrontation_wait(delta)
		if not stop_move:
			move_and_slide()
		return
	var sees_player := _eye_enemy_ray_cast()
	if sees_player:
		current_state = EnemyState.CHASING
		navigation_agent_enemy.target_position = player.global_position
	elif current_state == EnemyState.CHASING:
		current_state = EnemyState.SEARCHING
	match current_state:
		EnemyState.CHASING:
			_request_movement(delta)
		EnemyState.SEARCHING:
			if navigation_agent_enemy.is_navigation_finished():
				current_state = EnemyState.LOOKING_AROUND
				search_timer = search_duration
			else:
				_request_movement(delta)
		EnemyState.LOOKING_AROUND:
			_enemy_look_around(delta)
			search_timer -= delta
			if search_timer <= 0.0:
				current_state = EnemyState.PATROL_WAIT
		EnemyState.PATROL_WAIT:
			_enemy_patrol_wait(delta)
		EnemyState.PATROL_MOVE:
			if navigation_agent_enemy.is_navigation_finished():
				current_state = EnemyState.PATROL_WAIT
			else:
				_request_movement(delta)
	if not stop_move:
		move_and_slide()

func begin_escort(target_player: Node) -> void:
	if not is_instance_valid(target_player): return
	if _yielding_to_other_guard:
		_finish_escort_clearance()
	if not is_instance_valid(extraction_area):
		push_warning("Enemy: extraction_area inválida. Escolta cancelada.")
		if target_player.has_method("release_from_guard"):
			target_player.release_from_guard(self)
		current_state = EnemyState.SEARCHING
		stop_move = false
		return
	current_state = EnemyState.ESCORTING
	stop_move = false
	_escort_repath_timer = 0.0
	var initial_direction := player.global_position - global_position
	initial_direction.y = 0.0
	if initial_direction.length_squared() > 0.01:
		_escort_follow_direction = initial_direction.normalized()
	add_collision_exception_with(player)
	player.add_collision_exception_with(self)
	if target_player.has_method("begin_escort_capture"):
		target_player.begin_escort_capture(self, extraction_area.global_position)

func _escort_process(delta: float) -> void:
	if not is_instance_valid(player): return
	_escort_repath_timer = maxf(_escort_repath_timer - delta, 0.0)
	var follow_position := _get_escort_follow_position()
	if _escort_repath_timer <= 0.0 and navigation_agent_enemy.target_position.distance_squared_to(follow_position) > 0.0625:
		navigation_agent_enemy.target_position = follow_position
		_escort_repath_timer = escort_repath_interval
	if global_position.distance_to(follow_position) <= 0.35 or navigation_agent_enemy.is_navigation_finished():
		_stop_horizontal(delta)
	else:
		_request_movement(delta)

func _get_escort_follow_position() -> Vector3:
	var move_direction := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if move_direction.length_squared() > 0.01:
		_escort_follow_direction = move_direction.normalized()
	return player.global_position - _escort_follow_direction * escort_follow_distance

func _is_player_controlled_by_other_guard() -> bool:
	if not player.has_method("get_capture_guard"): return false
	var active_guard := player.call("get_capture_guard") as Node
	return is_instance_valid(active_guard) and active_guard != self

func _process_escort_clearance(delta: float) -> void:
	if not _yielding_to_other_guard:
		_begin_escort_clearance()
	_escort_clear_repath_timer = maxf(_escort_clear_repath_timer - delta, 0.0)
	var distance_to_player := global_position.distance_to(player.global_position)
	if distance_to_player <= escort_clear_radius:
		current_state = EnemyState.CLEARING_ESCORT_PATH
		if _escort_clear_repath_timer <= 0.0:
			navigation_agent_enemy.target_position = _get_escort_clear_target()
			_escort_clear_repath_timer = escort_clear_repath_interval
		if navigation_agent_enemy.is_navigation_finished():
			_stop_horizontal(delta)
		else:
			_request_movement(delta)
		return
	if current_state != EnemyState.PATROL_WAIT and current_state != EnemyState.PATROL_MOVE:
		current_state = EnemyState.PATROL_WAIT
	_process_patrol_only(delta)

func _begin_escort_clearance() -> void:
	_yielding_to_other_guard = true
	stop_move = false
	grab_cooldown_timer = maxf(grab_cooldown_timer, 0.5)
	current_state = EnemyState.PATROL_WAIT
	_escort_clear_repath_timer = 0.0
	if not _yield_collision_ignored:
		add_collision_exception_with(player)
		player.add_collision_exception_with(self)
		_yield_collision_ignored = true

func _finish_escort_clearance() -> void:
	_yielding_to_other_guard = false
	_escort_clear_repath_timer = 0.0
	if _yield_collision_ignored and is_instance_valid(player):
		remove_collision_exception_with(player)
		player.remove_collision_exception_with(self)
		_yield_collision_ignored = false
	if current_state == EnemyState.CLEARING_ESCORT_PATH:
		current_state = EnemyState.PATROL_WAIT

func _get_escort_clear_target() -> Vector3:
	var away := global_position - player.global_position
	away.y = 0.0
	if away.length_squared() <= 0.01:
		away = global_transform.basis.x
	away = away.normalized()
	var player_direction := Vector3(player.velocity.x, 0.0, player.velocity.z)
	if player_direction.length_squared() > 0.01:
		player_direction = player_direction.normalized()
		var side := Vector3(-player_direction.z, 0.0, player_direction.x)
		if side.dot(away) < 0.0:
			side = -side
		away = (away + side * 0.75).normalized()
	return player.global_position + away * escort_clear_target_distance

func _process_patrol_only(delta: float) -> void:
	match current_state:
		EnemyState.PATROL_MOVE:
			if navigation_agent_enemy.is_navigation_finished():
				current_state = EnemyState.PATROL_WAIT
			else:
				_request_movement(delta)
		_:
			current_state = EnemyState.PATROL_WAIT
			_enemy_patrol_wait(delta)

func on_escort_escape_success(_target_player: Node) -> void:
	_finish_escort_as_search()

func on_escort_navigation_failed(_target_player: Node) -> void:
	_finish_escort_as_search()

func _finish_escort_as_search() -> void:
	remove_collision_exception_with(player)
	player.remove_collision_exception_with(self)
	current_state = EnemyState.SEARCHING
	search_timer = search_duration
	grab_cooldown_timer = search_duration
	_escort_repath_timer = 0.0
	navigation_agent_enemy.target_position = player.global_position

func _has_clear_line_of_sight(target_pos: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state
	var my_head_pos := global_position + Vector3(0, 1.0, 0)
	var target_head_pos := target_pos + Vector3(0, 1.0, 0)
	var query := PhysicsRayQueryParameters3D.create(my_head_pos, target_head_pos)
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	return result and result.collider == player

func _eye_enemy_ray_cast() -> bool:
	var distance_to_player := global_position.distance_to(player.global_position)
	if distance_to_player > detection_distance: return false
	var direction_to_player := global_position.direction_to(player.global_position)
	var forward_vector := -global_transform.basis.z
	var angle_to_player := rad_to_deg(forward_vector.angle_to(direction_to_player))
	if angle_to_player > field_of_view / 2.0: return false
	ray_cast.target_position = ray_cast.to_local(player.marker_mira.global_position)
	ray_cast.force_raycast_update()
	if ray_cast.is_colliding():
		var collider := ray_cast.get_collider()
		if collider == player: return true
	return false

func _request_movement(_delta: float) -> void:
	var current_location := global_position
	var next_location := navigation_agent_enemy.get_next_path_position()
	var direction := current_location.direction_to(next_location)
	direction.y = 0.0
	direction = direction.normalized()
	var target_velocity := direction * speed
	if navigation_agent_enemy.avoidance_enabled:
		navigation_agent_enemy.set_velocity(target_velocity)
	else:
		_on_velocity_computed(target_velocity)

func _on_velocity_computed(safe_velocity: Vector3) -> void:
	var delta := get_physics_process_delta_time()
	velocity.x = move_toward(velocity.x, safe_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, safe_velocity.z, acceleration * delta)
	var horiz_vel := Vector3(velocity.x, 0, velocity.z)
	if horiz_vel.length_squared() > 0.01:
		var look_dir := global_position + horiz_vel.normalized()
		var target_transform := global_transform.looking_at(look_dir, Vector3.UP)
		global_transform.basis = global_transform.basis.slerp(target_transform.basis, turn_speed * delta).orthonormalized()

func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)

func _enemy_look_around(delta: float) -> void:
	_stop_horizontal(delta)
	global_transform.basis = global_transform.basis.rotated(Vector3.UP, search_spin_speed * delta).orthonormalized()

func _enemy_patrol_wait(delta: float) -> void:
	_stop_horizontal(delta)
	global_transform.basis = global_transform.basis.rotated(Vector3.UP, (search_spin_speed * 0.2) * delta).orthonormalized()

func _enemy_confrontation_wait(delta: float) -> void:
	_stop_horizontal(delta)
	if is_instance_valid(player):
		var target_pos := Vector3(player.global_position.x, global_position.y, player.global_position.z)
		if global_position.distance_to(target_pos) > 0.01:
			var target_transform := global_transform.looking_at(target_pos, Vector3.UP)
			global_transform.basis = global_transform.basis.slerp(target_transform.basis, turn_speed * delta).orthonormalized()

func _trigger_confrontation() -> void:
	if not player.has_method("begin_guard_confrontation"): return
	var qte_iniciado = player.begin_guard_confrontation(self, true)
	if qte_iniciado:
		current_state = EnemyState.CONFRONTATION
		stop_move = true
	else:
		grab_cooldown_timer = 1.5

func on_primary_escape_success(_target_player: Node) -> void:
	stop_move = false
	current_state = EnemyState.SEARCHING
	search_timer = search_duration
	grab_cooldown_timer = search_duration
	navigation_agent_enemy.target_position = player.global_position

func receber_novo_destino_patrulha(ponto_vector3: Vector3) -> void:
	if current_state == EnemyState.PATROL_WAIT or current_state == EnemyState.PATROL_MOVE:
		navigation_agent_enemy.target_position = ponto_vector3
		current_state = EnemyState.PATROL_MOVE
