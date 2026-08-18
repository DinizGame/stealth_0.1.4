extends ScrollContainer

@onready var option_language: OptionButton = %OptionLanguage

var _idiomas := ["pt_BR", "en"]

func _ready() -> void:
	if not AutoConfig.atualizar_idioma.is_connected(_atualizar_idioma):
		AutoConfig.atualizar_idioma.connect(_atualizar_idioma)
	_atualizar_idioma()

func _atualizar_idioma() -> void:
	var idioma_index := _idiomas.find(AutoConfig.idioma)
	if idioma_index < 0:
		idioma_index = 0
	option_language.select(idioma_index)

func _on_option_language_pressed() -> void:
	var popup := option_language.get_popup()
	await get_tree().process_frame
	popup.size.x = int(option_language.size.x)

func _on_option_language_item_selected(index: int) -> void:
	if index < 0 or index >= _idiomas.size():
		return
	AutoConfig.set_idioma(_idiomas[index])

func _on_salvar_secao_pressed() -> void:
	AutoConfig.salvar_secao(AutoConfig.SecaoConfig.JOGO)

func _on_restaurar_secao_pressed() -> void:
	await AutoConfig.restaurar_secao_padrao_em_memoria(
		AutoConfig.SecaoConfig.JOGO
	)
