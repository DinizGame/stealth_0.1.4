extends PanelContainer

const POPUP_ALERTA_GERAL := preload(
	"res://UI_ASSETS/cenas/popups/popup_alerta_geral.tscn"
)
const POPUP_NOME_SAVE := preload(
	"res://UI_ASSETS/cenas/popups/popup_nome_save.tscn"
)

@export_group("Cenas da Interface")
@export var base_scroll: PackedScene
@export var base_option: PackedScene
@export var base_color: PackedScene
@export var base_bool: PackedScene
@export var aba_shader_base: PackedScene

@export_group("Catálogo")
## Procura ItemMeshCustomizavel.tres recursivamente nesta pasta.
@export_dir var folder_catalogo_itens: String = "res://assets/player/meshs/"

@onready var tab_container: TabContainer = $VBoxContainer2/HBoxContainer/TabContainer/ColorTab/ShaderCuston
@onready var profile_save: BaseSavePerfis = $VBoxContainer2/base_save
@onready var mark_player: Node3D = %MarkPlayer
@onready var body_select: OptionButton = %BodySelect
@onready var bake_skin_body: SubViewport = %BakeSkinBody
@onready var bake_skin_roughness: SubViewport = %BakeSkinRoughness

var group_list: ButtonGroup
var mesh_base: Dictionary = {}
var mesh_clothes: Dictionary = {}
var bake_color_material: ShaderMaterial
var bake_roughness_material: ShaderMaterial
var item_manager := GerenteItensCustomizacao.new()

var _catalogo_por_id: Dictionary = {}
var _perfil_atual_id: String = ""
var _perfil_atual_nome: String = ""
var _snapshot_salvo: String = ""
var _estado_padrao: Dictionary = {}
var _snapshot_padrao: String = ""
var _nome_popup_resultado: String = ""
var _saida_sem_salvar_confirmada: bool = false


func _ready() -> void:
	custom_minimum_size.x = get_viewport_rect().size.x / 3.0
	group_list = ButtonGroup.new()
	group_list.allow_unpress = true

	_prepare_bake_materials()

	if not _find_character_slots():
		return

	item_manager.configurar(
		mesh_base,
		mesh_clothes,
		bake_skin_body.get_texture(),
		bake_skin_roughness.get_texture()
	)

	if not body_select.item_selected.is_connected(_on_body_selected):
		body_select.item_selected.connect(_on_body_selected)

	_populate_body_select()

	if body_select.item_count > 0:
		body_select.select(0)
		_on_body_selected(0)
	else:
		_clear_tabs()
		push_warning(
			"Nenhum corpo customizável encontrado em: %s"
			% folder_catalogo_itens
		)

	_estado_padrao = _capturar_estado_atual().duplicate(true)
	_snapshot_padrao = _criar_snapshot_atual()
	_snapshot_salvo = _snapshot_padrao

	_configurar_lista_perfis()

	var perfil_inicial_id: String = profile_save.obter_perfil_selecionado()

	if not perfil_inicial_id.is_empty():
		@warning_ignore("redundant_await")
		await _carregar_perfil(perfil_inicial_id)


func _prepare_bake_materials() -> void:
	var color_rect := bake_skin_body.get_node_or_null("SkinTemp") as TextureRect
	var roughness_rect := bake_skin_roughness.get_node_or_null(
		"RoughnessTemp"
	) as TextureRect

	if color_rect and color_rect.material is ShaderMaterial:
		bake_color_material = (
			color_rect.material as ShaderMaterial
		).duplicate() as ShaderMaterial
		color_rect.material = bake_color_material
	else:
		push_error("BakeSkinBody/SkinTemp precisa de um ShaderMaterial.")

	if roughness_rect and roughness_rect.material is ShaderMaterial:
		bake_roughness_material = (
			roughness_rect.material as ShaderMaterial
		).duplicate() as ShaderMaterial
		roughness_rect.material = bake_roughness_material
	else:
		push_error(
			"BakeSkinRoughness/RoughnessTemp precisa de um ShaderMaterial."
		)


