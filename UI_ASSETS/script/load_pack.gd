extends Control

enum TipoErro {
	NENHUM,
	PACK_OBRIGATORIO,
	PACK_EXTRA
}

@export_group("Inicialização")
@export_file("*.tscn") var proxima_cena: String = ""

@export_group("Execução pelo Editor")
## Caminho absoluto dos packs obrigatórios usado apenas ao executar pelo editor.
@export var caminho_obrigatorios_editor: String = ""
## Caminho absoluto dos packs opcionais usado apenas ao executar pelo editor.
@export var caminho_extras_editor: String = ""

@export_group("Execução Exportada")
## Pasta vizinha ao executável contendo os packs obrigatórios.
@export var pasta_obrigatorios_exe: String = "Packs"
## Pasta vizinha ao executável contendo os packs opcionais/DLCs.
@export var pasta_extras_exe: String = "DLCs"

@export_group("Packs")
## Nomes dos packs obrigatórios que devem existir.
@export var packs_obrigatorios: Array[String] = []
## Permite que packs carregados substituam recursos existentes.
@export var substituir_recursos: bool = false

@onready var progress_bar: ProgressBar = $AspectRatioContainer/VBoxContainer/LoadProgress/ProgressBar
@onready var label_infor: Label = $AspectRatioContainer/VBoxContainer/LoadProgress/LabelInfor

var _carregando: bool = false
var _packs_obrigatorios_concluidos: bool = false
var _packs_carregados: Dictionary = {}

var _popup_erro: ConfirmationDialog
var _tipo_erro_atual: TipoErro = TipoErro.NENHUM


func _ready() -> void:
	_configurar_progress_bar()
	_criar_popup_erro()
	await _carregar_packs_obrigatorios()


func _configurar_progress_bar() -> void:
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0


func _obter_diretorio_obrigatorios() -> String:
	if OS.has_feature("editor"):
		print(caminho_obrigatorios_editor)
		return caminho_obrigatorios_editor.strip_edges()
	else:
		print(caminho_obrigatorios_editor)
		
	var diretorio_exe: String = OS.get_executable_path().get_base_dir()
	return diretorio_exe.path_join(pasta_obrigatorios_exe)


func _obter_diretorio_extras() -> String:
	if OS.has_feature("editor"):
		return caminho_extras_editor.strip_edges()

	var diretorio_exe: String = OS.get_executable_path().get_base_dir()
	return diretorio_exe.path_join(pasta_extras_exe)


func _resolver_pack(entrada: String, diretorio_base: String) -> String:
	var caminho: String = entrada.strip_edges()

	if caminho.is_absolute_path():
		return caminho

	return diretorio_base.path_join(caminho)


func _carregar_packs_obrigatorios() -> void:
	if _carregando:
		return

	_carregando = true
	_packs_obrigatorios_concluidos = false
	_tipo_erro_atual = TipoErro.NENHUM

	progress_bar.value = 0.0
	progress_bar.max_value = maxf(float(packs_obrigatorios.size()), 1.0)
	label_infor.text = "Verificando packs obrigatórios..."

	await get_tree().process_frame

	if packs_obrigatorios.is_empty():
		progress_bar.value = progress_bar.max_value
		_carregando = false
		_packs_obrigatorios_concluidos = true
		await _carregar_extras()
		return

	var diretorio_base: String = _obter_diretorio_obrigatorios()

	if diretorio_base.is_empty():
		_carregando = false
		_falha_obrigatoria("O caminho dos packs obrigatórios não foi configurado.")
		return

	var falhas: PackedStringArray = PackedStringArray()

	for index in range(packs_obrigatorios.size()):
		var entrada: String = packs_obrigatorios[index].strip_edges()

		if entrada.is_empty():
			falhas.append("Entrada vazia no índice %d" % index)
			progress_bar.value = float(index + 1)
			continue

		var pack_path: String = _resolver_pack(entrada, diretorio_base)

		label_infor.text = "Carregando pack obrigatório:\n%s" % pack_path.get_file()
		await get_tree().process_frame

		if _packs_carregados.has(pack_path):
			progress_bar.value = float(index + 1)
			continue

		if not FileAccess.file_exists(pack_path):
			falhas.append(pack_path)
			progress_bar.value = float(index + 1)
			await get_tree().process_frame
			continue

		if ProjectSettings.load_resource_pack(pack_path, substituir_recursos):
			_packs_carregados[pack_path] = true
		else:
			falhas.append(pack_path)

		progress_bar.value = float(index + 1)
		await get_tree().process_frame

	_carregando = false

	if not falhas.is_empty():
		var mensagem: String = "Não foi possível carregar todos os packs obrigatórios.\n\n"
		mensagem += "A instalação pode estar incompleta ou corrompida.\n\nFalhas:"

		for falha in falhas:
			mensagem += "\n• %s" % falha

		_falha_obrigatoria(mensagem)
		return

	_packs_obrigatorios_concluidos = true
	label_infor.text = "Packs obrigatórios carregados."

	await get_tree().process_frame
	await _carregar_extras()


