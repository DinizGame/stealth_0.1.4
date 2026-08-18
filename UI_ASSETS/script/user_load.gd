extends AspectRatioContainer

const POPUP_NOME_SAVE := preload("res://UI_ASSETS/cenas/popups/popup_nome_save.tscn")

@onready var player_infor: VBoxContainer = $VBoxContainer/center_jogar/HBoxContainer/PanelMenuUser/player_infor
@export var user_base: PackedScene
@export var grupo_select_user: ButtonGroup

func _ready() -> void:
	_atualizar_lista_interface()

func _atualizar_lista_interface() -> void:
	# Limpa os botões antigos para não duplicar se a função for chamada novamente
	for child in player_infor.get_children():
		child.queue_free()

	# Cria um grupo novo para a lista atual
	grupo_select_user = ButtonGroup.new()
	grupo_select_user.allow_unpress = true

	# Pega o dicionário rápido
	var saves_validos: Dictionary = UserSave.get_valid_saves_metadata()

	for save_id in saves_validos:
		var meta: Dictionary = saves_validos[save_id]
		var slot_instance = user_base.instantiate()
	
		player_infor.add_child(slot_instance)
	
		slot_instance.setup(save_id, meta)
		slot_instance.definir_grupo_select(grupo_select_user)
		slot_instance.carregar_jogo_solicitado.connect(_iniciar_jogo)

func _on_new_user_pressed() -> void:
	var popup = POPUP_NOME_SAVE.instantiate()
	get_tree().root.add_child(popup)
	popup.configurar(
		"POPUP_SAVE_TITULO",
		"POPUP_SAVE_MENSAGEM",
		"POPUP_SAVE_PLACEHOLDER"
	)
	popup.nome_confirmado.connect(_criar_novo_save_com_nome)

func _criar_novo_save_com_nome(nome_novo_jogador: String) -> void:
	# Estrutura base de um novo jogo. Coloque inventário vazio, hp inicial, etc.
	var dados_iniciais_do_jogo = {
		"level": 1,
		"hp": 100,
		"money": 0,
		"progresso": 0,
		"tempo_jogo": 0,
		"posicao_x": 0.0,
		"posicao_y": 0.0,
		"posicao_z": 0.0
	}
	
	# Cria o save pelo Autoload
	var novo_id = UserSave.create_or_update_save(nome_novo_jogador, dados_iniciais_do_jogo)
	
	if novo_id != "":
		# Atualiza a interface visual para o novo botão aparecer instantaneamente
		_atualizar_lista_interface()

# Essa função é acionada pelo sinal do botão instanciado
func _iniciar_jogo(id_escolhido: String) -> void:
	print("Iniciando carregamento pesado para o ID: ", id_escolhido)
	# Agora sim, você lê o arquivo pesado com dados de inventário, NPCs, etc.
	var dados_do_jogo: Dictionary = UserSave.load_game_data(id_escolhido)
	
	if not dados_do_jogo.is_empty():
		print("Bem vindo, ", dados_do_jogo.get("nome_jogador", "Jogador"))
	else:
		push_error("Falha ao abrir os dados do jogo selecionado.")