func _find_character_slots() -> bool:
	for body_player: Node in mark_player.get_children():
		if not body_player.is_in_group("BodyPlayer"):
			continue

		var human: Node = body_player.get_node_or_null("Human")
		if human == null:
			push_error("BodyPlayer não possui o nó Human.")
			return false

		var base_slots: Variant = human.get("mesh_base")
		var clothes_slots: Variant = human.get("mesh_clothes")

		if base_slots is Dictionary:
			mesh_base = base_slots
		if clothes_slots is Dictionary:
			mesh_clothes = clothes_slots
		return true

	push_error("Nenhum BodyPlayer foi encontrado em MarkPlayer.")
	return false


# -----------------------------------------------------------------------------
# CATÁLOGO
# -----------------------------------------------------------------------------

func _populate_body_select() -> void:
	body_select.clear()
	_catalogo_por_id.clear()

	var items: Array[ItemMeshCustomizavel] = []
	_scan_item_resources(folder_catalogo_itens.trim_suffix("/"), items)
	items.sort_custom(_sort_items)

	for item: ItemMeshCustomizavel in items:
		var item_id: String = String(item.id)

		if _catalogo_por_id.has(item_id):
			push_warning("ID de item duplicado ignorado: %s" % item_id)
			continue

		_catalogo_por_id[item_id] = item

		if item.slot != ItemMeshCustomizavel.Slot.BODY:
			continue

		var index: int = body_select.item_count
		body_select.add_item(item.get_titulo_exibicao())
		body_select.set_item_metadata(index, item)

		if item.miniatura:
			body_select.set_item_icon(index, item.miniatura)


func _scan_item_resources(
	path: String,
	result: Array[ItemMeshCustomizavel]
) -> void:
	for entry: String in ResourceLoader.list_directory(path):
		if entry.ends_with("/"):
			_scan_item_resources(
				path.path_join(entry.trim_suffix("/")),
				result
			)
			continue

		if not entry.ends_with(".tres") and not entry.ends_with(".res"):
			continue

		var resource: Resource = ResourceLoader.load(path.path_join(entry))

		if resource is ItemMeshCustomizavel:
			var item := resource as ItemMeshCustomizavel
			if item.is_valid():
				result.append(item)


func _sort_items(
	a: ItemMeshCustomizavel,
	b: ItemMeshCustomizavel
) -> bool:
	return (
		a.get_titulo_exibicao().naturalnocasecmp_to(
			b.get_titulo_exibicao()
		) < 0
	)


func _on_body_selected(index: int) -> void:
	if index < 0 or index >= body_select.item_count:
		return

	var metadata: Variant = body_select.get_item_metadata(index)
	if not metadata is ItemMeshCustomizavel:
		return

	var item := metadata as ItemMeshCustomizavel
	var installed: Dictionary = item_manager.instalar_item(item)

	if installed.is_empty():
		return

	var materials: Dictionary = installed.get("materials", {})
	_build_item_interface(item, materials)


## Futuras listas de roupas podem chamar esta mesma função.
func install_item(item: ItemMeshCustomizavel) -> bool:
	var installed: Dictionary = item_manager.instalar_item(item)

	if installed.is_empty():
		return false

	var materials: Dictionary = installed.get("materials", {})
	_build_item_interface(item, materials)
	return true


func remove_item(slot: int) -> void:
	item_manager.remover_item(slot)


# -----------------------------------------------------------------------------
# PERFIS
# -----------------------------------------------------------------------------

