extends Node3D

@onready var mesh_base: Dictionary[String, Node3D] = {
	"Body": %Body,
	"Eyelash": %Eyelash,
	"Teeth": %Teeth,
	"Tongue": %Tongue,
	"Nails": %Nails,
	"Eyebrow": %Eyebrow,
	"Eye": %Eye,
	"Hair": %Hair
}

@onready var mesh_clothes: Dictionary[String, Node3D] = {
	"Action_outfits": %ActionOutfits,
	"Complete_outfits": %CompleteOutfits,
	"Feet": %Feet,
	"Lower_body": %LowerBody,
	"Upper_body": %UpperBody
}
