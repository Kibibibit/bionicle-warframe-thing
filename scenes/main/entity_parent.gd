extends Node3D


var bullet_scene: PackedScene = preload("res://scenes/bullet/bullet.tscn")

func _ready():
	for child in get_children():
		if (child is Player):
			child.shoot.connect(_on_shoot)


func _on_shoot(origin: Vector3, target: Vector3) -> void:
	var bullet: Bullet = bullet_scene.instantiate()
	bullet.look_at_from_position(origin, target)
	bullet.target = target
	add_child(bullet)