func _configurar_lista_perfis() -> void:
	if not profile_save.perfil_selecionado.is_connected(
		_on_perfil_selecionado
	):
		profile_save.perfil_selecionado.connect(
			_on_perfil_selecionado
		)

	if not profile_save.salvar_solicitado.is_connected(
		_on_salvar_perfil_solicitado
	):
		profile_save.salvar_solicitado.connect(
			_on_salvar_perfil_solicitado
		)

	if not profile_save.restaurar_solicitado.is_connected(
		_on_restaurar_perfil_solicitado
	):
		profile_save.restaurar_solicitado.connect(
			_on_restaurar_perfil_solicitado
		)

	if not profile_save.restaurar_padrao_solicitado.is_connected(
		_on_restaurar_padrao_solicitado
	):
		profile_save.restaurar_padrao_solicitado.connect(
			_on_restaurar_padrao_solicitado
		)

	if not profile_save.excluir_solicitado.is_connected(
		_on_excluir_perfil_solicitado
	):
		profile_save.excluir_solicitado.connect(
			_on_excluir_perfil_solicitado
		)

	_atualizar_lista_perfis(str(UserSave.perfil_user))


func _atualizar_lista_perfis(
	perfil_selecionado_id: String = ""
) -> void:
	profile_save.configurar(
		CharacterProfileStorage.listar_perfis(),
		perfil_selecionado_id
	)


func _on_perfil_selecionado(perfil_id: String) -> void:
	# "Novo Perfil" apenas muda o destino do próximo salvamento.
	# O personagem permanece exatamente como está.
	if perfil_id.is_empty():
		_perfil_atual_id = ""
		_perfil_atual_nome = ""
		return

	@warning_ignore("redundant_await")
	await _carregar_perfil(perfil_id)


func _on_restaurar_perfil_solicitado() -> void:
	var perfil_id: String = profile_save.obter_perfil_selecionado()

	if perfil_id.is_empty():
		return

	@warning_ignore("redundant_await")
	await _carregar_perfil(perfil_id)


func _on_restaurar_padrao_solicitado() -> void:
	if _estado_padrao.is_empty():
		push_warning("O estado padrão do personagem não foi registrado.")
		return

	if not _aplicar_estado_customizacao(_estado_padrao):
		push_warning("Não foi possível restaurar o personagem padrão.")
		return

	_perfil_atual_id = ""
	_perfil_atual_nome = ""
	UserSave.perfil_user = ""

	profile_save.selecionar_perfil("")
	_snapshot_salvo = _snapshot_padrao
	print("Customização restaurada para o padrão.")


func _on_salvar_perfil_solicitado() -> void:
	var perfil_selecionado_id: String = (
		profile_save.obter_perfil_selecionado()
	)

	if perfil_selecionado_id.is_empty():
		var nome_novo: String = await _solicitar_nome_novo_perfil()

		if nome_novo.is_empty():
			return

		var novo_id: String = CharacterProfileStorage.gerar_id_perfil()
		await _salvar_perfil(novo_id, nome_novo)
		return

	var nome_perfil: String = _perfil_atual_nome

	if nome_perfil.is_empty():
		var dados_perfil: Dictionary = (
			CharacterProfileStorage.carregar_perfil(
				perfil_selecionado_id
			)
		)
		nome_perfil = str(
			dados_perfil.get("nome", perfil_selecionado_id)
		)

	await _salvar_perfil(
		perfil_selecionado_id,
		nome_perfil
	)


func _on_excluir_perfil_solicitado(perfil_id: String) -> void:
	if perfil_id.is_empty():
		return

	var erro: Error = _excluir_perfil_do_disco(perfil_id)

	if erro != OK:
		push_error(
			"Não foi possível excluir o perfil '%s'. Erro: %d"
			% [perfil_id, erro]
		)
		return

	# A aparência atual permanece na tela, mas deixa de possuir
	# um perfil salvo associado.
	_perfil_atual_id = ""
	_perfil_atual_nome = ""
	UserSave.perfil_user = ""

	_atualizar_lista_perfis("")

	# Como o arquivo foi apagado, a aparência atual passa a ser
	# considerada uma alteração ainda não salva.
	_snapshot_salvo = ""

	print("Perfil de customização excluído: ", perfil_id)


