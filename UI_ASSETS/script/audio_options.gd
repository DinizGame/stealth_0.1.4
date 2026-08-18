extends ScrollContainer

func _on_salvar_secao_pressed() -> void:
	AutoConfig.salvar_secao(AutoConfig.SecaoConfig.AUDIO)

func _on_restaurar_secao_pressed() -> void:
	await AutoConfig.restaurar_secao_padrao_em_memoria(
		AutoConfig.SecaoConfig.AUDIO
	)
