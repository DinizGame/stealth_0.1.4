class_name ParametroShaderEditavel
extends Resource

## Tipo de controle que o painel deve criar para este parâmetro.
enum TipoControle {
	FLOAT,
	COLOR,
	TEXTURE,
	BOOL
}

## Material que receberá o valor durante a edição.
## MATERIAL_ITEM usa o material da própria mesh instalada.
## BAKE_COR e BAKE_ROUGHNESS usam os materiais dos SubViewports do corpo.
enum AlvoMaterial {
	MATERIAL_ITEM,
	BAKE_COR,
	BAKE_ROUGHNESS
}

@export_group("Identificação")
## Identificador estável usado no JSON. Não deve mudar depois que houver saves.
@export var id: StringName = &""
## Texto mostrado na interface. Se estiver vazio, o ID será usado.
@export var titulo: String = ""
## Nome da aba em que o controle será criado, por exemplo Corpo ou Traje.
@export var aba: StringName = &"Geral"

@export_group("Shader")
## Nome exato do uniform no shader. É sensível a maiúsculas e minúsculas.
@export var shader_parameter: StringName = &""
@export var tipo_controle: TipoControle = TipoControle.FLOAT
@export var alvo_material: AlvoMaterial = AlvoMaterial.MATERIAL_ITEM
## Superfície usada quando o alvo é MATERIAL_ITEM.
@export_range(0, 31, 1) var surface_index: int = 0

@export_group("Configuração de Float")
@export var valor_minimo: float = 0.0
@export var valor_maximo: float = 1.0
@export var incremento: float = 0.01

@export_group("Configuração de Textura")
## Pasta usada pelo base_option para listar as texturas permitidas.
@export_dir var pasta_opcoes: String = ""


func get_titulo_exibicao() -> String:
	if not titulo.is_empty():
		return titulo

	return String(id).replace("_", " ").capitalize()


func is_valid() -> bool:
	if id.is_empty():
		return false

	if shader_parameter.is_empty():
		return false

	if tipo_controle == TipoControle.FLOAT:
		return valor_maximo >= valor_minimo and incremento > 0.0

	if tipo_controle == TipoControle.TEXTURE:
		return not pasta_opcoes.is_empty()

	# COLOR e BOOL não precisam de configurações adicionais.
	return true