func _solicitar_nome_novo_perfil() -> String:
	_nome_popup_resultado = ""

	var popup = POPUP_NOME_SAVE.instantiate()
	get_tree().root.add_child(popup)
	popup.configurar(
		"POPUP_PROFILE_NAME_TITLE",
		"POPUP_PROFILE_NAME_MESSAGE",
		"POPUP_PROFILE_NAME_PLACEHOLDER"
	)
	popup.nome_confirmado.connect(_on_nome_perfil_confirmado)

	await popup.tree_exited
	return _nome_popup_resultado


func _on_nome_perfil_confirmado(nome: String) -> void:
	_nome_popup_resultado = nome.strip_edges()


func _salvar_perfil(perfil_id: String, nome: String) -> bool:
	var modo_cor_anterior: int = bake_skin_body.render_target_update_mode
	var modo_roughness_anterior: int = (
		bake_skin_roughness.render_target_update_mode
	)

	bake_skin_body.render_target_update_mode = SubViewport.UPDATE_ONCE
	bake_skin_roughness.render_target_update_mode = SubViewport.UPDATE_ONCE

	await RenderingServer.frame_post_draw

	var imagem_cor: Image = bake_skin_body.get_texture().get_image()
	var imagem_roughness: Image = (
		bake_skin_roughness.get_texture().get_image()
	)

	@warning_ignore("int_as_enum_without_cast")
	bake_skin_body.render_target_update_mode = modo_cor_anterior
	@warning_ignore("int_as_enum_without_cast")
	bake_skin_roughness.render_target_update_mode = modo_roughness_anterior

	var dados_customizacao: Dictionary = _capturar_estado_atual()
	var erro: Error = CharacterProfileStorage.salvar_perfil(
		perfil_id,
		nome,
		dados_customizacao,
		imagem_cor,
		imagem_roughness
	)

	if erro != OK:
		push_error(
			"Não foi possível salvar o perfil '%s'. Erro: %d"
			% [nome, erro]
		)
		return false

	_perfil_atual_id = perfil_id
	_perfil_atual_nome = nome.strip_edges()
	UserSave.perfil_user = perfil_id

	_snapshot_salvo = _criar_snapshot_atual()
	_atualizar_lista_perfis(perfil_id)

	print("Perfil de customização salvo: ", _perfil_atual_nome)
	return true


func _carregar_perfil(perfil_id: String) -> bool:
	var dados: Dictionary = CharacterProfileStorage.carregar_perfil(
		perfil_id
	)

	if dados.is_empty():
		push_warning("Não foi possível carregar o perfil: %s" % perfil_id)
		return false

	if not _aplicar_estado_customizacao(dados):
		return false

	_perfil_atual_id = perfil_id
	_perfil_atual_nome = str(dados.get("nome", perfil_id))
	UserSave.perfil_user = perfil_id

	_snapshot_salvo = _criar_snapshot_atual()
	profile_save.selecionar_perfil(perfil_id)
	return true


