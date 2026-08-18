extends RefCounted


const Storage = preload("res://ScriptGlobais/settings/config_storage.gd")

const DEFAULT_INPUT_CONFIG := "res://Config/InputMapPadrao.json"
const USER_INPUT_CONFIG := "user://inputs.json"
const LEGACY_BACKUP_CONFIG := "user://inputs_legacy_backup.json"
const FORMATO_ATUAL := 2

var _padroes_cache: Dictionary = {}


func carregar_ou_criar() -> void:
	var dados: Dictionary
	var precisa_salvar := false

	if FileAccess.file_exists(USER_INPUT_CONFIG):
		dados = Storage.carregar_json(USER_INPUT_CONFIG)
		if dados.is_empty():
			dados = carregar_padroes()
			precisa_salvar = true
	else:
		dados = carregar_padroes()
		precisa_salvar = true

	var normalizados := normalizar_dados(dados)
	if normalizados.is_empty():
		push_error("Nenhum mapeamento de input válido foi encontrado.")
		return

	aplicar_dados(normalizados)

	if normalizados != dados and FileAccess.file_exists(USER_INPUT_CONFIG):
		Storage.criar_backup(
			USER_INPUT_CONFIG,
			LEGACY_BACKUP_CONFIG
		)

	if precisa_salvar or normalizados != dados:
		salvar()


func carregar_padroes() -> Dictionary:
	if not _padroes_cache.is_empty():
		return _padroes_cache.duplicate(true)

	var dados := Storage.carregar_json(DEFAULT_INPUT_CONFIG)
	_padroes_cache = normalizar_dados(dados)
	return _padroes_cache.duplicate(true)


func salvar() -> Error:
	return Storage.salvar_json(
		USER_INPUT_CONFIG,
		serializar_inputmap()
	)


func criar_snapshot() -> Dictionary:
	return serializar_inputmap()


func restaurar_snapshot(snapshot: Dictionary) -> void:
	aplicar_dados(snapshot)


func restaurar_todos_padroes() -> void:
	aplicar_dados(carregar_padroes())


func restaurar_acao_padrao(
	action_id: StringName,
	usar_teclado: bool
) -> bool:
	var padroes := carregar_padroes()
	var plataforma := "PC" if usar_teclado else "JOYPAD"

	if not padroes.has(plataforma):
		return false

	var dados_plataforma: Dictionary = padroes[plataforma]
	var chave := str(action_id)
	if not dados_plataforma.has(chave):
		return false

	var evento := desserializar_evento(dados_plataforma[chave])
	if evento == null:
		return false

	_garantir_acao(action_id)
	_remover_eventos_plataforma(action_id, plataforma)
	InputMap.action_add_event(action_id, evento)
	return true


func normalizar_dados(dados: Dictionary) -> Dictionary:
	if dados.is_empty():
		return {}

	var resultado := {
		"version": FORMATO_ATUAL,
		"PC": {},
		"JOYPAD": {}
	}

	if dados.has("PC") and dados["PC"] is Dictionary:
		for acao in dados["PC"]:
			var evento_pc := _normalizar_evento_legacy(
				dados["PC"][acao],
				"PC"
			)
			if not evento_pc.is_empty():
				resultado["PC"][str(acao)] = evento_pc

	var origem_joypad: Dictionary = {}
	if dados.has("JOYPAD") and dados["JOYPAD"] is Dictionary:
		origem_joypad = dados["JOYPAD"]
	elif dados.has("XBOX") and dados["XBOX"] is Dictionary:
		origem_joypad = dados["XBOX"]
	elif dados.has("PLAYSTATION") and dados["PLAYSTATION"] is Dictionary:
		origem_joypad = dados["PLAYSTATION"]

	for acao in origem_joypad:
		var evento_joypad := _normalizar_evento_legacy(
			origem_joypad[acao],
			"JOYPAD"
		)
		if not evento_joypad.is_empty():
			resultado["JOYPAD"][str(acao)] = evento_joypad

	if resultado["PC"].is_empty() and resultado["JOYPAD"].is_empty():
		return {}

	return resultado


func serializar_inputmap() -> Dictionary:
	var dados := {
		"version": FORMATO_ATUAL,
		"PC": {},
		"JOYPAD": {}
	}

	for acao in InputMap.get_actions():
		if str(acao).begins_with("ui_"):
			continue

		for evento in InputMap.action_get_events(acao):
			if evento is InputEventKey:
				if not dados["PC"].has(str(acao)):
					dados["PC"][str(acao)] = serializar_evento(evento)

			elif (
				evento is InputEventJoypadButton
				or evento is InputEventJoypadMotion
			):
				if not dados["JOYPAD"].has(str(acao)):
					dados["JOYPAD"][str(acao)] = serializar_evento(evento)

	return dados


