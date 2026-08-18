extends Node


@warning_ignore("unused_signal")
signal atualizar_resolution

@warning_ignore("unused_signal")
signal ajuste_fonte_size(_index)

@warning_ignore("unused_signal")
signal atualizar_plataforma

@warning_ignore("unused_signal")
signal atualizar_idioma

@warning_ignore("unused_signal")
signal resetar_inputs

@warning_ignore("unused_signal")
signal resetar_audio

@warning_ignore("unused_signal")
signal tema_alterado(novo_tema: Theme, index: int)

@warning_ignore("unused_signal")
signal inputs_alterados

@warning_ignore("unused_signal")
signal estado_secao_alterado(secao: int)


const Storage = preload(
	"res://ScriptGlobais/settings/config_storage.gd"
)
const VideoSettings = preload(
	"res://ScriptGlobais/settings/video_settings.gd"
)
const AudioSettings = preload(
	"res://ScriptGlobais/settings/audio_settings.gd"
)
const LanguageSettings = preload(
	"res://ScriptGlobais/settings/language_settings.gd"
)
const InputSettings = preload(
	"res://ScriptGlobais/settings/input_settings.gd"
)

const DEFAULT_CONFIG := "res://Config/default.cfg"
const USER_CONFIG := "user://user_local.cfg"


enum TipoControle {
	PC,
	XBOX,
	PLAYSTATION
}

enum SecaoConfig {
	JOGO,
	VIDEO,
	AUDIO,
	INPUTS
}


var video_settings
var audio_settings
var language_settings
var input_settings

var tipo_controle := TipoControle.PC

var _snapshot_edicao: Dictionary = {}
var _snapshots_padrao: Dictionary = {}
var _edicao_ativa := false


var resolution_multiplier: int:
	get:
		return video_settings.resolution_multiplier
	set(valor):
		video_settings.resolution_multiplier = valor


var interface_scale_index: int:
	get:
		return video_settings.interface_scale_index
	set(valor):
		video_settings.interface_scale_index = valor


var fullscreen: bool:
	get:
		return video_settings.fullscreen
	set(valor):
		video_settings.fullscreen = valor


var idioma: String:
	get:
		return language_settings.idioma
	set(valor):
		language_settings.idioma = valor


func _init() -> void:
	video_settings = VideoSettings.new()
	audio_settings = AudioSettings.new()
	language_settings = LanguageSettings.new()
	input_settings = InputSettings.new()


func _ready() -> void:
	await carregar_config()
	input_settings.carregar_ou_criar()
	inputs_alterados.emit()


func reset_current_scene() -> void:
	var error: Error = get_tree().reload_current_scene()

	if error != OK:
		push_error(
			"Falha ao reiniciar a cena atual. Código de erro: %s"
			% error
		)


# ==========================
# VÍDEO
# ==========================

func set_resolution_multiplier(index: int) -> void:
	video_settings.resolution_multiplier = clampi(
		index,
		0,
		VideoSettings.RESOLUCOES.size() - 1
	)

	await aplicar_video()
	_notificar_estado_secao(SecaoConfig.VIDEO)


func set_interface_scale(index: int) -> void:
	video_settings.interface_scale_index = clampi(
		index,
		0,
		VideoSettings.ESCALAS_INTERFACE.size() - 1
	)

	await aplicar_video()
	_notificar_estado_secao(SecaoConfig.VIDEO)


func set_fullscreen(valor: bool) -> void:
	video_settings.fullscreen = valor

	await aplicar_video()
	_notificar_estado_secao(SecaoConfig.VIDEO)


func aplicar_video() -> void:
	await video_settings.aplicar(get_tree())

	var tema = video_settings.get_tema_atual()
	var scale_index: int = (
		video_settings.interface_scale_index
	)

	tema_alterado.emit(tema, scale_index)
	ajuste_fonte_size.emit(scale_index)
	atualizar_resolution.emit()


func aplicar_tema_global(index: int) -> void:
	# Compatibilidade com chamadas antigas: o índice agora representa
	# a escala da interface, não a resolução da janela.
	await set_interface_scale(index)


func get_tema_atual() -> Theme:
	return video_settings.get_tema_atual()


# ==========================
# ÁUDIO
# ==========================

func get_audio(id: String) -> float:
	return audio_settings.get_audio(id)


func set_audio(id: String, valor: float) -> void:
	audio_settings.set_audio(id, valor)
	_notificar_estado_secao(SecaoConfig.AUDIO)