func _aplicar_estado_customizacao(dados: Dictionary) -> bool:
	var itens_salvos: Variant = dados.get("itens", [])

	if not itens_salvos is Array:
		push_warning("O estado não possui uma lista de itens válida.")
		return false

	var itens_preparados: Array[Dictionary] = []
	var possui_corpo: bool = false

	for entrada: Variant in itens_salvos:
		if not entrada is Dictionary:
			continue

		var dados_item: Dictionary = entrada
		var item_id: String = str(dados_item.get("item_id", ""))
		var item: ItemMeshCustomizavel = _catalogo_por_id.get(
			item_id
		) as ItemMeshCustomizavel

		if item == null:
			push_warning("Item do perfil não encontrado: %s" % item_id)
			continue

		if item.slot == ItemMeshCustomizavel.Slot.BODY:
			possui_corpo = true

		itens_preparados.append({
			"item": item,
			"dados": dados_item
		})

	if not possui_corpo:
		push_warning("O estado não possui um corpo válido.")
		return false

	var slots_instalados: Array = item_manager.installed_items.keys()

	for slot: Variant in slots_instalados:
		item_manager.remover_item(int(slot))

	var corpo_instalado: Dictionary = {}
	var recurso_corpo: ItemMeshCustomizavel

	for entrada_preparada: Dictionary in itens_preparados:
		var item := entrada_preparada.get(
			"item"
		) as ItemMeshCustomizavel
		var dados_item: Dictionary = entrada_preparada.get(
			"dados",
			{}
		)
		var instalado: Dictionary = item_manager.instalar_item(item)

		if instalado.is_empty():
			continue

		_aplicar_parametros_salvos(
			item,
			instalado,
			dados_item
		)

		if item.slot == ItemMeshCustomizavel.Slot.BODY:
			corpo_instalado = instalado
			recurso_corpo = item

	if corpo_instalado.is_empty() or recurso_corpo == null:
		push_warning("Não foi possível instalar o corpo salvo.")
		return false

	_selecionar_corpo_sem_emitir(recurso_corpo.id)

	var materiais_corpo: Dictionary = corpo_instalado.get(
		"materials",
		{}
	)

	_build_item_interface(
		recurso_corpo,
		materiais_corpo
	)

	return true


func _selecionar_corpo_sem_emitir(item_id: StringName) -> void:
	for index: int in range(body_select.item_count):
		var metadata: Variant = body_select.get_item_metadata(index)

		if metadata is ItemMeshCustomizavel:
			var item := metadata as ItemMeshCustomizavel

			if item.id == item_id:
				body_select.select(index)
				return


func _aplicar_parametros_salvos(
	item: ItemMeshCustomizavel,
	instalado: Dictionary,
	dados_item: Dictionary
) -> void:
	var parametros_salvos: Variant = dados_item.get("parametros", {})

	if not parametros_salvos is Dictionary:
		return

	var valores: Dictionary = parametros_salvos
	var materiais: Dictionary = instalado.get("materials", {})

	for parametro: ParametroShaderEditavel in item.parametros:
		var parametro_id: String = String(parametro.id)

		if not valores.has(parametro_id):
			continue

		var material_alvo: ShaderMaterial = _get_parameter_material(
			parametro,
			materiais
		)

		if material_alvo == null:
			continue

		_aplicar_valor_salvo(
			material_alvo,
			parametro,
			valores[parametro_id]
		)


func _aplicar_valor_salvo(
	material_alvo: ShaderMaterial,
	parametro: ParametroShaderEditavel,
	valor_salvo: Variant
) -> void:
	match parametro.tipo_controle:
		ParametroShaderEditavel.TipoControle.FLOAT:
			if typeof(valor_salvo) in [TYPE_FLOAT, TYPE_INT]:
				material_alvo.set_shader_parameter(
					parametro.shader_parameter,
					float(valor_salvo)
				)

		ParametroShaderEditavel.TipoControle.COLOR:
			if valor_salvo is Array and valor_salvo.size() >= 4:
				material_alvo.set_shader_parameter(
					parametro.shader_parameter,
					Color(
						float(valor_salvo[0]),
						float(valor_salvo[1]),
						float(valor_salvo[2]),
						float(valor_salvo[3])
					)
				)

		ParametroShaderEditavel.TipoControle.TEXTURE:
			var caminho_textura: String = str(valor_salvo)

			if caminho_textura.is_empty():
				material_alvo.set_shader_parameter(
					parametro.shader_parameter,
					null
				)
				return

			var textura: Resource = ResourceLoader.load(
				caminho_textura,
				"Texture2D"
			)

			if textura is Texture2D:
				material_alvo.set_shader_parameter(
					parametro.shader_parameter,
					textura
				)
			else:
				push_warning(
					"Textura salva não encontrada: %s"
					% caminho_textura
				)

		ParametroShaderEditavel.TipoControle.BOOL:
			if typeof(valor_salvo) == TYPE_BOOL:
				material_alvo.set_shader_parameter(
					parametro.shader_parameter,
					valor_salvo
				)


