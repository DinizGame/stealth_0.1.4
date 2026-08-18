extends HBoxContainer


@export_enum(
	"Jogo",
	"Vídeo",
	"Áudio",
	"Inputs"
)
var secao: int = 0


@onready var restore_section: Button = (
	$RestoreSection
)

@onready var save_section: Button = (
	$SaveSection
)

@onready var separador: HSeparator = (
	get_node_or_null("../HSeparatorActions")
	as HSeparator
)


func _ready() -> void:
	if not AutoConfig.estado_secao_alterado.is_connected(
		_on_estado_secao_alterado
	):
		AutoConfig.estado_secao_alterado.connect(
			_on_estado_secao_alterado
		)

	_atualizar_visibilidade()


func _exit_tree() -> void:
	if AutoConfig.estado_secao_alterado.is_connected(
		_on_estado_secao_alterado
	):
		AutoConfig.estado_secao_alterado.disconnect(
			_on_estado_secao_alterado
		)


func _on_estado_secao_alterado(
	secao_alterada: int
) -> void:
	if secao_alterada != secao:
		return

	_atualizar_visibilidade()


func _atualizar_visibilidade() -> void:
	var mostrar_salvar: bool = bool(
		AutoConfig.tem_alteracoes_secao(secao)
	)

	var mostrar_restaurar: bool = bool(
		AutoConfig.secao_tem_diferenca_do_padrao(
			secao
		)
	)

	save_section.visible = mostrar_salvar
	restore_section.visible = mostrar_restaurar

	var mostrar_acoes: bool = (
		mostrar_salvar
		or mostrar_restaurar
	)

	visible = mostrar_acoes

	if separador != null:
		separador.visible = mostrar_acoes