# ==========================
# IDIOMA
# ==========================

func set_idioma(novo_idioma: String) -> void:
	language_settings.idioma = novo_idioma
	language_settings.aplicar()

	atualizar_idioma.emit()
	_notificar_estado_secao(SecaoConfig.JOGO)


# ==========================
# INPUTS
# ==========================

func carregar_inputs() -> void:
	input_settings.carregar_ou_criar()
	inputs_alterados.emit()
	atualizar_plataforma.emit()


func salvar_inputs() -> void:
	if not salvar_secao(SecaoConfig.INPUTS):
		push_error("Não foi possível salvar os inputs.")


func notificar_inputs_alterados() -> void:
	inputs_alterados.emit()
	_notificar_estado_secao(SecaoConfig.INPUTS)


func obter_input_padrao(
	action_id: StringName,
	usar_teclado: bool
) -> InputEvent:
	var padroes: Dictionary = input_settings.carregar_padroes()
	var plataforma: String = (
		"PC"
		if usar_teclado
		else "JOYPAD"
	)

	var dados_plataforma: Variant = padroes.get(
		plataforma,
		{}
	)

	if dados_plataforma is not Dictionary:
		return null

	var chave := str(action_id)

	if not dados_plataforma.has(chave):
		return null

	# desserializar_evento() cria uma nova instância.
	# Consultar o padrão não modifica o JSON nem o InputMap.
	return input_settings.desserializar_evento(
		dados_plataforma[chave]
	)


func restaurar_input_padrao(
	action_id: StringName,
	usar_teclado: bool
) -> bool:
	var restaurado: bool = (
		input_settings.restaurar_acao_padrao(
			action_id,
			usar_teclado
		)
	)

	if restaurado:
		notificar_inputs_alterados()

	return restaurado


func restaurar_inputs_padrao_em_memoria() -> void:
	input_settings.restaurar_todos_padroes()

	inputs_alterados.emit()
	atualizar_plataforma.emit()
	_notificar_estado_secao(SecaoConfig.INPUTS)


# ==========================
# APLICAR, SALVAR E CARREGAR
# ==========================

func aplicar_config() -> void:
	await aplicar_video()

	audio_settings.aplicar()
	language_settings.aplicar()

	atualizar_plataforma.emit()
	atualizar_idioma.emit()
	resetar_audio.emit()


func salvar_config() -> void:
	var config := ConfigFile.new()

	video_settings.escrever(config)
	audio_settings.escrever(config)
	language_settings.escrever(config)

	var erro: Error = Storage.salvar_config(
		config,
		USER_CONFIG
	)

	if erro != OK:
		push_error(
			"Erro ao salvar configurações. Código: %s"
			% erro
		)


func carregar_config() -> void:
	var config: ConfigFile = Storage.carregar_config(
		USER_CONFIG
	)

	if config == null:
		config = Storage.carregar_config(DEFAULT_CONFIG)

		if config == null:
			push_error(
				"Nenhuma configuração padrão válida foi encontrada."
			)
			return

		_carregar_modulos(config)
		salvar_config()
	else:
		_carregar_modulos(config)

	await aplicar_config()


func _carregar_modulos(config: ConfigFile) -> void:
	video_settings.carregar(config)
	audio_settings.carregar(config)
	language_settings.carregar(config)


# ==========================
# EDIÇÃO POR SEÇÃO
# ==========================

func iniciar_nova_sessao_edicao(
	secoes: Array = []
) -> void:
	var candidatas: Array = (
		secoes
		if not secoes.is_empty()
		else SecaoConfig.values()
	)

	for secao in candidatas:
		var chave: String = _chave_secao(secao)

		if chave.is_empty():
			continue

		# Sobrescreve snapshots antigos ou criados antes
		# de as configurações salvas terminarem de carregar.
		_snapshot_edicao[chave] = (
			_criar_snapshot_secao(secao)
		)

		_notificar_estado_secao(secao)

	_edicao_ativa = not _snapshot_edicao.is_empty()


func iniciar_edicao() -> void:
	for secao in SecaoConfig.values():
		iniciar_edicao_secao(secao)

	_edicao_ativa = true