func _capturar_estado_atual() -> Dictionary:
	var itens: Array[Dictionary] = []
	var slots: Array = item_manager.installed_items.keys()
	slots.sort()

	for slot: Variant in slots:
		var instalado: Dictionary = item_manager.installed_items.get(
			slot,
			{}
		)
		var item := instalado.get("item") as ItemMeshCustomizavel

		if item == null:
			continue

		var materiais: Dictionary = instalado.get("materials", {})
		var parametros: Dictionary = {}

		for parametro: ParametroShaderEditavel in item.parametros:
			var material_alvo: ShaderMaterial = _get_parameter_material(
				parametro,
				materiais
			)

			if material_alvo == null:
				continue

			var valor_atual: Variant = material_alvo.get_shader_parameter(
				parametro.shader_parameter
			)
			parametros[String(parametro.id)] = _serializar_valor_parametro(
				parametro,
				valor_atual
			)

		itens.append({
			"item_id": String(item.id),
			"slot": item.slot,
			"parametros": parametros
		})

	return {"itens": itens}


func _serializar_valor_parametro(
	parametro: ParametroShaderEditavel,
	valor: Variant
) -> Variant:
	match parametro.tipo_controle:
		ParametroShaderEditavel.TipoControle.FLOAT:
			if typeof(valor) in [TYPE_FLOAT, TYPE_INT]:
				return float(valor)
			return 0.0

		ParametroShaderEditavel.TipoControle.COLOR:
			if typeof(valor) == TYPE_COLOR:
				var cor: Color = valor
				return [cor.r, cor.g, cor.b, cor.a]
			return [1.0, 1.0, 1.0, 1.0]

		ParametroShaderEditavel.TipoControle.TEXTURE:
			if valor is Texture2D:
				return (valor as Texture2D).resource_path
			return ""

		ParametroShaderEditavel.TipoControle.BOOL:
			if typeof(valor) == TYPE_BOOL:
				return valor
			return false

	return null


func _criar_snapshot_atual() -> String:
	return JSON.stringify(
		_capturar_estado_atual(),
		"",
		true,
		true
	)


func tem_alteracoes_nao_salvas() -> bool:
	return _criar_snapshot_atual() != _snapshot_salvo


func solicitar_saida() -> bool:
	if not tem_alteracoes_nao_salvas():
		return true

	_saida_sem_salvar_confirmada = false

	var popup = POPUP_ALERTA_GERAL.instantiate()
	get_tree().root.add_child(popup)
	popup.configurar(
		"POPUP_PROFILE_UNSAVED_TITLE",
		"POPUP_PROFILE_UNSAVED_MESSAGE",
		"BTN_CONTINUAR_EDITANDO",
		"BTN_SAIR_SEM_SALVAR"
	)
	popup.confirmado.connect(_on_saida_sem_salvar_confirmada)

	await popup.tree_exited
	return _saida_sem_salvar_confirmada


func _on_saida_sem_salvar_confirmada() -> void:
	_saida_sem_salvar_confirmada = true


func _excluir_perfil_do_disco(perfil_id: String) -> Error:
	var pasta_perfil: String = CharacterProfileStorage.ROOT_DIR.path_join(
		perfil_id
	)

	if not DirAccess.dir_exists_absolute(pasta_perfil):
		return ERR_DOES_NOT_EXIST

	return _remover_diretorio_recursivo(pasta_perfil)


