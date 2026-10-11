class_name Interactable
extends Node
 
var outline_mesh: Node3D

func show_outline():
	if outline_mesh:
		outline_mesh.visible = true

func hide_outline():
	if outline_mesh:
		outline_mesh.visible = false
