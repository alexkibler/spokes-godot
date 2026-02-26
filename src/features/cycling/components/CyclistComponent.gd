class_name CyclistComponent
extends Node

## Base class for cyclist components to allow automatic initialization by the Cyclist root.

var cyclist: Node2D

func initialize(parent_cyclist: Node2D) -> void:
	cyclist = parent_cyclist