func _remover_diretorio_recursivo(path: String) -> Error:
	var diretorio := DirAccess.open(path)

	if diretorio == null:
		return DirAccess.get_open_error()

	diretorio.list_dir_begin()
	var entrada: String = diretorio.get_next()

	while not entrada.is_empty():
		var caminho_entrada: String = path.path_join(entrada)
		var entrada_e_diretorio: bool = diretorio.current_is_dir()

		if entrada_e_diretorio:
			var erro_subpasta: Error = _remover_diretorio_recursivo(
				caminho_entrada
			)

			if erro_subpasta != OK:
				diretorio.list_dir_end()
				return erro_subpasta
		else:
			var erro_arquivo: Error = DirAccess.remove_absolute(
				caminho_entrada
			)

			if erro_arquivo != OK:
				diretorio.list_dir_end()
				return erro_arquivo

		entrada = diretorio.get_next()

	diretorio.list_dir_end()
	return DirAccess.remove_absolute(path)


# -----------------------------------------------------------------------------
# INTERFACE
# -----------------------------------------------------------------------------

func _build_item_interface(
	item: ItemMeshCustomizavel,
	materials: Dictionary
) -> void:
	_clear_tabs()
	var tabs: Dictionary = {}

	for parameter: ParametroShaderEditavel in item.parametros:
		var material_alvo: ShaderMaterial = _get_parameter_material(
			parameter,
			materials
		)
		if material_alvo == null:
			push_warning(
				"Material não encontrado para o parâmetro: %s"
				% parameter.id
			)
			continue

		var tab_name: String = String(parameter.aba)
		if tab_name.is_empty():
			tab_name = "Geral"

		if not tabs.has(tab_name):
			tabs[tab_name] = _create_tab(tab_name)

		_create_parameter_control(
			tabs[tab_name] as VBoxContainer,
			parameter,
			material_alvo
		)


func _get_parameter_material(
	parameter: ParametroShaderEditavel,
	materials: Dictionary
) -> ShaderMaterial:
	match parameter.alvo_material:
		ParametroShaderEditavel.AlvoMaterial.MATERIAL_ITEM:
			return materials.get(parameter.surface_index) as ShaderMaterial
		ParametroShaderEditavel.AlvoMaterial.BAKE_COR:
			return bake_color_material
		ParametroShaderEditavel.AlvoMaterial.BAKE_ROUGHNESS:
			return bake_roughness_material

	return null


func _create_parameter_control(
	container: VBoxContainer,
	parameter: ParametroShaderEditavel,
	material_alvo: ShaderMaterial
) -> void:
	var scene: PackedScene

	match parameter.tipo_controle:
		ParametroShaderEditavel.TipoControle.FLOAT:
			scene = base_scroll
		ParametroShaderEditavel.TipoControle.COLOR:
			scene = base_color
		ParametroShaderEditavel.TipoControle.TEXTURE:
			scene = base_option
		ParametroShaderEditavel.TipoControle.BOOL:
			scene = base_bool

	if scene == null:
		return

	var control: Node = scene.instantiate()
	container.add_child(control)
	var data := {
		"nome": parameter.get_titulo_exibicao(),
		"material": material_alvo,
		"shader_parameter": parameter.shader_parameter,
		"valor": material_alvo.get_shader_parameter(
			parameter.shader_parameter
		),
		"min": parameter.valor_minimo,
		"max": parameter.valor_maximo,
		"step": parameter.incremento,
		"option_folder": parameter.pasta_opcoes
	}

	if control.has_method("configurar"):
		control.call("configurar", data)
	if control.has_method("definir_grupo_select"):
		control.call("definir_grupo_select", group_list)


func _clear_tabs() -> void:
	for tab: Node in tab_container.get_children():
		tab_container.remove_child(tab)
		tab.queue_free()


func _create_tab(tab_name: String) -> VBoxContainer:
	var tab: Control = aba_shader_base.instantiate()
	tab.name = tab_name
	tab_container.add_child(tab)
	return tab.get_node("SuporteParameter") as VBoxContainer
