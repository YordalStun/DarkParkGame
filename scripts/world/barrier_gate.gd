extends Node3D
## Red-and-white barrier arm at the lot entrance. Call open()/close() from missions.
## Origin = base of the housing. The arm extends along local -X.

signal moved(is_open: bool)

@export var arm_length := 3.8
var is_open := false
var _pivot: Node3D


func _ready() -> void:
	var yellow := MK.mat(Color(0.75, 0.6, 0.1), "metal", 0.5, 1.0, 0.2)
	var dark := MK.mat(Color(0.1, 0.1, 0.1), "metal", 0.5)
	MK.box(self, Vector3(0.35, 1.0, 0.3), Vector3(0, 0.5, 0), yellow, Vector3.ZERO, "Housing")
	MK.box(self, Vector3(0.38, 0.04, 0.33), Vector3(0, 1.02, 0), dark)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_pivot.position = Vector3(-0.1, 0.92, 0.18)
	add_child(_pivot)
	var red := MK.mat(Color(0.7, 0.05, 0.04), "", 0.35)
	var white := MK.mat(Color(0.9, 0.9, 0.86), "", 0.35)
	var seg := 8
	var sl := arm_length / seg
	for i in seg:
		MK.box(_pivot, Vector3(sl, 0.08, 0.05), Vector3(-sl * (i + 0.5), 0, 0), red if i % 2 == 0 else white)
	# Rest post at the far end.
	MK.box(self, Vector3(0.08, 0.85, 0.08), Vector3(-arm_length + 0.1, 0.42, 0.18), yellow)


func open(duration := 2.5) -> void:
	_swing(true, duration)


func close(duration := 2.5) -> void:
	_swing(false, duration)


func _swing(to_open: bool, duration: float) -> void:
	is_open = to_open
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_pivot, "rotation:z", -deg_to_rad(80.0) if to_open else 0.0, duration)
	moved.emit(to_open)