func _carregar_extras() -> void:
	if not _packs_obrigatorios_concluidos or _carregando:
		return

	var diretorio: String = _obter_diretorio_extras()

	# Packs extras são opcionais. Caminho vazio ou pasta inexistente não são erros.
	if diretorio.is_empty() or not DirAccess.dir_exists_absolute(diretorio):
		_finalizar()
		return

	var dir: DirAccess = DirAccess.open(diretorio)

	if dir == null:
		_finalizar()
		return

	var packs: PackedStringArray = _buscar_packs(dir, diretorio)

	if packs.is_empty():
		_finalizar()
		return

	var pendentes: PackedStringArray = PackedStringArray()

	for pack_path in packs:
		if not _packs_carregados.has(pack_path):
			pendentes.append(pack_path)

	if pendentes.is_empty():
		_finalizar()
		return

	_carregando = true
	_tipo_erro_atual = TipoErro.NENHUM

	progress_bar.value = 0.0
	progress_bar.max_value = float(pendentes.size())

	var falhas: PackedStringArray = PackedStringArray()

	for index in range(pendentes.size()):
		var pack_path: String = pendentes[index]

		label_infor.text = "Carregando Pack/DLC extra:\n%s" % pack_path.get_file()
		await get_tree().process_frame

		if ProjectSettings.load_resource_pack(pack_path, substituir_recursos):
			_packs_carregados[pack_path] = true
		else:
			falhas.append(pack_path)

		progress_bar.value = float(index + 1)
		await get_tree().process_frame

	_carregando = false

	if not falhas.is_empty():
		var mensagem: String = "%d Pack(s)/DLC(s) extra(s) não puderam ser carregados." % falhas.size()
		mensagem += "\n\nVocê pode tentar novamente ou iniciar o jogo sem eles."
		mensagem += "\n\nFalhas:"

		for falha in falhas:
			mensagem += "\n• %s" % falha.get_file()

		_falha_extra(mensagem)
		return

	_finalizar()


func _buscar_packs(dir: DirAccess, diretorio: String) -> PackedStringArray:
	var packs: PackedStringArray = PackedStringArray()

	for arquivo in dir.get_files():
		var extensao: String = arquivo.get_extension().to_lower()

		if extensao == "pck" or extensao == "zip":
			packs.append(diretorio.path_join(arquivo))

	packs.sort()
	return packs


func _criar_popup_erro() -> void:
	_popup_erro = ConfirmationDialog.new()
	_popup_erro.title = "Erro ao carregar conteúdo"
	_popup_erro.dialog_autowrap = true
	_popup_erro.dialog_close_on_escape = false

	add_child(_popup_erro)

	_popup_erro.confirmed.connect(_on_tentar_novamente)
	_popup_erro.get_cancel_button().pressed.connect(_on_acao_secundaria_popup)


func _mostrar_erro(mensagem: String) -> void:
	_popup_erro.dialog_text = mensagem
	_popup_erro.popup_centered_clamped(Vector2i(720, 360))


func _falha_obrigatoria(mensagem: String) -> void:
	_carregando = false
	_tipo_erro_atual = TipoErro.PACK_OBRIGATORIO
	_packs_obrigatorios_concluidos = false

	progress_bar.value = 0.0
	label_infor.text = "Falha ao carregar packs obrigatórios."

	_popup_erro.title = "Erro nos packs obrigatórios"
	_popup_erro.ok_button_text = "Tentar novamente"
	_popup_erro.cancel_button_text = "Sair do jogo"

	_mostrar_erro(mensagem)


func _falha_extra(mensagem: String) -> void:
	_carregando = false
	_tipo_erro_atual = TipoErro.PACK_EXTRA

	progress_bar.value = 0.0
	label_infor.text = "Falha ao carregar Packs/DLCs extras."

	_popup_erro.title = "Erro ao carregar conteúdo extra"
	_popup_erro.ok_button_text = "Tentar novamente"
	_popup_erro.cancel_button_text = "Ignorar e iniciar"

	_mostrar_erro(mensagem)


func _on_tentar_novamente() -> void:
	_popup_erro.hide()

	match _tipo_erro_atual:
		TipoErro.PACK_OBRIGATORIO:
			_tipo_erro_atual = TipoErro.NENHUM
			await _carregar_packs_obrigatorios()

		TipoErro.PACK_EXTRA:
			_tipo_erro_atual = TipoErro.NENHUM
			await _carregar_extras()


func _on_acao_secundaria_popup() -> void:
	_popup_erro.hide()

	match _tipo_erro_atual:
		TipoErro.PACK_OBRIGATORIO:
			label_infor.text = "Encerrando o jogo..."
			get_tree().quit()

		TipoErro.PACK_EXTRA:
			_tipo_erro_atual = TipoErro.NENHUM
			_carregando = false
			_finalizar()


func _finalizar() -> void:
	_carregando = false

	if not _packs_obrigatorios_concluidos:
		push_error("LoadPack: tentativa de iniciar antes da conclusão dos packs obrigatórios.")
		return

	progress_bar.value = progress_bar.max_value

	if _packs_carregados.is_empty():
		label_infor.text = "Iniciando jogo..."
	else:
		label_infor.text = "%d Pack(s) carregado(s)." % _packs_carregados.size()

	await get_tree().process_frame

	if proxima_cena.is_empty():
		push_warning("LoadPack: configure 'proxima_cena' no Inspector.")
		return

	var erro: Error = get_tree().change_scene_to_file(proxima_cena)

	if erro != OK:
		push_error("LoadPack: erro %d ao abrir '%s'." % [erro, proxima_cena])