func iniciar_edicao_secao(secao: SecaoConfig) -> void:
	var chave: String = _chave_secao(secao)

	if chave.is_empty() or _snapshot_edicao.has(chave):
		return

	_snapshot_edicao[chave] = (
		_criar_snapshot_secao(secao)
	)

	_edicao_ativa = true
	_notificar_estado_secao(secao)


func salvar_secao(secao: SecaoConfig) -> bool:
	iniciar_edicao_secao(secao)

	var sucesso := true

	match secao:
		SecaoConfig.JOGO:
			sucesso = _salvar_modulo_config(
				language_settings
			)

		SecaoConfig.VIDEO:
			sucesso = _salvar_modulo_config(
				video_settings
			)

		SecaoConfig.AUDIO:
			sucesso = _salvar_modulo_config(
				audio_settings
			)

		SecaoConfig.INPUTS:
			var erro: Error = input_settings.salvar()
			sucesso = erro == OK

			if not sucesso:
				push_error(
					"Não foi possível salvar os inputs."
				)

		_:
			return false

	if not sucesso:
		return false

	var chave: String = _chave_secao(secao)

	_snapshot_edicao[chave] = (
		_criar_snapshot_secao(secao)
	)

	if secao == SecaoConfig.INPUTS:
		inputs_alterados.emit()

	_notificar_estado_secao(secao)
	return true


func salvar_secoes(secoes: Array) -> bool:
	var sucesso := true

	for secao in secoes:
		if not salvar_secao(secao):
			sucesso = false

	return sucesso


func confirmar_edicao() -> bool:
	var pendentes: Array = obter_secoes_pendentes()

	if not salvar_secoes(pendentes):
		return false

	_snapshot_edicao.clear()
	_edicao_ativa = false
	return true


func descartar_secao(secao: SecaoConfig) -> void:
	var chave: String = _chave_secao(secao)

	if not _snapshot_edicao.has(chave):
		return

	var snapshot: Dictionary = _snapshot_edicao[chave]

	match secao:
		SecaoConfig.JOGO:
			language_settings.restaurar_snapshot(
				snapshot
			)
			language_settings.aplicar()
			atualizar_idioma.emit()

		SecaoConfig.VIDEO:
			video_settings.restaurar_snapshot(
				snapshot
			)
			await aplicar_video()

		SecaoConfig.AUDIO:
			audio_settings.restaurar_snapshot(
				snapshot
			)
			audio_settings.aplicar()
			resetar_audio.emit()

		SecaoConfig.INPUTS:
			input_settings.restaurar_snapshot(
				snapshot
			)
			inputs_alterados.emit()
			atualizar_plataforma.emit()

		_:
			return

	_snapshot_edicao[chave] = (
		_criar_snapshot_secao(secao)
	)

	_notificar_estado_secao(secao)


func cancelar_edicoes_sem_salvar() -> void:
	var pendentes: Array = obter_secoes_pendentes()

	for secao in pendentes:
		await descartar_secao(secao)

	_snapshot_edicao.clear()
	_edicao_ativa = false


func tem_alteracoes_secao(
	secao: SecaoConfig
) -> bool:
	var chave: String = _chave_secao(secao)

	if not _snapshot_edicao.has(chave):
		return false

	return (
		_snapshot_edicao[chave]
		!= _criar_snapshot_secao(secao)
	)


func tem_alteracoes_pendentes(
	secoes: Array = []
) -> bool:
	return not obter_secoes_pendentes(
		secoes
	).is_empty()


func obter_secoes_pendentes(
	secoes: Array = []
) -> Array:
	var resultado: Array = []
	var candidatas: Array = (
		secoes
		if not secoes.is_empty()
		else SecaoConfig.values()
	)

	for secao in candidatas:
		if tem_alteracoes_secao(secao):
			resultado.append(secao)

	return resultado


func obter_nome_secao(secao: SecaoConfig) -> String:
	match secao:
		SecaoConfig.JOGO:
			return tr("KEY_TAB_GAME")

		SecaoConfig.VIDEO:
			return tr("KEY_TAB_GRAPHIC")

		SecaoConfig.AUDIO:
			return tr("KEY_TAB_AUDIO")

		SecaoConfig.INPUTS:
			return tr("KEY_TAB_INPUT")

	return str(secao)


func criar_snapshot_atual() -> Dictionary:
	return {
		"language": language_settings.criar_snapshot(),
		"video": video_settings.criar_snapshot(),
		"audio": audio_settings.criar_snapshot(),
		"inputs": input_settings.criar_snapshot()
	}


