extends Control

signal nome_confirmado(nome: String)
signal cancelado

@onready var titulo_label: Label = %TituloLabel
@onready var mensagem_label: Label = %MensagemLabel
@onready var nome_line_edit: LineEdit = %NomeLineEdit
@onready var erro_label: Label = %ErroLabel
@onready var bt_cancelar: Button = %BtCancelar
@onready var bt_confirmar: Button = %BtConfirmar

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	nome_line_edit.grab_focus()
	_atualizar_estado_confirmar()

func configurar(
	titulo: String = "POPUP_SAVE_TITULO",
	mensagem: String = "POPUP_SAVE_MENSAGEM",
	placeholder: String = "POPUP_SAVE_PLACEHOLDER",
	nome_inicial: String = ""
) -> void:
	titulo_label.text = titulo
	mensagem_label.text = mensagem
	nome_line_edit.placeholder_text = placeholder
	nome_line_edit.text = nome_inicial
	
	if nome_inicial != "":
		nome_line_edit.select_all()
		nome_line_edit.caret_column = nome_line_edit.text.length()
	
	_atualizar_estado_confirmar()

func _atualizar_estado_confirmar() -> void:
	var nome := nome_line_edit.text.strip_edges()
	bt_confirmar.disabled = nome.length() < 2
	erro_label.visible = nome.length() > 0 and nome.length() < 2

func _confirmar_nome() -> void:
	var nome := nome_line_edit.text.strip_edges()
	if nome.length() < 2:
		_atualizar_estado_confirmar()
		return
	nome_confirmado.emit(nome)
	queue_free()

func _on_nome_line_edit_text_changed(_new_text: String) -> void:
	_atualizar_estado_confirmar()

func _on_nome_line_edit_text_submitted(_new_text: String) -> void:
	_confirmar_nome()

func _on_bt_cancelar_pressed() -> void:
	cancelado.emit()
	queue_free()

func _on_bt_confirmar_pressed() -> void:
	_confirmar_nome()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_bt_cancelar_pressed()
