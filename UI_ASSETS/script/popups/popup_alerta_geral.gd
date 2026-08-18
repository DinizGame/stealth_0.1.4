extends Control

signal confirmado
signal cancelado
signal alternativo

@onready var titulo_label: Label = %TituloLabel
@onready var mensagem_label: Label = %MensagemLabel
@onready var bt_cancelar: Button = %BtCancelar
@onready var bt_alternativo: Button = %BtAlternativo
@onready var bt_confirmar: Button = %BtConfirmar


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	bt_cancelar.grab_focus()


func configurar(
	titulo: String,
	mensagem: String,
	texto_cancelar: String = "BTN_CANCELAR",
	texto_confirmar: String = "BTN_CONFIRMAR"
) -> void:
	titulo_label.text = titulo
	mensagem_label.text = mensagem
	bt_cancelar.text = texto_cancelar
	bt_confirmar.text = texto_confirmar
	bt_alternativo.hide()

func configurar_tres_opcoes(
	titulo: String,
	mensagem: String,
	texto_cancelar: String,
	texto_alternativo: String,
	texto_confirmar: String
) -> void:
	titulo_label.text = titulo
	mensagem_label.text = mensagem
	bt_cancelar.text = texto_cancelar
	bt_alternativo.text = texto_alternativo
	bt_confirmar.text = texto_confirmar
	bt_alternativo.show()

func _on_bt_cancelar_pressed() -> void:
	cancelado.emit()
	queue_free()

func _on_bt_alternativo_pressed() -> void:
	alternativo.emit()
	queue_free()

func _on_bt_confirmar_pressed() -> void:
	confirmado.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_bt_cancelar_pressed()
