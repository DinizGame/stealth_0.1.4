extends AspectRatioContainer


const POPUP_ALERTA_GERAL := preload(
	"res://UI_ASSETS/cenas/popups/popup_alerta_geral.tscn"
)

@onready var menu_lateral: VBoxContainer = %menu_lateral
@onready var menu_central: HBoxContainer = %menu_central
@onready var tab_menu_central: TabContainer = %TabMenuCentral
@onready var margin_central: PanelContainer = %MarginCentral
@onready var margin_lateral: PanelContainer = (
	$HBoxContainer/menu_lateral/MarginLateral
)

@export var tab_menu_grup_button: ButtonGroup

var fonte_acessibilidade: int = 0


func _ready() -> void:
	if not AutoConfig.ajuste_fonte_size.is_connected(
		_on_graphic_options_ajuste_fonte_size
	):
		AutoConfig.ajuste_fonte_size.connect(
			_on_graphic_options_ajuste_fonte_size
		)

	_atualizar_visibilidade_menus(false)
	await _on_graphic_options_ajuste_fonte_size(
		AutoConfig.interface_scale_index
	)


func _atualizar_visibilidade_menus(mostrar_central: bool) -> void:
	menu_central.visible = mostrar_central
	menu_lateral.visible = not mostrar_central


func _voltar_para_menu_lateral() -> void:
	if not tab_menu_grup_button:
		push_warning("ButtonGroup não foi atribuído no Inspetor.")
		return

	var botao_pressionado := tab_menu_grup_button.get_pressed_button()
	if botao_pressionado:
		botao_pressionado.button_pressed = false


func _on_user_menu_toggled(toggled_on: bool) -> void:
	_atualizar_visibilidade_menus(toggled_on)
	tab_menu_central.current_tab = 0


func _on_extra_menu_toggled(toggled_on: bool) -> void:
	_atualizar_visibilidade_menus(toggled_on)
	tab_menu_central.current_tab = 1

	await get_tree().process_frame
	%OptionPanel.selected = 1
	%SCROLLPANEL._on_option_panel_item_selected(1)


func _on_option_menu_toggled(toggled_on: bool) -> void:
	_atualizar_visibilidade_menus(toggled_on)
	tab_menu_central.current_tab = 2

	if toggled_on:
		AutoConfig.iniciar_nova_sessao_edicao()


func _on_credito_menu_toggled(toggled_on: bool) -> void:
	_atualizar_visibilidade_menus(toggled_on)
	tab_menu_central.current_tab = 3


func _on_graphic_options_ajuste_fonte_size(_index: int) -> void:
	await get_tree().process_frame

	var largura_menu := get_viewport_rect().size.x / 4.0
	margin_central.custom_minimum_size.x = largura_menu * 2.5
	margin_lateral.custom_minimum_size.x = largura_menu

	await get_tree().process_frame
	queue_redraw()


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_salvarsair_pressed() -> void:
	AutoConfig.confirmar_edicao()
	_voltar_para_menu_lateral()


func _on_reset_config_pressed() -> void:
	await AutoConfig.restaurar_padrao_em_memoria()
	_sincronizar_ui_com_autoconfig()


func _mostrar_alerta_sair_sem_salvar() -> void:
	var pendentes = AutoConfig.obter_secoes_pendentes()
	var nomes: Array[String] = []
	for secao in pendentes:
		nomes.append(AutoConfig.obter_nome_secao(secao))

	var mensagem := tr("POPUP_OPCOES_SEM_SALVAR_MENSAGEM_LISTA") % [
		" | ".join(nomes)
	]

	var popup = POPUP_ALERTA_GERAL.instantiate()
	get_tree().root.add_child(popup)
	popup.configurar_tres_opcoes(
		"POPUP_OPCOES_SEM_SALVAR_TITULO",
		mensagem,
		"BTN_CONTINUAR_EDITANDO",
		"BTN_SAIR_SEM_SALVAR",
		"BTN_SALVAR_TUDO"
	)
	popup.confirmado.connect(_salvar_tudo_e_sair_opcoes)
	popup.alternativo.connect(_descartar_alteracoes_e_sair_opcoes)

func _salvar_tudo_e_sair_opcoes() -> void:
	AutoConfig.confirmar_edicao()
	_voltar_para_menu_lateral()

func _descartar_alteracoes_e_sair_opcoes() -> void:
	await AutoConfig.cancelar_edicoes_sem_salvar()
	_sincronizar_ui_com_autoconfig()
	_voltar_para_menu_lateral()


func _sincronizar_ui_com_autoconfig() -> void:
	AutoConfig.atualizar_idioma.emit()
	AutoConfig.atualizar_resolution.emit()
	AutoConfig.atualizar_plataforma.emit()
	AutoConfig.inputs_alterados.emit()
	AutoConfig.resetar_audio.emit()


func _on_btn_return_pressed() -> void:
	if (
		tab_menu_central.current_tab == 2
		and AutoConfig.tem_alteracoes_pendentes()
	):
		_mostrar_alerta_sair_sem_salvar()
		return
	_voltar_para_menu_lateral()
