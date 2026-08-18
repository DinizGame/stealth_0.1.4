extends HBoxContainer


const InputIconResolver = preload(
	"res://ScriptGlobais/settings/input_icon_resolver.gd"
)

const ACOES_DE_MOVIMENTO: Array[StringName] = [
	&"MoveUp",
	&"MoveDown",
	&"MoveLeft",
	&"MoveRight"
]

const COR_CONFLITO := Color.FIREBRICK
const TEMPO_FEEDBACK_CONFLITO := 1.0

static var _grupo_remapeamento: ButtonGroup
static var _titulos_por_acao: Dictionary = {}


@onready var key_input: Button = $PanelContainer/key_input
@onready var label_title: Label = (
	$PanelContainer/HBoxContainer/LabelTitle
)
@onready var icone_tecla: TextureRect = (
	$PanelContainer/HBoxContainer/IconeTecla
)
@onready var reset_input: Button = $reset_input

@export var action_id: StringName
@export var titulo: String

var aguardando_input := false
var _feedback_conflito_id := 0


static func cancelar_remapeamento_ativo() -> void:
	if _grupo_remapeamento == null:
		return

	var botao_ativo := _grupo_remapeamento.get_pressed_button()
	if botao_ativo != null:
		# Emite toggled(false), permitindo que a instância dona
		# do botão também limpe aguardando_input e seu texto.
		botao_ativo.button_pressed = false


func _ready() -> void:
	label_title.text = tr(titulo)

	_registrar_titulo_acao()
	_configurar_grupo_remapeamento()

	if not AutoConfig.atualizar_plataforma.is_connected(
		atualizar_tecla
	):
		AutoConfig.atualizar_plataforma.connect(
			atualizar_tecla
		)

	if not AutoConfig.inputs_alterados.is_connected(
		atualizar_tecla
	):
		AutoConfig.inputs_alterados.connect(
			atualizar_tecla
		)

	if not AutoConfig.resetar_inputs.is_connected(
		_on_reset_input_pressed
	):
		AutoConfig.resetar_inputs.connect(
			_on_reset_input_pressed
		)

	atualizar_tecla()


func _registrar_titulo_acao() -> void:
	if action_id == &"":
		return

	_titulos_por_acao[action_id] = titulo


func _configurar_grupo_remapeamento() -> void:
	if _grupo_remapeamento == null:
		_grupo_remapeamento = ButtonGroup.new()
		_grupo_remapeamento.allow_unpress = true

	key_input.toggle_mode = true
	key_input.button_group = _grupo_remapeamento


func atualizar_tecla() -> void:
	key_input.disabled = false
	reset_input.disabled = false

	if not aguardando_input:
		key_input.text = ""

	if (
		AutoConfig.tipo_controle != AutoConfig.TipoControle.PC
		and action_id in ACOES_DE_MOVIMENTO
	):
		key_input.disabled = true
		reset_input.disabled = true
		key_input.text = "Fixo"

	var pasta := _obter_pasta_icones()
	icone_tecla.texture = InputIconResolver.obter_textura_acao(
		action_id,
		pasta
	)


func _obter_pasta_icones() -> String:
	match AutoConfig.tipo_controle:
		AutoConfig.TipoControle.PC:
			return "PC"
		AutoConfig.TipoControle.XBOX:
			return "XBOX"
		AutoConfig.TipoControle.PLAYSTATION:
			return "PLAYSTATION"

	return "PC"


func _input(event: InputEvent) -> void:
	if (
		not aguardando_input
		or key_input.disabled
		or not key_input.button_pressed
	):
		return

	if event is InputEventKey and not event.pressed:
		return

	if event is InputEventJoypadButton and not event.pressed:
		return

	match AutoConfig.tipo_controle:
		AutoConfig.TipoControle.PC:
			_processar_tecla(event)

		AutoConfig.TipoControle.XBOX, \
		AutoConfig.TipoControle.PLAYSTATION:
			_processar_joypad(event)


func _processar_tecla(event: InputEvent) -> void:
	if event is not InputEventKey:
		return

	if not InputIconResolver.tecla_possui_icone(event):
		key_input.text = tr("MS_KEY_WITHOUT_ICON")
		return

	var conflito := _buscar_conflito_evento(event)
	if conflito != &"":
		_mostrar_conflito(conflito)
		return

	_definir_tecla(event)