func _criar_snapshot_secao(
	secao: SecaoConfig
) -> Dictionary:
	match secao:
		SecaoConfig.JOGO:
			return language_settings.criar_snapshot()

		SecaoConfig.VIDEO:
			return video_settings.criar_snapshot()

		SecaoConfig.AUDIO:
			return audio_settings.criar_snapshot()

		SecaoConfig.INPUTS:
			return input_settings.criar_snapshot()

	return {}


func _chave_secao(secao: SecaoConfig) -> String:
	match secao:
		SecaoConfig.JOGO:
			return "language"

		SecaoConfig.VIDEO:
			return "video"

		SecaoConfig.AUDIO:
			return "audio"

		SecaoConfig.INPUTS:
			return "inputs"

	return ""


func _carregar_config_usuario_para_edicao() -> ConfigFile:
	var config: ConfigFile = Storage.carregar_config(
		USER_CONFIG
	)

	if config == null:
		config = ConfigFile.new()

	return config


func _salvar_modulo_config(modulo) -> bool:
	var config: ConfigFile = (
		_carregar_config_usuario_para_edicao()
	)

	modulo.escrever(config)

	var erro: Error = Storage.salvar_config(
		config,
		USER_CONFIG
	)

	if erro != OK:
		push_error(
			"Erro ao salvar seção. Código: %s"
			% erro
		)
		return false

	return true


# ==========================
# COMPARAÇÃO COM OS PADRÕES
# ==========================

func secao_tem_diferenca_do_padrao(
	secao: SecaoConfig
) -> bool:
	_garantir_snapshots_padrao()

	var chave: String = _chave_secao(secao)

	if chave.is_empty():
		return false

	if not _snapshots_padrao.has(chave):
		return false

	return (
		_criar_snapshot_secao(secao)
		!= _snapshots_padrao[chave]
	)


func _garantir_snapshots_padrao() -> void:
	if not _snapshots_padrao.is_empty():
		return

	var config: ConfigFile = Storage.carregar_config(
		DEFAULT_CONFIG
	)

	if config == null:
		push_error(
			"Não foi possível carregar os padrões das configurações."
		)
		return

	var video_padrao = VideoSettings.new()
	var audio_padrao = AudioSettings.new()
	var idioma_padrao = LanguageSettings.new()

	video_padrao.carregar(config)
	audio_padrao.carregar(config)
	idioma_padrao.carregar(config)

	_snapshots_padrao = {
		"language": idioma_padrao.criar_snapshot(),
		"video": video_padrao.criar_snapshot(),
		"audio": audio_padrao.criar_snapshot(),
		"inputs": input_settings.carregar_padroes()
	}


func _notificar_estado_secao(
	secao: SecaoConfig
) -> void:
	estado_secao_alterado.emit(secao)


# ==========================
# RESTAURAÇÃO PADRÃO POR SEÇÃO
# ==========================

func restaurar_secao_padrao_em_memoria(
	secao: SecaoConfig
) -> bool:
	iniciar_edicao_secao(secao)

	if secao == SecaoConfig.INPUTS:
		restaurar_inputs_padrao_em_memoria()
		return true

	var config: ConfigFile = Storage.carregar_config(
		DEFAULT_CONFIG
	)

	if config == null:
		push_error(
			"default.cfg não encontrado ou inválido."
		)
		return false

	match secao:
		SecaoConfig.JOGO:
			language_settings.carregar(config)
			language_settings.aplicar()
			atualizar_idioma.emit()

		SecaoConfig.VIDEO:
			video_settings.carregar(config)
			await aplicar_video()

		SecaoConfig.AUDIO:
			audio_settings.carregar(config)
			audio_settings.aplicar()
			resetar_audio.emit()

		_:
			return false

	_notificar_estado_secao(secao)
	return true


func restaurar_padrao_em_memoria() -> void:
	for secao in SecaoConfig.values():
		await restaurar_secao_padrao_em_memoria(
			secao
		)


func restaurar_padrao() -> void:
	await restaurar_padrao_em_memoria()

	if not confirmar_edicao():
		push_error(
			"Não foi possível salvar todas as configurações padrão."
		)


# ==========================
# PLATAFORMA VISUAL
# ==========================

func set_tipo_controle(tipo: TipoControle) -> void:
	if tipo_controle == tipo:
		return

	tipo_controle = tipo
	atualizar_plataforma.emit()
