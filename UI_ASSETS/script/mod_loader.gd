extends HBoxContainer

signal painel_selecionado(index: int)

@export var pasta_mods: String = "res://mods/extras"
@export var painel_mod_scene: PackedScene

@onready var option_panel: OptionButton = %OptionPanel

var paineis: Array[Control] = []
var scroll_container: ScrollContainer
var tween_scroll: Tween


func _ready() -> void:
	scroll_container = get_parent() as ScrollContainer
	adicionar_painel_fake()

	carregar_mods()

	adicionar_painel_fake()

	await get_tree().process_frame
	await get_tree().process_frame

	if paineis.size() > 0:
		centralizar_painel(0)
		
func adicionar_painel_fake() -> void:
	var painel_fake := painel_mod_scene.instantiate() as Control
	add_child(painel_fake)

	painel_fake.custom_minimum_size.x = get_viewport_rect().size.x / 3.0

	# Fica invisível visualmente, mas ainda ocupa espaço no HBoxContainer
	painel_fake.modulate.a = 0.0

	# Impede que botões/controles internos capturem mouse
	_desativar_interacao_recursiva(painel_fake)
	
func _desativar_interacao_recursiva(node: Node) -> void:
	if node is Control:
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if node is BaseButton:
		var button := node as BaseButton
		button.disabled = true

	for child in node.get_children():
		_desativar_interacao_recursiva(child)

func carregar_mods() -> void:
	var dir := DirAccess.open(pasta_mods)
	if dir == null:
		push_error("Pasta de mods não encontrada: " + pasta_mods)
		return

	var arquivos := dir.get_files()
	arquivos.sort()

	for file_name in arquivos:
		if not file_name.ends_with(".json"):
			continue

		var json_path := pasta_mods.path_join(file_name)
		var dados := carregar_json(json_path)
		print(dados.id)
		if dados.is_empty():
			continue

		adicionar_painel_mod(dados, file_name)


func carregar_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("JSON não encontrado: " + path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	var text := file.get_as_text()

	var json := JSON.new()
	var error := json.parse(text)

	if error != OK:
		push_error("Erro ao ler JSON: " + path)
		return {}

	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("JSON inválido. Esperado Dictionary: " + path)
		return {}

	return json.data


func adicionar_painel_mod(dados: Dictionary, file_name: String) -> void:
	var painel := painel_mod_scene.instantiate() as Control
	add_child(painel)

	painel.configurar(dados)

	var index_painel := paineis.size()

	paineis.append(painel)

	if painel.has_method("_on_painel_selecionado"):
		painel_selecionado.connect(painel._on_painel_selecionado.bind(index_painel))

	if option_panel:
		var titulo_json := str(dados.get("title", file_name.get_basename()))
		var titulo_option := str(titulo_json)

		option_panel.add_item(titulo_option)


func centralizar_painel(index: int) -> void:
	if scroll_container == null:
		push_error("ScrollContainer não encontrado.")
		return

	if index < 0 or index >= paineis.size():
		return

	painel_selecionado.emit(index)

	var painel := paineis[index]

	await get_tree().process_frame

	var centro_painel := painel.position.x + painel.size.x / 2.0
	var centro_scroll := scroll_container.size.x / 2.0

	var alvo_scroll := centro_painel - centro_scroll

	var h_scroll_bar := scroll_container.get_h_scroll_bar()
	alvo_scroll = clamp(alvo_scroll, h_scroll_bar.min_value, h_scroll_bar.max_value)

	if tween_scroll:
		tween_scroll.kill()

	tween_scroll = create_tween()
	tween_scroll.tween_property(
		scroll_container,
		"scroll_horizontal",
		int(alvo_scroll),
		0.35
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_option_panel_item_selected(index: int) -> void:
	centralizar_painel(index)

func _on_previous_pressed() -> void:
	if option_panel.selected > 0:
		option_panel.selected -= 1
		_on_option_panel_item_selected(option_panel.selected)
	
func _on_next_pressed() -> void:
	if option_panel.selected < paineis.size() - 1:
		option_panel.selected += 1
		_on_option_panel_item_selected(option_panel.selected)
