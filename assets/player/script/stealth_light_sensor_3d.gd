class_name ProceduralLightSensor3D
extends Node

## Consulta a exposição luminosa do personagem no ProceduralFacility.
## O sensor tenta reencontrar o gerador caso ele ainda não esteja pronto
## quando o Player entra na árvore.

signal light_exposure_changed(light_level: float, light_zone: int)
signal facility_resolved(facility: Node3D)

@export var target: Node3D
@export var facility: Node3D
@export var auto_find_facility: bool = true
@export_range(0.1, 5.0, 0.1) var facility_retry_interval: float = 0.50

@export_group("Amostragem")
@export_range(1.0, 30.0, 1.0) var samples_per_second: float = 10.0
@export_range(0.0, 2.5, 0.05) var sample_height: float = 1.0
@export_range(0.01, 1.0, 0.01) var smoothing: float = 0.20
@export_range(0.001, 0.20, 0.001) var change_threshold: float = 0.02

@export_group("Debug")
@export var print_connection_debug: bool = false

# -1 indica que ainda não houve uma leitura válida.
var light_level: float = 0.0
var light_zone: int = -1
var has_valid_sample: bool = false

var _sample_timer: float = 0.0
var _facility_retry_timer: float = 0.0
var _reported_missing_facility: bool = false


func _ready() -> void:
	if target == null:
		target = get_parent() as Node3D

	_resolve_facility()
	set_process(not Engine.is_editor_hint())


func _process(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		target = get_parent() as Node3D
		if target == null:
			return

	if not _facility_is_valid():
		has_valid_sample = false

		if not auto_find_facility:
			return

		_facility_retry_timer -= delta
		if _facility_retry_timer <= 0.0:
			_facility_retry_timer = facility_retry_interval
			_resolve_facility()
		return

	_sample_timer -= delta
	if _sample_timer > 0.0:
		return

	_sample_timer = 1.0 / maxf(samples_per_second, 1.0)
	_sample_light()


func _sample_light() -> void:
	if not _facility_is_valid() or target == null:
		return

	var sample_position := target.global_position + Vector3.UP * sample_height
	var sampled_level := clampf(
		float(
			facility.call(
				"get_light_level_at_world_position",
				sample_position
			)
		),
		0.0,
		1.0
	)

	var previous_level := light_level
	var previous_zone := light_zone

	# A primeira leitura não deve ser suavizada a partir de um valor artificial.
	if not has_valid_sample:
		light_level = sampled_level
		has_valid_sample = true
	else:
		light_level = lerpf(
			light_level,
			sampled_level,
			clampf(smoothing, 0.01, 1.0)
		)

	if facility.has_method("get_light_zone_from_level"):
		light_zone = int(
			facility.call(
				"get_light_zone_from_level",
				light_level
			)
		)
	else:
		light_zone = _fallback_zone_from_level(light_level)

	if (
		absf(light_level - previous_level) >= change_threshold
		or light_zone != previous_zone
	):
		light_exposure_changed.emit(light_level, light_zone)


func _resolve_facility() -> void:
	if _facility_is_valid():
		return

	facility = null

	# Caminho principal: o próprio gerador entra neste grupo no _ready().
	var grouped := get_tree().get_first_node_in_group(
		"procedural_training_facility"
	) as Node3D

	if _node_is_light_facility(grouped):
		_set_resolved_facility(grouped)
		return

	# Fallback importante: encontra o gerador mesmo quando seu _ready()
	# ainda não executou e ele ainda não entrou no grupo.
	var scene_root := get_tree().current_scene
	var found := _find_facility_recursive(scene_root)
	if found != null:
		_set_resolved_facility(found)
		return

	if print_connection_debug and not _reported_missing_facility:
		_reported_missing_facility = true
		print(str(
			"[StealthLightSensor:%s] ProceduralFacility ainda não "
			+ "foi encontrado. Tentarei novamente.")
			% name
		)


func _set_resolved_facility(found: Node3D) -> void:
	facility = found
	_reported_missing_facility = false
	_facility_retry_timer = 0.0
	_sample_timer = 0.0

	if print_connection_debug:
		print(
			"[StealthLightSensor:%s] Conectado ao gerador: %s"
			% [name, facility.get_path()]
		)

	facility_resolved.emit(facility)


func _find_facility_recursive(node: Node) -> Node3D:
	if node == null:
		return null

	if _node_is_light_facility(node):
		return node as Node3D

	for child in node.get_children():
		var result := _find_facility_recursive(child)
		if result != null:
			return result

	return null


func _node_is_light_facility(node: Node) -> bool:
	return (
		node != null
		and node != self
		and node is Node3D
		and node.has_method("get_light_level_at_world_position")
		and node.has_method("get_light_zone_from_level")
	)


func _facility_is_valid() -> bool:
	return (
		facility != null
		and is_instance_valid(facility)
		and facility.has_method("get_light_level_at_world_position")
	)


func _fallback_zone_from_level(level: float) -> int:
	if level <= 0.28:
		return 0
	if level <= 0.48:
		return 1
	if level < 0.68:
		return 2
	return 3


func get_visibility_multiplier(
	minimum_visibility_in_dark: float = 0.20
) -> float:
	if not has_valid_sample:
		# Enquanto não há leitura, não concede vantagem indevida ao jogador.
		return 1.0

	return lerpf(
		clampf(minimum_visibility_in_dark, 0.0, 1.0),
		1.0,
		clampf(light_level, 0.0, 1.0)
	)


func is_in_darkness() -> bool:
	if not has_valid_sample:
		return false

	if _facility_is_valid():
		var threshold_value = facility.get("dark_light_threshold")
		if threshold_value != null:
			return light_level <= float(threshold_value)

	return light_level <= 0.28


func get_debug_state() -> Dictionary:
	return {
		"valid_sample": has_valid_sample,
		"light_level": light_level,
		"light_zone": light_zone,
		"facility_valid": _facility_is_valid(),
		"facility_path": (
			String(facility.get_path())
			if _facility_is_valid()
			else "<não encontrada>"
		)
	}
