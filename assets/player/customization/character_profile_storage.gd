class_name CharacterProfileStorage
extends RefCounted

const ROOT_DIR := "user://profiles/body_bakes"
const PROFILE_FILE := "profile.json"
const COLOR_FILE := "body_color.png"
const ROUGHNESS_FILE := "body_roughness.png"


static func listar_perfis() -> Array[Dictionary]:
	var perfis: Array[Dictionary] = []
	var erro_pasta: Error = DirAccess.make_dir_recursive_absolute(ROOT_DIR)

	if erro_pasta != OK:
		push_error("Não foi possível criar a pasta de perfis: %s" % ROOT_DIR)
		return perfis

	var diretorio := DirAccess.open(ROOT_DIR)

	if diretorio == null:
		push_error("Não foi possível abrir a pasta de perfis: %s" % ROOT_DIR)
		return perfis

	diretorio.list_dir_begin()
	var entrada: String = diretorio.get_next()

	while not entrada.is_empty():
		if diretorio.current_is_dir() and not entrada.begins_with("."):
			var dados: Dictionary = carregar_perfil(entrada)

			if not dados.is_empty():
				perfis.append({
					"id": entrada,
					"nome": str(dados.get("nome", entrada))
				})

		entrada = diretorio.get_next()

	diretorio.list_dir_end()
	perfis.sort_custom(_ordenar_perfis)
	return perfis


static func gerar_id_perfil() -> String:
	return "profile_%d_%d" % [
		int(Time.get_unix_time_from_system()),
		Time.get_ticks_msec()
	]


static func salvar_perfil(
	perfil_id: String,
	nome: String,
	dados_customizacao: Dictionary,
	imagem_cor: Image,
	imagem_roughness: Image
) -> Error:
	if perfil_id.is_empty() or nome.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER

	if imagem_cor == null or imagem_cor.is_empty():
		return ERR_INVALID_DATA

	if imagem_roughness == null or imagem_roughness.is_empty():
		return ERR_INVALID_DATA

	var pasta_perfil: String = _obter_pasta_perfil(perfil_id)
	var erro_pasta: Error = DirAccess.make_dir_recursive_absolute(pasta_perfil)

	if erro_pasta != OK:
		return erro_pasta

	var erro_cor: Error = imagem_cor.save_png(
		pasta_perfil.path_join(COLOR_FILE)
	)

	if erro_cor != OK:
		return erro_cor

	var erro_roughness: Error = imagem_roughness.save_png(
		pasta_perfil.path_join(ROUGHNESS_FILE)
	)

	if erro_roughness != OK:
		return erro_roughness

	var dados_finais: Dictionary = dados_customizacao.duplicate(true)
	dados_finais["versao"] = 1
	dados_finais["perfil_id"] = perfil_id
	dados_finais["nome"] = nome.strip_edges()
	dados_finais["bakes"] = {
		"cor": COLOR_FILE,
		"roughness": ROUGHNESS_FILE
	}

	var caminho_json: String = pasta_perfil.path_join(PROFILE_FILE)
	var arquivo := FileAccess.open(caminho_json, FileAccess.WRITE)

	if arquivo == null:
		return FileAccess.get_open_error()

	arquivo.store_string(
		JSON.stringify(dados_finais, "\t", true, true)
	)
	arquivo.close()
	return OK


static func carregar_perfil(perfil_id: String) -> Dictionary:
	if perfil_id.is_empty():
		return {}

	var caminho_json: String = _obter_pasta_perfil(perfil_id).path_join(
		PROFILE_FILE
	)

	if not FileAccess.file_exists(caminho_json):
		return {}

	var texto_json: String = FileAccess.get_file_as_string(caminho_json)
	var resultado: Variant = JSON.parse_string(texto_json)

	if resultado is Dictionary:
		var dados: Dictionary = resultado
		return dados

	push_warning("Perfil inválido ou corrompido: %s" % perfil_id)
	return {}


static func _obter_pasta_perfil(perfil_id: String) -> String:
	return ROOT_DIR.path_join(perfil_id)


static func _ordenar_perfis(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("nome", "")).naturalnocasecmp_to(
		str(b.get("nome", ""))
	) < 0
