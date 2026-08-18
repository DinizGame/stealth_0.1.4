extends RefCounted


const MAPA_ICONES_CONTROLE := {
	JOY_BUTTON_A: "1",
	JOY_BUTTON_X: "2",
	JOY_BUTTON_B: "3",
	JOY_BUTTON_Y: "4",
	JOY_BUTTON_DPAD_UP: "5",
	JOY_BUTTON_DPAD_DOWN: "6",
	JOY_BUTTON_DPAD_LEFT: "7",
	JOY_BUTTON_DPAD_RIGHT: "8",
	JOY_BUTTON_LEFT_SHOULDER: "9",
	JOY_BUTTON_RIGHT_SHOULDER: "16",
	JOY_BUTTON_LEFT_STICK: "11",
	JOY_BUTTON_RIGHT_STICK: "18",
	JOY_BUTTON_BACK: "24",
	JOY_BUTTON_START: "23"
}

const MAPA_EIXOS_CONTROLE := {
	JOY_AXIS_LEFT_Y: {-1.0: "13", 1.0: "12"},
	JOY_AXIS_LEFT_X: {-1.0: "14", 1.0: "15"},
	JOY_AXIS_TRIGGER_LEFT: {1.0: "10"},
	JOY_AXIS_TRIGGER_RIGHT: {1.0: "17"}
}


static func obter_codigo_tecla(evento: InputEventKey) -> Key:
	if evento.physical_keycode != 0:
		return evento.physical_keycode
	return evento.keycode


static func obter_nome_icone(
	evento: InputEvent,
	pasta: String
) -> String:
	if pasta == "PC":
		if evento is not InputEventKey:
			return ""

		var codigo := obter_codigo_tecla(evento)
		return OS.get_keycode_string(codigo)

	if evento is InputEventJoypadButton:
		return str(MAPA_ICONES_CONTROLE.get(evento.button_index, ""))

	if evento is InputEventJoypadMotion:
		var direcoes: Dictionary = MAPA_EIXOS_CONTROLE.get(
			evento.axis,
			{}
		)
		var direcao := float(sign(evento.axis_value))
		return str(direcoes.get(direcao, ""))

	return ""


static func obter_textura_evento(
	evento: InputEvent,
	pasta: String
) -> Texture2D:
	var nome_icone := obter_nome_icone(evento, pasta)
	if nome_icone.is_empty():
		return null

	var caminho := (
		"res://UI_ASSETS/icon/InputMap/%s/%s.png"
		% [pasta, nome_icone]
	)

	if not FileAccess.file_exists(caminho):
		return null

	return load(caminho) as Texture2D


static func obter_textura_acao(
	acao: StringName,
	pasta: String
) -> Texture2D:
	if not InputMap.has_action(acao):
		return null

	for evento in InputMap.action_get_events(acao):
		var textura := obter_textura_evento(evento, pasta)
		if textura != null:
			return textura

	return null


static func tecla_possui_icone(evento: InputEventKey) -> bool:
	return obter_textura_evento(evento, "PC") != null