func _processar_joypad(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var _conflito := _buscar_conflito_evento(event)
		if _conflito != &"":
			_mostrar_conflito(_conflito)
			return

		_definir_botao(event)
		return

	if event is not InputEventJoypadMotion:
		return

	if abs(event.axis_value) < 0.8:
		return

	if event.axis not in [
		JOY_AXIS_TRIGGER_LEFT,
		JOY_AXIS_TRIGGER_RIGHT
	]:
		return

	var conflito := _buscar_conflito_evento(event)
	if conflito != &"":
		_mostrar_conflito(conflito)
		return

	_definir_trigger(event)


func _buscar_conflito_evento(
	evento_novo: InputEvent
) -> StringName:
	for acao in InputMap.get_actions():
		if str(acao).begins_with("ui_"):
			continue

		if acao == action_id:
			continue

		for evento_existente in InputMap.action_get_events(acao):
			if _eventos_entram_em_conflito(
				evento_novo,
				evento_existente
			):
				return acao

	return &""


func _eventos_entram_em_conflito(
	evento_a: InputEvent,
	evento_b: InputEvent
) -> bool:
	if (
		evento_a is InputEventKey
		and evento_b is InputEventKey
	):
		var codigo_a := InputIconResolver.obter_codigo_tecla(
			evento_a
		)
		var codigo_b := InputIconResolver.obter_codigo_tecla(
			evento_b
		)

		return codigo_a != 0 and codigo_a == codigo_b

	if (
		evento_a is InputEventJoypadButton
		and evento_b is InputEventJoypadButton
	):
		return evento_a.button_index == evento_b.button_index

	if (
		evento_a is InputEventJoypadMotion
		and evento_b is InputEventJoypadMotion
	):
		return (
			evento_a.axis == evento_b.axis
			and sign(evento_a.axis_value)
			== sign(evento_b.axis_value)
		)

	return false


func _definir_trigger(
	evento: InputEventJoypadMotion
) -> void:
	_remover_eventos_joypad()

	var novo_evento := InputEventJoypadMotion.new()
	novo_evento.axis = evento.axis
	novo_evento.axis_value = 1.0
	InputMap.action_add_event(action_id, novo_evento)

	_finalizar_remapeamento()


func _definir_tecla(evento: InputEventKey) -> void:
	_remover_eventos_teclado()

	var novo_evento := InputEventKey.new()
	novo_evento.physical_keycode = (
		InputIconResolver.obter_codigo_tecla(evento)
	)
	InputMap.action_add_event(action_id, novo_evento)

	_finalizar_remapeamento()


func _definir_botao(
	evento: InputEventJoypadButton
) -> void:
	_remover_eventos_joypad()

	var novo_evento := InputEventJoypadButton.new()
	novo_evento.button_index = evento.button_index
	InputMap.action_add_event(action_id, novo_evento)

	_finalizar_remapeamento()


func _finalizar_remapeamento() -> void:
	_feedback_conflito_id += 1
	_restaurar_cor_texto_input()

	aguardando_input = false
	key_input.set_pressed_no_signal(false)
	key_input.text = ""

	AutoConfig.notificar_inputs_alterados()
	atualizar_tecla()
	get_viewport().set_input_as_handled()


func _remover_eventos_teclado() -> void:
	for evento in InputMap.action_get_events(action_id):
		if evento is InputEventKey:
			InputMap.action_erase_event(action_id, evento)


func _remover_eventos_joypad() -> void:
	for evento in InputMap.action_get_events(action_id):
		if (
			evento is InputEventJoypadButton
			or evento is InputEventJoypadMotion
		):
			InputMap.action_erase_event(action_id, evento)


func _on_reset_input_pressed() -> void:
	if reset_input.disabled:
		return

	cancelar_remapeamento_ativo()

	var usar_teclado := (
		AutoConfig.tipo_controle
		== AutoConfig.TipoControle.PC
	)

	var evento_padrao := AutoConfig.obter_input_padrao(
		action_id,
		usar_teclado
	)

	if evento_padrao == null:
		push_warning(
			"Configuração padrão não encontrada para a ação: %s"
			% action_id
		)
		return

	var conflito := _buscar_conflito_evento(evento_padrao)
	if conflito != &"":
		await _mostrar_conflito(conflito)
		return

	if not AutoConfig.restaurar_input_padrao(
		action_id,
		usar_teclado
	):
		push_warning(
			"Não foi possível restaurar a ação: %s"
			% action_id
		)
		return

	atualizar_tecla()


func _obter_titulo_acao(acao: StringName) -> String:
	var chave_traducao := str(
		_titulos_por_acao.get(
			acao,
			str(acao)
		)
	)

	return tr(chave_traducao)


func _mostrar_conflito(conflito: StringName) -> void:
	_feedback_conflito_id += 1
	var feedback_atual := _feedback_conflito_id
	var titulo_conflito := _obter_titulo_acao(conflito)

	key_input.text = (
		tr("MS_KEY_USED")
		+ " '"
		+ titulo_conflito.to_upper()
		+ "'"
	)
	_definir_cor_texto_input(COR_CONFLITO)

	await get_tree().create_timer(
		TEMPO_FEEDBACK_CONFLITO
	).timeout

	if feedback_atual != _feedback_conflito_id:
		return

	_restaurar_cor_texto_input()

	if aguardando_input and key_input.button_pressed:
		key_input.text = (
			tr("MS_NEW_KEY")
			+ " '"
			+ tr(titulo).to_upper()
			+ "'..."
		)
	else:
		# Necessário quando o conflito veio do botão Restaurar.
		key_input.text = ""


func _definir_cor_texto_input(cor: Color) -> void:
	for nome_cor in [
		"font_color",
		"font_pressed_color",
		"font_hover_color",
		"font_focus_color",
		"font_hover_pressed_color"
	]:
		key_input.add_theme_color_override(nome_cor, cor)


func _restaurar_cor_texto_input() -> void:
	for nome_cor in [
		"font_color",
		"font_pressed_color",
		"font_hover_color",
		"font_focus_color",
		"font_hover_pressed_color"
	]:
		key_input.remove_theme_color_override(nome_cor)


func _on_key_input_toggled(toggled_on: bool) -> void:
	_feedback_conflito_id += 1
	_restaurar_cor_texto_input()

	if toggled_on and key_input.disabled:
		key_input.set_pressed_no_signal(false)
		aguardando_input = false
		key_input.text = ""
		return

	aguardando_input = toggled_on

	if toggled_on:
		key_input.text = (
			tr("MS_NEW_KEY")
			+ " '"
			+ tr(titulo).to_upper()
			+ "'..."
		)
	else:
		key_input.text = ""
