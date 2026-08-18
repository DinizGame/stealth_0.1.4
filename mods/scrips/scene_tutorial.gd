extends Node3D

@onready var navigation_randon: Node3D = $NavigationRandon

func _ready() -> void:
	_upload_referencias()
	
func _upload_referencias() -> void:
	# 1. Pega os nós principais da cena
	var player_node := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var extraction_node := get_tree().get_first_node_in_group("extraction_area") as Node3D
	
	if not player_node:
		push_error("CRÍTICO: Nenhum nó do grupo 'player' foi encontrado!")
		return
	if not extraction_node:
		push_error("CRÍTICO: Nenhum nó do grupo 'extraction_area' foi encontrado! A escolta falhará.")
		
	# 2. Pega TODOS os nós do grupo "enemy" na cena
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemy")
	
	if enemies.is_empty():
		return
		
	# 3. Repassa as referências para cada inimigo
	for enemy in enemies:
		if "player" in enemy:
			enemy.player = player_node
		else:
			push_error("O inimigo '" + enemy.name + "' não possui a variável 'player'.")
			
		if "extraction_area" in enemy:
			enemy.extraction_area = extraction_node
			
	# 4. Inicia o diretor de navegação
	if is_instance_valid(navigation_randon) and navigation_randon.has_method("iniciar_diretor"):
		navigation_randon.iniciar_diretor(enemies)
