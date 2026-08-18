extends Node3D

@export_group("Configurações Globais de Patrulha")
@export var tempo_distribuicao: float = 0.5 
@export var raio_patrulha: float = 10.0

var lista_inimigos: Array[Node] = []
var indice_atual: int = 0
var timer: Timer

# Função chamada pelo Gerente Principal da Cena
func iniciar_diretor(inimigos_encontrados: Array[Node]) -> void:
	lista_inimigos = inimigos_encontrados
	
	if lista_inimigos.is_empty():
		return
		
	timer = Timer.new()
	add_child(timer)
	timer.wait_time = tempo_distribuicao
	timer.timeout.connect(_distribuir_ponto_vector3)
	timer.start()

func _distribuir_ponto_vector3() -> void:
	if lista_inimigos.is_empty():
		return
		
	var inimigo = lista_inimigos[indice_atual]
	
	# Verifica se o nó ainda existe e se tem a função antes de tentar rodar a matemática
	if is_instance_valid(inimigo) and inimigo.has_method("receber_novo_destino_patrulha"):
		var map_rid = inimigo.get_world_3d().navigation_map
		
		# Matemática do sorteio de posição
		var dir_aleatoria = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
		var dist_aleatoria = randf_range(raio_patrulha * 0.3, raio_patrulha)
		var alvo_bruto = inimigo.global_position + (dir_aleatoria * dist_aleatoria)
		
		# Consulta ao servidor de navegação
		var ponto_seguro = NavigationServer3D.map_get_closest_point(map_rid, alvo_bruto)
		
		# Envia a coordenada final para o inimigo
		inimigo.receber_novo_destino_patrulha(ponto_seguro)
		
	# Passa para o próximo inimigo na fila para o ciclo seguinte
	indice_atual = (indice_atual + 1) % lista_inimigos.size()
