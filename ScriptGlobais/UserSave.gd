extends Node

const SAVE_DIR: String = "user://saves/"
const INDEX_FILE: String = "user://saves/index.dat"

# Estrutura do Index em memória
var valid_saves: Dictionary = {}
var ignored_files: Array = []
var perfil_user: String = ""

# Reference to the security manager (will be injected or loaded)
var _security_manager: SecurityManager


func _ready() -> void:
	_ensure_security_manager()
	_ensure_save_directory_exists()
	_load_index()
	# Sempre que o jogo abre, ele faz uma varredura rápida para achar arquivos que
	# foram jogados na pasta mas não estão em nenhuma das duas listas.
	_sync_untracked_files()


## Ensure SecurityManager is available
func _ensure_security_manager() -> void:
	if _security_manager == null:
		# Try to get from autoload first
		if has_node("/root/SecurityManager"):
			_security_manager = get_node("/root/SecurityManager")
		else:
			# Fallback: create a new instance
			_security_manager = SecurityManager.new()
			add_child(_security_manager)


## Get the encryption key from SecurityManager
func _get_encryption_key() -> String:
	if _security_manager == null:
		_ensure_security_manager()
	return _security_manager.get_encryption_key()


func _ensure_save_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err := DirAccess.make_dir_absolute(SAVE_DIR)
		if err != OK:
			push_error("Falha ao criar o diretório de saves. Erro: ", err)

# ==========================================
# GERENCIAMENTO DO ÍNDICE
# ==========================================

func _load_index() -> void:
	if FileAccess.file_exists(INDEX_FILE):
		var encryption_key := _get_encryption_key()
		var file := FileAccess.open_encrypted_with_pass(INDEX_FILE, FileAccess.READ, encryption_key)
		if file:
			var data: Dictionary = file.get_var()
			# Garante que as chaves existam caso seja uma versão antiga do save
			valid_saves = data.get("validos", {})
			ignored_files = data.get("ignorados", [])
			file.close()
			return
		else:
			push_error("Index corrompido ou chave inválida. O sistema fará a reconstrução no próximo passo.")
			
	valid_saves = {}
	ignored_files = []

func _save_index() -> void:
	var encryption_key := _get_encryption_key()
	var file := FileAccess.open_encrypted_with_pass(INDEX_FILE, FileAccess.WRITE, encryption_key)
	if file:
		var data := {
			"validos": valid_saves,
			"ignorados": ignored_files
		}
		file.store_var(data)
		file.close()
	else:
		push_error("Falha ao salvar o arquivo de index.")

func get_valid_saves_metadata() -> Dictionary:
	return valid_saves

# ==========================================
# VARREDURA E RECONSTRUÇÃO (STATE RECONCILIATION)
# ==========================================

func rename_save(save_id: String, novo_nome: String) -> String:
	novo_nome = novo_nome.strip_edges()

	if save_id == "":
		return ""

	if novo_nome.length() < 2:
		return ""

	var dados := load_game_data(save_id)

	if dados.is_empty():
		return ""

	create_or_update_save(
		novo_nome,
		dados,
		save_id
	)

	var metadata: Dictionary = valid_saves.get(save_id, {})
	return str(metadata.get("nome", ""))

func _extract_metadata_from_save_data(full_data: Dictionary) -> Dictionary:
	return {
		"nome": full_data.get("nome_jogador", "Desconhecido"),
		"ultima_vez": full_data.get("data_salvamento", "Desconhecida"),
		"tempo_jogo": full_data.get("tempo_jogo", 0),
		"progresso": full_data.get("progresso", 0),
		"level": full_data.get("level", 1),
		"money": full_data.get("money", 0)
	}

# Lê apenas arquivos que não estão mapeados no index atual
func _sync_untracked_files() -> void:
	var files := DirAccess.get_files_at(SAVE_DIR)
	var index_changed := false
	
	for file_name in files:
		# Pula o próprio arquivo de index e arquivos que não são de save
		if file_name == "index.dat" or not file_name.ends_with(".dat"):
			continue
			
		var save_id: String = file_name.get_basename()
		
		# Se já conhecemos o arquivo (válido ou ignorado), pula a leitura pesada
		if valid_saves.has(save_id) or save_id in ignored_files:
			continue
			
		# Arquivo desconhecido encontrado! Vamos testá-lo.
		var is_valid := _verify_and_extract_save(save_id)
		if is_valid:
			index_changed = true
			print("Novo save válido detectado e indexado: ", save_id)
		else:
			ignored_files.append(save_id)
			index_changed = true
			print("Arquivo inválido detectado e adicionado à lista de ignorados: ", save_id)
			
	if index_changed:
		_save_index()

