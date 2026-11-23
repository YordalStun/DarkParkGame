class_name Interactable
extends Area3D
## Something the player can point at and click. The desk camera raycasts against
## collision layer 2 and calls `activate()`.
##
## If `zoom_marker` is set, clicking moves the camera to that marker (e.g. the CRT).

signal activated
signal key_used   ## the player pressed E while pointing at it (standing up)

const LAYER := 2

@export var prompt := ""
var zoom_marker: Node3D
var zoom_fov := 40.0
## How far (degrees, yaw/pitch) the player can look around while zoomed to this marker.
## Zero (the CRT) holds the view perfectly still.
var zoom_look := Vector2.ZERO
var enabled := true
## Only usable while the camera is zoomed to this one (e.g. things you reach from the side window).
var requires_focus: Interactable
## Can be used from outside the booth (the door, car boots). Everything else only works from inside.
var outdoor := false


func _init() -> void:
	collision_layer = 0
	set_collision_layer_value(LAYER, true)
	collision_mask = 0
	monitoring = false
	monitorable = false
	input_ray_pickable = false


## Convenience: add a box-shaped hit area.
func add_box(size: Vector3, offset := Vector3.ZERO) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = offset
	add_child(cs)


func activate() -> void:
	activated.emit()
