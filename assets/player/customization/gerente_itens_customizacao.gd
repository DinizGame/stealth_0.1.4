class_name GerenteItensCustomizacao
extends RefCounted

const SLOT_CONFLICTS := {
	ItemMeshCustomizavel.Slot.COMPLETE_OUTFITS: [
		ItemMeshCustomizavel.Slot.UPPER_BODY,
		ItemMeshCustomizavel.Slot.LOWER_BODY,
		ItemMeshCustomizavel.Slot.FEET
	],
	ItemMeshCustomizavel.Slot.UPPER_BODY: [ItemMeshCustomizavel.Slot.COMPLETE_OUTFITS],
	ItemMeshCustomizavel.Slot.LOWER_BODY: [ItemMeshCustomizavel.Slot.COMPLETE_OUTFITS],
	ItemMeshCustomizavel.Slot.FEET: [ItemMeshCustomizavel.Slot.COMPLETE_OUTFITS]
}

var mesh_base: Dictionary = {}
var mesh_clothes: Dictionary = {}
var bake_color: Texture2D
var bake_roughness: Texture2D
var installed_items: Dictionary = {}


func configurar(
	base_slots: Dictionary,
	clothes_slots: Dictionary,
	color_texture: Texture2D,
	roughness_texture: Texture2D
) -> void:
	mesh_base = base_slots
	mesh_clothes = clothes_slots
	bake_color = color_texture
	bake_roughness = roughness_texture


func instalar_item(item: ItemMeshCustomizavel) -> Dictionary:
	if item == null or not item.is_valid():
		push_error("Item customizável inválido.")
		return {}

	var slot_node: Node3D = _get_slot_node(item.slot)

	if slot_node == null:
		push_error("O personagem não possui o slot: %s" % item.get_slot_key())
		return {}

	for conflicting_slot: int in SLOT_CONFLICTS.get(item.slot, []):
		remover_item(conflicting_slot)

	_clear_slot(slot_node)

	var instance: Node = item.cena.instantiate()

	if not instance is Node3D:
		push_error("A cena de '%s' precisa ter uma raiz Node3D." % item.id)
		instance.free()
		return {}

	slot_node.add_child(instance)

	var mesh: MeshInstance3D = _find_mesh(instance, item.nome_mesh)

	if mesh == null:
		push_error("Nenhum MeshInstance3D encontrado em: %s" % item.id)
		_clear_slot(slot_node)
		return {}

	var materials: Dictionary = {}
	var required_surfaces: Dictionary = {}

	if item.recebe_bake_cor or item.recebe_bake_roughness:
		required_surfaces[item.surface_bake] = true

	for parameter: ParametroShaderEditavel in item.parametros:
		if parameter.alvo_material == ParametroShaderEditavel.AlvoMaterial.MATERIAL_ITEM:
			required_surfaces[parameter.surface_index] = true

	for surface: int in required_surfaces:
		var material: ShaderMaterial = _duplicate_surface_material(mesh, surface)

		if material == null:
			_clear_slot(slot_node)
			return {}

		materials[surface] = material

	var bake_material: ShaderMaterial = materials.get(item.surface_bake) as ShaderMaterial

	if bake_material:
		if item.recebe_bake_cor:
			bake_material.set_shader_parameter(item.shader_parameter_bake_cor, bake_color)
		if item.recebe_bake_roughness:
			bake_material.set_shader_parameter(item.shader_parameter_bake_roughness, bake_roughness)

	var installed := {
		"item": item,
		"instance": instance,
		"mesh": mesh,
		"materials": materials
	}
	installed_items[item.slot] = installed
	return installed


func remover_item(slot: int) -> void:
	var slot_node: Node3D = _get_slot_node(slot)

	if slot_node:
		_clear_slot(slot_node)

	installed_items.erase(slot)


func _get_slot_node(slot: int) -> Node3D:
	var key: String = String(ItemMeshCustomizavel.slot_to_key(slot))

	if mesh_base.has(key):
		return mesh_base[key] as Node3D
	if mesh_clothes.has(key):
		return mesh_clothes[key] as Node3D

	return null


func _clear_slot(slot_node: Node3D) -> void:
	for child: Node in slot_node.get_children():
		slot_node.remove_child(child)
		child.queue_free()


func _find_mesh(root: Node, mesh_name: StringName) -> MeshInstance3D:
	if not mesh_name.is_empty():
		return root.find_child(String(mesh_name), true, false) as MeshInstance3D

	if root is MeshInstance3D:
		return root as MeshInstance3D

	for child: Node in root.get_children():
		var found: MeshInstance3D = _find_mesh(child, &"")
		if found:
			return found

	return null


func _duplicate_surface_material(mesh: MeshInstance3D, surface: int) -> ShaderMaterial:
	if mesh.mesh == null or surface >= mesh.mesh.get_surface_count():
		push_error("A mesh '%s' não possui a superfície %d." % [mesh.name, surface])
		return null

	var original: Material = mesh.get_active_material(surface)

	if not original is ShaderMaterial:
		push_error("A superfície %d de '%s' precisa usar ShaderMaterial." % [surface, mesh.name])
		return null

	var duplicated := (original as ShaderMaterial).duplicate() as ShaderMaterial
	mesh.set_surface_override_material(surface, duplicated)
	return duplicated