func serializar_evento(evento: InputEvent) -> Dictionary:
	if evento is InputEventKey:
		var codigo: Key = evento.physical_keycode
		if codigo == 0:
			codigo = evento.keycode

		return {
			"type": "key",
			"physical_keycode": int(codigo)
		}

	if evento is InputEventJoypadButton:
		return {
			"type": "joypad_button",
			"button_index": int(evento.button_index)
		}

	if evento is InputEventJoypadMotion:
		return {
			"type": "joypad_motion",
			"axis": int(evento.axis),
			"axis_value": float(evento.axis_value)
		}

	return {}


func desserializar_evento(dados_evento: Variant) -> InputEvent:
	if dados_evento is not Dictionary:
		return null

	var tipo := str(dados_evento.get("type", ""))

	match tipo:
		"key":
			var codigo := int(dados_evento.get("physical_keycode", 0))
			if codigo == 0:
				return null

			var evento_tecla := InputEventKey.new()
			evento_tecla.physical_keycode = codigo as Key
			return evento_tecla

		"joypad_button":
			var indice_botao := int(dados_evento.get("button_index", -1))
			if indice_botao < 0:
				return null

			var evento_botao := InputEventJoypadButton.new()
			evento_botao.button_index = indice_botao as JoyButton
			return evento_botao

		"joypad_motion":
			var eixo := int(dados_evento.get("axis", -1))
			var valor := float(dados_evento.get("axis_value", 0.0))
			if eixo < 0 or is_zero_approx(valor):
				return null

			var evento_eixo := InputEventJoypadMotion.new()
			evento_eixo.axis = eixo as JoyAxis
			evento_eixo.axis_value = clampf(valor, -1.0, 1.0)
			return evento_eixo

	return null


func aplicar_dados(dados: Dictionary) -> void:
	var normalizados := normalizar_dados(dados)
	if normalizados.is_empty():
		return

	for plataforma in ["PC", "JOYPAD"]:
		var dados_plataforma: Dictionary = normalizados.get(
			plataforma,
			{}
		)

		for acao in dados_plataforma:
			var evento := desserializar_evento(
				dados_plataforma[acao]
			)
			if evento == null:
				continue

			var action_id := StringName(acao)
			_garantir_acao(action_id)
			_remover_eventos_plataforma(action_id, plataforma)
			InputMap.action_add_event(action_id, evento)


func _normalizar_evento_legacy(
	valor: Variant,
	plataforma: String
) -> Dictionary:
	if valor is Dictionary:
		var tipo := str(valor.get("type", ""))
		if tipo in ["key", "joypad_button", "joypad_motion"]:
			return valor.duplicate(true)

	if plataforma == "PC":
		if valor is String:
			var codigo := OS.find_keycode_from_string(valor)
			if codigo != 0:
				return {
					"type": "key",
					"physical_keycode": int(codigo)
				}

		if valor is int or valor is float:
			var codigo_numerico := int(valor)
			if codigo_numerico != 0:
				return {
					"type": "key",
					"physical_keycode": codigo_numerico
				}

		return {}

	if valor is String:
		match valor.to_upper():
			"LT":
				return {
					"type": "joypad_motion",
					"axis": int(JOY_AXIS_TRIGGER_LEFT),
					"axis_value": 1.0
				}
			"RT":
				return {
					"type": "joypad_motion",
					"axis": int(JOY_AXIS_TRIGGER_RIGHT),
					"axis_value": 1.0
				}

	if valor is int or valor is float:
		return {
			"type": "joypad_button",
			"button_index": int(valor)
		}

	return {}


func _garantir_acao(action_id: StringName) -> void:
	if not InputMap.has_action(action_id):
		InputMap.add_action(action_id)


func _remover_eventos_plataforma(
	action_id: StringName,
	plataforma: String
) -> void:
	for evento in InputMap.action_get_events(action_id):
		if plataforma == "PC" and evento is InputEventKey:
			InputMap.action_erase_event(action_id, evento)

		elif plataforma == "JOYPAD" and (
			evento is InputEventJoypadButton
			or evento is InputEventJoypadMotion
		):
			InputMap.action_erase_event(action_id, evento)