# Tenta descriptografar e extrair os metadados. Retorna true se for um save legítimo.
func _verify_and_extract_save(save_id: String) -> bool:
	var path := SAVE_DIR + save_id + ".dat"
	var encryption_key := _get_encryption_key()
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, encryption_key)

	if file:
		var full_data = file.get_var()
		file.close()

		if typeof(full_data) == TYPE_DICTIONARY and full_data.has("nome_jogador"):
			valid_saves[save_id] = _extract_metadata_from_save_data(full_data)
			return true

	return false

# A função de Força Bruta solicitada. Apaga o mapa atual e varre tudo do zero.
func rebuild_entire_index() -> void:
	print("Iniciando reconstrução total do sistema de saves...")
	valid_saves.clear()
	ignored_files.clear()
	
	# Deleta o arquivo físico do index para garantir uma base limpa
	if FileAccess.file_exists(INDEX_FILE):
		DirAccess.remove_absolute(INDEX_FILE)
		
	# A função de sync agora vai enxergar todos os arquivos como "desconhecidos" e testar um por um
	_sync_untracked_files()
	print("Reconstrução finalizada. Saves recuperados: ", valid_saves.size())

# ==========================================
# OPERAÇÕES DE ROTINA (Salvar, Carregar, Deletar)
# ==========================================

func _normalizar_nome_save(nome: String) -> String:
	return nome.strip_edges().to_lower()


func _save_name_exists(nome: String, ignore_save_id: String = "") -> bool:
	var nome_normalizado := _normalizar_nome_save(nome)

	for save_id in valid_saves.keys():
		if save_id == ignore_save_id:
			continue

		var meta: Dictionary = valid_saves[save_id]
		var nome_existente := str(meta.get("nome", ""))

		if _normalizar_nome_save(nome_existente) == nome_normalizado:
			return true

	return false


func _gerar_nome_unico(nome_base: String, ignore_save_id: String = "") -> String:
	nome_base = nome_base.strip_edges()

	if nome_base.length() < 2:
		return nome_base

	if not _save_name_exists(nome_base, ignore_save_id):
		return nome_base

	var contador := 2

	while true:
		var nome_teste := "%s (%d)" % [nome_base, contador]

		if not _save_name_exists(nome_teste, ignore_save_id):
			return nome_teste

		contador += 1

	return nome_base

func create_or_update_save(player_name: String, full_game_data: Dictionary, existing_id: String = "") -> String:
	var save_id: String = existing_id

	if save_id == "":
		save_id = str(Time.get_unix_time_from_system()).replace(".", "") + "_" + str(randi() % 1000)

	var nome_final := _gerar_nome_unico(
		player_name,
		save_id
	)

	# Injeta dados de metadados diretamente no arquivo pesado para futura recuperação
	full_game_data["nome_jogador"] = nome_final
	full_game_data["data_salvamento"] = Time.get_datetime_string_from_system()

	valid_saves[save_id] = _extract_metadata_from_save_data(full_game_data)

	if save_id in ignored_files:
		ignored_files.erase(save_id)

	_save_index()

	var path := SAVE_DIR + save_id + ".dat"
	var encryption_key := _get_encryption_key()
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, encryption_key)

	if file:
		file.store_var(full_game_data)
		file.close()
	else:
		push_error("Falha fatal ao gravar dados do jogo no disco.")

	return save_id

func load_game_data(save_id: String) -> Dictionary:
	if not valid_saves.has(save_id):
		return {}
		
	var path := SAVE_DIR + save_id + ".dat"
	var encryption_key := _get_encryption_key()
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, encryption_key)
	if file:
		var data: Dictionary = file.get_var()
		file.close()
		return data
		
	push_error("Save constava como válido, mas falhou ao abrir. Reconstrução recomendada.")
	return {}

func delete_save(save_id: String) -> void:
	valid_saves.erase(save_id)
	ignored_files.erase(save_id) # Limpa caso estivesse ignorado também
	_save_index()
	
	var path := SAVE_DIR + save_id + ".dat"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
