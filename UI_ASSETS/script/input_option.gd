extends ScrollContainer

const KeyInputBase = preload("res://UI_ASSETS/script/key_input_base.gd")

func _on_metodo_input_option_item_selected(index: int) -> void:
	KeyInputBase.cancelar_remapeamento_ativo()
	match index:
		0:
			AutoConfig.set_tipo_controle(AutoConfig.TipoControle.PC)
			%KeyInputBaseUp.show()
			%KeyInputBaseDown.show()
			%KeyInputCompostaUp.hide()
			%KeyInputCompostaDown.hide()
		1:
			AutoConfig.set_tipo_controle(AutoConfig.TipoControle.XBOX)
			%KeyInputBaseUp.hide()
			%KeyInputBaseDown.hide()
			%KeyInputCompostaUp.show()
			%KeyInputCompostaDown.show()
		2:
			AutoConfig.set_tipo_controle(AutoConfig.TipoControle.PLAYSTATION)
			%KeyInputBaseUp.hide()
			%KeyInputBaseDown.hide()
			%KeyInputCompostaUp.show()
			%KeyInputCompostaDown.show()

func _on_salvar_secao_pressed() -> void:
	KeyInputBase.cancelar_remapeamento_ativo()
	AutoConfig.salvar_secao(AutoConfig.SecaoConfig.INPUTS)

func _on_restaurar_secao_pressed() -> void:
	KeyInputBase.cancelar_remapeamento_ativo()
	await AutoConfig.restaurar_secao_padrao_em_memoria(
		AutoConfig.SecaoConfig.INPUTS
	)
