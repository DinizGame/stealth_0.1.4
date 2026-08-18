extends Node3D

@onready var animation_tree: AnimationTree = $AnimationTree

var current_moving: String = "parameters/StandingBlendSpace1D/blend_position"


func set_moving(valor: float) -> void:
	animation_tree.set(current_moving, valor)

func set_mode_moving(crouch: bool):
	if not crouch:
		animation_tree.set("parameters/OptionMove/transition_request", "crouch")
		current_moving = "parameters/CrouchBlendSpace1D/blend_position"
	else:
		animation_tree.set("parameters/OptionMove/transition_request", "standing")
		current_moving = "parameters/StandingBlendSpace1D/blend_position"
