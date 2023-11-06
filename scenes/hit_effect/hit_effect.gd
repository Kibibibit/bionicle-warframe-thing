extends GPUParticles3D



func _process(_delta):
	if (!emitting):
		_die.call_deferred()

func _die():
	self.queue_free()
	self.get_parent().remove_child(self)
