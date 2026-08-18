class_name ProceduralCameraController
extends SpringArm3D

@export_group("Sensibilidade")
@export var mouse_sensitivity: float = 0.003
@export_range(10.0, 360.0, 1.0) var joystick_sensitivity: float = 120.0
@export_range(0.0, 0.9, 0.01) var joystick_deadzone: float = 0.15
@export var invert_joystick_y: bool = false

@export_group("Limites de Ângulo")
@export_range(-90.0, 0.0, 1.0) var min_pitch: float = -80.0
@export_range(0.0, 90.0, 1.0) var max_pitch: float = 30.0

@export_group("Zoom")
@export_range(0.1, 1.5, 0.1) var min_spring_length: float = 0.5
@export_range(1.0, 10.0, 0.1) var max_spring_length: float = 5.0
@export_range(0.1, 2.0, 0.1) var zoom_step: float = 0.5

@export_group("Altura (POV)")
@export_range(0.1, 3.0, 0.1) var pov_cam: float = 0.5
@export_range(0.0, 1.0, 0.1) var min_pov: float = 0.5
@export_range(1.0, 3.0, 0.1) var max_pov: float = 2.0

var joystick_camera_input: Vector2 = Vector2.ZERO

func _ready() -> void:
	position.y = pov_cam

func _input(event: InputEvent) -> void:
	_processar_zoom_mouse(event)
	_processar_camera_mouse(event)
	_processar_evento_joystick(event)
	_processar_altura_camera(event)

func _process(delta: float) -> void:
	_processar_camera_joystick(delta)
	
func _processar_zoom_mouse(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
		
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		spring_length = clampf(spring_length - zoom_step, min_spring_length, max_spring_length)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		spring_length = clampf(spring_length + zoom_step, min_spring_length, max_spring_length)

func _processar_camera_mouse(event: InputEvent) -> void:
	if not event is InputEventMouseMotion or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	var yaw: float = -event.relative.x * mouse_sensitivity
	var pitch: float = -event.relative.y * mouse_sensitivity
	_rotacionar_camera(yaw, pitch)

func _processar_evento_joystick(event: InputEvent) -> void:
	if not event is InputEventJoypadMotion:
		return

	match event.axis:
		JOY_AXIS_RIGHT_X:
			joystick_camera_input.x = event.axis_value
		JOY_AXIS_RIGHT_Y:
			joystick_camera_input.y = event.axis_value

func _processar_camera_joystick(delta: float) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return

	var camera_input := Vector2(
		_aplicar_deadzone(joystick_camera_input.x),
		_aplicar_deadzone(joystick_camera_input.y)
	)

	if camera_input == Vector2.ZERO:
		return

	var vertical_input: float = camera_input.y * (-1.0 if invert_joystick_y else 1.0)
	var velocidade_radianos := deg_to_rad(joystick_sensitivity)

	var yaw: float = -camera_input.x * velocidade_radianos * delta
	var pitch: float = -vertical_input * velocidade_radianos * delta

	_rotacionar_camera(yaw, pitch)

func _processar_altura_camera(event: InputEvent) -> void:
	if event.is_action_pressed("RB"):
		pov_cam = clampf(pov_cam + 0.1, min_pov, max_pov)
		position.y = pov_cam
	elif event.is_action_pressed("LB"):
		pov_cam = clampf(pov_cam - 0.1, min_pov, max_pov)
		position.y = pov_cam

func _aplicar_deadzone(value: float) -> float:
	var absolute_value := absf(value)
	if absolute_value <= joystick_deadzone:
		return 0.0

	var adjusted_value := (absolute_value - joystick_deadzone) / (1.0 - joystick_deadzone)
	return -adjusted_value if value < 0.0 else adjusted_value

func _rotacionar_camera(yaw_delta: float, pitch_delta: float) -> void:
	rotation.y += yaw_delta
	rotation.x += pitch_delta
	rotation.x = clampf(rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
