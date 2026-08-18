extends RefCounted


var idioma: String = "pt_BR"


func carregar(config: ConfigFile) -> void:
	idioma = str(config.get_value("geral", "idioma", "pt_BR"))


func escrever(config: ConfigFile) -> void:
	config.set_value("geral", "idioma", idioma)


func aplicar() -> void:
	TranslationServer.set_locale(idioma)


func criar_snapshot() -> Dictionary:
	return {"idioma": idioma}


func restaurar_snapshot(snapshot: Dictionary) -> void:
	idioma = str(snapshot.get("idioma", "pt_BR"))
