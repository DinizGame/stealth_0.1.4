class_name ItemMeshCustomizavel
extends Resource

## Slot físico ocupado pelo item no body_custon.gd.
enum Slot {
	BODY,
	EYELASH,
	TEETH,
	TONGUE,
	NAILS,
	EYEBROW,
	EYE,
	HAIR,
	ACTION_OUTFITS,
	COMPLETE_OUTFITS,
	FEET,
	LOWER_BODY,
	UPPER_BODY
}

@export_group("Identificação")
## Identificador estável usado nos saves. Não renomeie depois de publicar perfis.
@export var id: StringName = &""
## Nome apresentado ao jogador.
@export var titulo: String = ""
## Local em que a cena será instalada.
@export var slot: Slot = Slot.BODY
@export var miniatura: Texture2D

@export_group("Cena e Mesh")
## Cena real da mesh. Não é necessário anexar um script diferente nela.
@export var cena: PackedScene
## Opcional. Vazio faz o gerente localizar o primeiro MeshInstance3D recursivamente.
@export var nome_mesh: StringName = &""

@export_group("Integração com Bake")
@export var recebe_bake_cor: bool = false
@export var recebe_bake_roughness: bool = false
@export_range(0, 31, 1) var surface_bake: int = 0
@export var shader_parameter_bake_cor: StringName = &"SkinColor"
@export var shader_parameter_bake_roughness: StringName = &"ColorRoughness"

@export_group("Parâmetros Editáveis")
## Somente estes parâmetros aparecerão na interface.
@export var parametros: Array[ParametroShaderEditavel] = []


func get_titulo_exibicao() -> String:
	if not titulo.is_empty():
		return titulo

	return String(id).replace("_", " ").capitalize()


func get_slot_key() -> StringName:
	return slot_to_key(slot)


static func slot_to_key(slot_value: int) -> StringName:
	match slot_value:
		Slot.BODY:
			return &"Body"
		Slot.EYELASH:
			return &"Eyelash"
		Slot.TEETH:
			return &"Teeth"
		Slot.TONGUE:
			return &"Tongue"
		Slot.NAILS:
			return &"Nails"
		Slot.EYEBROW:
			return &"Eyebrow"
		Slot.EYE:
			return &"Eye"
		Slot.HAIR:
			return &"Hair"
		Slot.ACTION_OUTFITS:
			return &"Action_outfits"
		Slot.COMPLETE_OUTFITS:
			return &"Complete_outfits"
		Slot.FEET:
			return &"Feet"
		Slot.LOWER_BODY:
			return &"Lower_body"
		Slot.UPPER_BODY:
			return &"Upper_body"

	return &""


func is_valid() -> bool:
	if id.is_empty() or cena == null or get_slot_key().is_empty():
		return false

	var found_ids: Dictionary = {}

	for parameter: ParametroShaderEditavel in parametros:
		if parameter == null or not parameter.is_valid():
			return false

		if found_ids.has(parameter.id):
			return false

		found_ids[parameter.id] = true

	return true
