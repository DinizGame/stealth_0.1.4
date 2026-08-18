class_name BaseSavePerfis
extends PanelContainer

signal perfil_selecionado(perfil_id: String)
signal salvar_solicitado
signal restaurar_solicitado
signal restaurar_padrao_solicitado
signal excluir_solicitado(perfil_id: String)

const NOVO_PERFIL_ID := ""

@onready var option: OptionButton = (
	$VBoxContainer2/HBoxContainer/option
)

@onready var botao_restaurar: TextureButton = (
	$VBoxContainer2/HBoxContainer/resset
)

@onready var botao_salvar: TextureButton = (
	$VBoxContainer2/HBoxContainer/salve
)

@onready var botao_excluir: BaseButton = (
	$VBoxContainer2/HBoxContainer/delete
)

var _atualizando_lista: bool = false


func _ready() -> void:
	if not option.item_selected.is_connected(
		_on_option_item_selected
	):
		option.item_selected.connect(
			_on_option_item_selected
		)

	if not botao_restaurar.pressed.is_connected(
		_on_restaurar_pressed
	):
		botao_restaurar.pressed.connect(
			_on_restaurar_pressed
		)

	if not botao_salvar.pressed.is_connected(
		_on_salvar_pressed
	):
		botao_salvar.pressed.connect(
			_on_salvar_pressed
		)

	if not botao_excluir.pressed.is_connected(
		_on_excluir_pressed
	):
		botao_excluir.pressed.connect(
			_on_excluir_pressed
		)

	_atualizar_botoes()


# -----------------------------------------------------------------------------
# LISTA DE PERFIS
# -----------------------------------------------------------------------------

func configurar(
	perfis: Array[Dictionary],
	perfil_selecionado_id: String = NOVO_PERFIL_ID
) -> void:
	_atualizando_lista = true

	option.clear()

	# "Novo Perfil" deve permanecer sempre no topo.
	option.add_item(tr("PROFILE_NEW"))
	option.set_item_metadata(
		0,
		NOVO_PERFIL_ID
	)

	for perfil: Dictionary in perfis:
		var perfil_id: String = str(
			perfil.get("id", "")
		)

		if perfil_id.is_empty():
			continue

		var perfil_nome: String = str(
			perfil.get("nome", "Perfil")
		)

		var indice: int = option.item_count

		option.add_item(perfil_nome)
		option.set_item_metadata(
			indice,
			perfil_id
		)

	# Caso nenhum ID tenha sido informado diretamente,
	# tenta restaurar o último perfil salvo no autoload.
	var id_para_selecionar: String = perfil_selecionado_id

	if id_para_selecionar.is_empty():
		id_para_selecionar = str(
			UserSave.perfil_user
		)

	var perfil_encontrado: bool = _selecionar_sem_emitir(
		id_para_selecionar
	)

	# O perfil salvo no autoload pode ter sido apagado.
	# Nesse caso, volta para "Novo Perfil".
	if not perfil_encontrado:
		option.select(0)
		UserSave.perfil_user = NOVO_PERFIL_ID

	_atualizando_lista = false
	_atualizar_botoes()


func obter_perfil_selecionado() -> String:
	if option.selected < 0:
		return NOVO_PERFIL_ID

	var metadata: Variant = option.get_item_metadata(
		option.selected
	)

	return str(metadata)


func selecionar_perfil(perfil_id: String) -> void:
	_atualizando_lista = true

	var perfil_encontrado: bool = _selecionar_sem_emitir(
		perfil_id
	)

	if not perfil_encontrado:
		option.select(0)
		UserSave.perfil_user = NOVO_PERFIL_ID
	else:
		UserSave.perfil_user = perfil_id

	_atualizando_lista = false
	_atualizar_botoes()


func _selecionar_sem_emitir(
	perfil_id: String
) -> bool:
	# ID vazio representa "Novo Perfil".
	if perfil_id.is_empty():
		option.select(0)
		return true

	for indice: int in range(option.item_count):
		var item_id: String = str(
			option.get_item_metadata(indice)
		)

		if item_id == perfil_id:
			option.select(indice)
			return true

	return false


# -----------------------------------------------------------------------------
# ESTADO VISUAL
# -----------------------------------------------------------------------------

func _atualizar_botoes() -> void:
	var novo_perfil_selecionado: bool = (
		obter_perfil_selecionado().is_empty()
	)

	# Um perfil vazio ainda pode usar Restaurar,
	# mas nesse caso restaurará o personagem padrão.
	botao_restaurar.disabled = false

	# "Novo Perfil" não existe em disco e não pode ser apagado.
	botao_excluir.visible = not novo_perfil_selecionado
	botao_excluir.disabled = novo_perfil_selecionado


# -----------------------------------------------------------------------------
# SINAIS DA INTERFACE
# -----------------------------------------------------------------------------

func _on_option_item_selected(_index: int) -> void:
	_atualizar_botoes()

	if _atualizando_lista:
		return

	var perfil_id: String = obter_perfil_selecionado()

	# Guarda um identificador estável, não o índice da lista.
	UserSave.perfil_user = perfil_id

	# Selecionar "Novo Perfil" não modifica o personagem.
	# Ele permanece exatamente com as alterações atuais.
	if perfil_id.is_empty():
		return

	# Somente perfis já salvos são carregados automaticamente.
	perfil_selecionado.emit(perfil_id)


func _on_restaurar_pressed() -> void:
	var perfil_id: String = obter_perfil_selecionado()

	if perfil_id.is_empty():
		# Quando "Novo Perfil" estiver selecionado,
		# restaura os valores originais do personagem.
		restaurar_padrao_solicitado.emit()
		return

	# Perfil existente: recarrega a versão salva no disco.
	restaurar_solicitado.emit()


func _on_salvar_pressed() -> void:
	# O painel decidirá:
	# - perfil vazio: abrir popup_nome_save;
	# - perfil existente: sobrescrever diretamente.
	salvar_solicitado.emit()


func _on_excluir_pressed() -> void:
	var perfil_id: String = obter_perfil_selecionado()

	if perfil_id.is_empty():
		return

	excluir_solicitado.emit(perfil_id)
