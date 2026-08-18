extends RefCounted


static func carregar_config(path: String) -> ConfigFile:
	var config := ConfigFile.new()
	var erro := config.load(path)

	if erro != OK:
		return null

	return config


static func salvar_config(config: ConfigFile, path: String) -> Error:
	return config.save(path)


static func carregar_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var arquivo := FileAccess.open(path, FileAccess.READ)
	if arquivo == null:
		push_error("Não foi possível abrir o JSON: %s" % path)
		return {}

	var conteudo := arquivo.get_as_text()
	arquivo.close()

	var dados = JSON.parse_string(conteudo)
	if dados is not Dictionary:
		push_error("JSON inválido ou incompatível: %s" % path)
		return {}

	return dados


static func criar_backup(origem: String, destino: String) -> Error:
	if not FileAccess.file_exists(origem):
		return ERR_FILE_NOT_FOUND

	var arquivo_origem := FileAccess.open(origem, FileAccess.READ)
	if arquivo_origem == null:
		return ERR_CANT_OPEN

	var conteudo := arquivo_origem.get_buffer(arquivo_origem.get_length())
	arquivo_origem.close()

	var arquivo_destino := FileAccess.open(destino, FileAccess.WRITE)
	if arquivo_destino == null:
		return ERR_CANT_CREATE

	arquivo_destino.store_buffer(conteudo)
	arquivo_destino.close()
	return OK


static func salvar_json(path: String, dados: Dictionary) -> Error:
	var arquivo := FileAccess.open(path, FileAccess.WRITE)
	if arquivo == null:
		push_error("Não foi possível criar o JSON: %s" % path)
		return ERR_CANT_CREATE

	arquivo.store_string(JSON.stringify(dados, "\t"))
	arquivo.close()
	return OK
