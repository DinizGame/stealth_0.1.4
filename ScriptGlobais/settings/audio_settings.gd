extends RefCounted


const BUS_MAP := {
	"master": "Master",
	"music": "Music",
	"sfx": "SFX"
}

var valores := {
	"master": 100.0,
	"music": 100.0,
	"sfx": 100.0
}


func carregar(config: ConfigFile) -> void:
	for id in valores:
		valores[id] = clampf(
			float(config.get_value("audio", id, 100.0)),
			0.0,
			100.0
		)


func escrever(config: ConfigFile) -> void:
	for id in valores:
		config.set_value("audio", id, valores[id])


func get_audio(id: String) -> float:
	return float(valores.get(id, 100.0))


func set_audio(id: String, valor: float) -> void:
	if not valores.has(id):
		push_warning("Bus de áudio não registrado: %s" % id)
		return

	valores[id] = clampf(valor, 0.0, 100.0)
	aplicar_bus(id)


func aplicar() -> void:
	for id in valores:
		aplicar_bus(id)


func aplicar_bus(id: String) -> void:
	var nome_bus := str(BUS_MAP.get(id, ""))
	if nome_bus.is_empty():
		return

	var indice := AudioServer.get_bus_index(nome_bus)
	if indice == -1:
		return

	var valor := get_audio(id)
	var volume_db := -80.0 if valor <= 0.0 else linear_to_db(valor / 100.0)
	AudioServer.set_bus_volume_db(indice, volume_db)


func criar_snapshot() -> Dictionary:
	return valores.duplicate(true)


func restaurar_snapshot(snapshot: Dictionary) -> void:
	for id in valores:
		valores[id] = clampf(
			float(snapshot.get(id, 100.0)),
			0.0,
			100.0
		)
