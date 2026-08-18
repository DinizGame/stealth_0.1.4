extends HBoxContainer


const InputIconResolver = preload(
	"res://ScriptGlobais/settings/input_icon_resolver.gd"
)

@onready var label_title: Label = (
	$PanelContainer/HBoxContainer/LabelTitle
)
@onready var icone_acao_1: TextureRect = (
	$PanelContainer/HBoxContainer/IconeTecla
)
@onready var icone_acao_2: TextureRect = (
	$PanelContainer/HBoxContainer/IconeTecla2
)
@onready var icone_plus: TextureRect = (
	$PanelContainer/HBoxContainer/IconePlus
)
@onready var icone_ajuste_ui: TextureRect = $IconeAjustUI

@export_group("Identificação")
@export var titulo: String = "Ação composta"

@export_group("Ações de origem")
@export var action_id_1: StringName
@export var action_id_2: StringName


func _ready() -> void:
	label_title.text = titulo

	if not AutoConfig.atualizar_plataforma.is_connected(
		atualizar_icones
	):
		AutoConfig.atualizar_plataforma.connect(
			atualizar_icones
		)

	if not AutoConfig.inputs_alterados.is_connected(
		atualizar_icones
	):
		AutoConfig.inputs_alterados.connect(
			atualizar_icones
		)

	atualizar_icones()


func atualizar_icones() -> void:
	label_title.text = titulo
	var pasta := _obter_pasta_icones()

	icone_acao_1.texture = InputIconResolver.obter_textura_acao(
		action_id_1,
		pasta
	)
	icone_acao_2.texture = InputIconResolver.obter_textura_acao(
		action_id_2,
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
