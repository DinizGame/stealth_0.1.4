extends Node3D

signal movimento_alterado(movendo: float)
signal modo_movimento(crouch: bool)

# Usando as constantes do Player diretamente para manter consistência
const VELOCIDADE_CAMINHADA: float = ProceduralPlayer.SPEED
const VELOCIDADE_CORRIDA: float = ProceduralPlayer.SPEED * ProceduralPlayer.RUN_MULTIPLIER

@onready var temp_player: Node3D = %temp_player
@onready var player: ProceduralPlayer = $".."

@export var caminho_mesh: String
@export var velocidade_suavizacao: float = 10.0

var _moving_state: bool = true
var body: Node3D
var _movendo_normalizado: float = 0.0

func _ready() -> void:
	processar_verificacao_de_cena(caminho_mesh)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
		
	# Lida com o input de Agachar/Levantar de forma eficiente
	# Só executa se o botão de correr for pressionado E o player estiver agachado
	if Input.is_action_pressed("Run") and not _moving_state:
		_moving_state = true
		player.mode_moving = _moving_state
		modo_movimento.emit(_moving_state)
		
	elif Input.is_action_just_pressed("ModeMove") and not Input.is_action_pressed("Run"):
		_moving_state = not _moving_state
		player.mode_moving = _moving_state
		modo_movimento.emit(_moving_state)

	# Suavização da velocidade para a animação
	var vel_horizontal := Vector3(player.velocity.x, 0.0, player.velocity.z).length()
	var alvo_normalizado := _obter_estado_normalizado(vel_horizontal)
	var novo_valor := lerpf(_movendo_normalizado, alvo_normalizado, velocidade_suavizacao * delta)
	
	if absf(novo_valor - alvo_normalizado) < 0.001:
		novo_valor = alvo_normalizado
		
	if _movendo_normalizado != novo_valor:
		_movendo_normalizado = novo_valor
		movimento_alterado.emit(_movendo_normalizado)
		
	# Oculta o corpo se o player estiver no armário (locker)
	if is_instance_valid(body):
		body.visible = not player.locker_on

func _obter_estado_normalizado(vel_real: float) -> float:
	if vel_real <= 0.05: # Adicionado um pequeno threshold para evitar micro-movimentos
		return 0.0
	if vel_real <= VELOCIDADE_CAMINHADA:
		return remap(vel_real, 0.0, VELOCIDADE_CAMINHADA, 0.0, 1.0)
	return clampf(remap(vel_real, VELOCIDADE_CAMINHADA, VELOCIDADE_CORRIDA, 1.0, 2.0), 1.0, 2.0)

func processar_verificacao_de_cena(caminho: String) -> void:
	if not caminho.is_empty() and ResourceLoader.exists(caminho, "PackedScene"):
		var recurso := ResourceLoader.load(caminho, "PackedScene") as PackedScene
		if recurso != null and _aplicar_body_scene(recurso):
			return
	_aplicar_fallback()

func _aplicar_body_scene(scene: PackedScene) -> bool:
	var instance := scene.instantiate()
	if not (instance is Node3D):
		instance.free()
		return false
		
	body = instance as Node3D
	add_child(body)
	temp_player.hide()
	_conectar_body(body)
	return true

func _aplicar_fallback() -> void:
	temp_player.show()
	body = temp_player
	_conectar_body(body)

func _conectar_body(novo_body: Node) -> void:
	if novo_body.has_method("set_moving"):
		if not movimento_alterado.is_connected(novo_body.set_moving):
			movimento_alterado.connect(novo_body.set_moving)
		novo_body.set_moving(_movendo_normalizado)
		
	if novo_body.has_method("set_mode_moving"):
		if not modo_movimento.is_connected(novo_body.set_mode_moving):
			modo_movimento.connect(novo_body.set_mode_moving)
		novo_body.set_mode_moving(_moving_state)
