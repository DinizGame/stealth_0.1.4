extends ScrollContainer


var atualizando_interface := false

@onready var option_resolution: OptionButton = (
	$VBoxContainer/OptionResolution
)
@onready var option_interface_scale: OptionButton = (
	$VBoxContainer/OptionInterfaceScale
)
@onready var option_fullscreen: CheckButton = (
	$VBoxContainer/OptionFullscreen
)


func _ready() -> void:
	if not AutoConfig.atualizar_resolution.is_connected(
		_atualizar_graphic
	):
		AutoConfig.atualizar_resolution.connect(
			_atualizar_graphic
		)

	_atualizar_graphic()


func _atualizar_graphic() -> void:
	var resolution_index := clampi(
		AutoConfig.resolution_multiplier,
		0,
		option_resolution.item_count - 1
	)
	var scale_index := clampi(
		AutoConfig.interface_scale_index,
		0,
		option_interface_scale.item_count - 1
	)

	atualizando_interface = true
	option_resolution.select(resolution_index)
	option_interface_scale.select(scale_index)
	option_fullscreen.button_pressed = AutoConfig.fullscreen
	atualizando_interface = false


func _ajustar_largura_popup(option: OptionButton) -> void:
	var popup := option.get_popup()
	await get_tree().process_frame
	popup.size.x = int(option.size.x)


func _on_option_resolution_pressed() -> void:
	await _ajustar_largura_popup(option_resolution)


func _on_option_interface_scale_pressed() -> void:
	await _ajustar_largura_popup(option_interface_scale)


func _on_option_resolution_item_selected(index: int) -> void:
	if atualizando_interface:
		return

	await AutoConfig.set_resolution_multiplier(index)


func _on_option_interface_scale_item_selected(index: int) -> void:
	if atualizando_interface:
		return

	await AutoConfig.set_interface_scale(index)


func _on_option_fullscreen_toggled(toggled_on: bool) -> void:
	if atualizando_interface:
		return

	await AutoConfig.set_fullscreen(toggled_on)


func _on_salvar_secao_pressed() -> void:
	AutoConfig.salvar_secao(AutoConfig.SecaoConfig.VIDEO)


func _on_restaurar_secao_pressed() -> void:
	await AutoConfig.restaurar_secao_padrao_em_memoria(
		AutoConfig.SecaoConfig.VIDEO
	)
