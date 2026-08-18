extends CanvasLayer

@onready var sub_cam: SubViewport = %SubCam

func _on_check_sub_cam_toggled(toggled_on: bool) -> void:
	sub_cam.disable_3d = !toggled_on
