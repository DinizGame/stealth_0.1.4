extends RefCounted


const RESOLUCOES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

# A interface foi construída usando 1280 x 720 como referência.
# Esse valor não muda quando a resolução da janela é alterada.
const RESOLUCAO_BASE_INTERFACE := Vector2i(1280, 720)

const ESCALAS_INTERFACE: Array[float] = [
	0.75,
	1.0,
	1.25
]

const MARGEM_JANELA := Vector2i(80, 80)

# Um único tema base é suficiente. O Window escala o tema, as fontes,
# os ícones e os espaçamentos de forma uniforme.
const TEMA_BASE := preload(
	"res://UI_ASSETS/themes/theme_720p.tres"
)

# Mantido com o nome antigo para não quebrar cenas existentes.
# Agora representa somente o índice da resolução da janela.
var resolution_multiplier: int = 1
var interface_scale_index: int = 1
var fullscreen: bool = true

# Mantido por compatibilidade com chamadas antigas.
var tema_atual_index: int = 1


func carregar(config: ConfigFile) -> void:
	resolution_multiplier = clampi(
		int(config.get_value("video", "resolution_multiplier", 1)),
		0,
		RESOLUCOES.size() - 1
	)

	interface_scale_index = clampi(
		int(config.get_value("video", "interface_scale_index", 1)),
		0,
		ESCALAS_INTERFACE.size() - 1
	)

	fullscreen = bool(config.get_value("video", "fullscreen", true))


func escrever(config: ConfigFile) -> void:
	config.set_value(
		"video",
		"resolution_multiplier",
		resolution_multiplier
	)
	config.set_value(
		"video",
		"interface_scale_index",
		interface_scale_index
	)
	config.set_value("video", "fullscreen", fullscreen)


func criar_snapshot() -> Dictionary:
	return {
		"resolution_multiplier": resolution_multiplier,
		"interface_scale_index": interface_scale_index,
		"fullscreen": fullscreen
	}


func restaurar_snapshot(snapshot: Dictionary) -> void:
	resolution_multiplier = clampi(
		int(snapshot.get("resolution_multiplier", 1)),
		0,
		RESOLUCOES.size() - 1
	)

	interface_scale_index = clampi(
		int(snapshot.get("interface_scale_index", 1)),
		0,
		ESCALAS_INTERFACE.size() - 1
	)

	fullscreen = bool(snapshot.get("fullscreen", true))


func aplicar(tree: SceneTree) -> void:
	var window := tree.root
	var resolution_index := clampi(
		resolution_multiplier,
		0,
		RESOLUCOES.size() - 1
	)
	var scale_index := clampi(
		interface_scale_index,
		0,
		ESCALAS_INTERFACE.size() - 1
	)

	resolution_multiplier = resolution_index
	interface_scale_index = scale_index
	tema_atual_index = scale_index

	# Resolução física e escala visual passam a ser independentes.
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	window.content_scale_size = RESOLUCAO_BASE_INTERFACE
	window.content_scale_factor = ESCALAS_INTERFACE[scale_index]

	aplicar_tema(tree)

	# Mantém a aplicação assíncrona em todos os modos de janela.
	await tree.process_frame

	if fullscreen:
		# Em tela cheia, o Godot usa o tamanho físico do monitor.
		window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		return

	window.mode = Window.MODE_WINDOWED
	await tree.process_frame

	window.size = calcular_tamanho_janela_seguro(
		window,
		RESOLUCOES[resolution_index]
	)

	await tree.process_frame
	centralizar_janela(window)


func aplicar_tema(
	tree: SceneTree,
	_index_compatibilidade: int = -1
) -> Theme:
	tree.root.theme = TEMA_BASE
	return TEMA_BASE


func get_tema_atual() -> Theme:
	return TEMA_BASE


func get_escala_interface() -> float:
	return ESCALAS_INTERFACE[
		clampi(
			interface_scale_index,
			0,
			ESCALAS_INTERFACE.size() - 1
		)
	]


func calcular_tamanho_janela_seguro(
	window: Window,
	tamanho_desejado: Vector2i
) -> Vector2i:
	var area_util := DisplayServer.screen_get_usable_rect(
		window.current_screen
	)

	var tamanho_maximo := Vector2i(
		maxi(area_util.size.x - MARGEM_JANELA.x, 1),
		maxi(area_util.size.y - MARGEM_JANELA.y, 1)
	)

	if (
		tamanho_desejado.x <= tamanho_maximo.x
		and tamanho_desejado.y <= tamanho_maximo.y
	):
		return tamanho_desejado

	var escala := minf(
		float(tamanho_maximo.x) / float(tamanho_desejado.x),
		float(tamanho_maximo.y) / float(tamanho_desejado.y)
	)

	return Vector2i(
		maxi(roundi(tamanho_desejado.x * escala), 1),
		maxi(roundi(tamanho_desejado.y * escala), 1)
	)


func centralizar_janela(window: Window) -> void:
	var area_util := DisplayServer.screen_get_usable_rect(
		window.current_screen
	)

	@warning_ignore("integer_division")
	window.position = (
		area_util.position
		+ (area_util.size - window.size) / 2
	)
