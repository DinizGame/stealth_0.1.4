class_name ProceduralQTEComponent
extends Node

signal primary_escape_success
signal primary_escape_failed
signal escort_escape_success
signal escort_escape_failed
signal prompt_changed(text: String)
signal prompt_hidden

@export_group("Primeira Fuga")
@export_range(0.0, 3.0, 0.05) var primary_prepare_time: float = 0.45
@export_range(0.1, 3.0, 0.05) var primary_window_time: float = 0.85
@export var primary_action: StringName = &"Interact"

@export_group("Fuga Durante Escolta")
@export_range(0.0, 5.0, 0.05) var escort_prepare_time: float = 1.0
@export_range(0.2, 5.0, 0.05) var escort_window_time: float = 2.0
@export_range(0.25, 8.0, 0.25) var escort_retry_delay: float = 1.5
@export_range(0.03, 0.5, 0.01) var escort_sync_tolerance: float = 0.16
@export var escort_left_action: StringName = &"MoveLeft"
@export var escort_right_action: StringName = &"MoveRight"

var _running := false
var _phase := 0
var _primary_blocked := false

func is_running() -> bool:
	return _running

func is_primary_escape_running() -> bool:
	return _running and _phase == 1

func is_escort_escape_running() -> bool:
	return _running and _phase == 2

func start_primary_escape() -> bool:
	if _running: return false
	_running = true
	_phase = 1
	_primary_blocked = false
	_run_primary_escape()
	return true

func start_escort_escape() -> bool:
	if _running: return false
	_running = true
	_phase = 2
	_primary_blocked = false
	_run_escort_escape()
	return true

func block_primary_escape() -> void:
	if is_primary_escape_running():
		_primary_blocked = true

func cancel_qte() -> void:
	_finish_qte()

func _run_primary_escape() -> void:
	prompt_changed.emit("AGUARDE O MOMENTO...")
	if not await _wait_seconds(primary_prepare_time): return
	
	if _primary_blocked:
		_finish_qte()
		primary_escape_failed.emit()
		return
		
	prompt_changed.emit("AGORA!  [E]")
	var start_msec := Time.get_ticks_msec()
	
	while _running and _phase == 1:
		await get_tree().process_frame
		
		if _primary_blocked:
			_finish_qte()
			primary_escape_failed.emit()
			return
			
		if Input.is_action_just_pressed(primary_action):
			_finish_qte()
			primary_escape_success.emit()
			return
			
		if _elapsed_seconds(start_msec) >= primary_window_time:
			_finish_qte()
			primary_escape_failed.emit()
			return

func _run_escort_escape() -> void:
	prompt_changed.emit("OPORTUNIDADE DE FUGA — PREPARE A + D")
	if not await _wait_seconds(escort_prepare_time): return
	
	prompt_changed.emit("AGORA!  [A + D]")
	var start_msec := Time.get_ticks_msec()
	var left_press_msec := -1
	var right_press_msec := -1
	
	while _running and _phase == 2:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		
		if Input.is_action_just_pressed(escort_left_action):
			left_press_msec = now
		if Input.is_action_just_pressed(escort_right_action):
			right_press_msec = now
			
		if left_press_msec >= 0 and right_press_msec >= 0:
			var difference := absf(float(left_press_msec - right_press_msec)) / 1000.0
			if difference <= escort_sync_tolerance:
				_finish_qte()
				escort_escape_success.emit()
				return
			
			if left_press_msec < right_press_msec:
				left_press_msec = -1
			else:
				right_press_msec = -1
				
		if _elapsed_seconds(start_msec) >= escort_window_time:
			_finish_qte()
			escort_escape_failed.emit()
			return

func _wait_seconds(seconds: float) -> bool:
	if seconds <= 0.0: return _running
	var start_msec := Time.get_ticks_msec()
	while _running and _elapsed_seconds(start_msec) < seconds:
		await get_tree().process_frame
	return _running

func _elapsed_seconds(start_msec: int) -> float:
	return float(Time.get_ticks_msec() - start_msec) / 1000.0

func _finish_qte() -> void:
	if not _running: return
	_running = false
	_phase = 0
	_primary_blocked = false
	prompt_hidden.emit()


func _on_canvas_layer_stop_process_frame() -> void:
	_finish_qte()
