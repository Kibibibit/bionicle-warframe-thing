extends Node3D
class_name Bullet

@onready
var ray: RayCast3D = $RayCast3D

var hit_effect_scene: PackedScene = preload("res://scenes/hit_effect/hit_effect.tscn")


var target: Vector3
var speed: float = 50

var time_to_live: float = 10.0;

var die_next_frame: bool = false
var body: Node3D

func _ready():
	ray.target_position = Vector3(0,0,-speed)
	target = position.direction_to(target)


func _physics_process(delta):
	time_to_live -= delta
	if (time_to_live <= 0):
		_delete.call_deferred()
		return
		
	else:
		position += target*speed*delta
		if (ray.is_colliding()):
			_hit()

func _hit():
	time_to_live = 0.0
	body = ray.get_collider()
	var particles: GPUParticles3D = hit_effect_scene.instantiate()
	get_parent().add_child(particles)
	particles.global_position = ray.get_collision_point()
	particles.global_rotation = self.global_rotation
	particles.emitting = true
	
	
func _delete():
	if (!self.is_queued_for_deletion()):
		self.queue_free()
		self.get_parent().remove_child(self)
