extends CharacterBody3D
class_name Player

enum PlayerState {
	STILL, 
	WALKING, 
	RUNNING, 
	JUMPING, 
	FALLING, 
	CROUCHING,
	SNEAKING,
	SLIDING, 
	BULLET_JUMPING
}


signal shoot(origin: Vector3, aim_point: Vector3)

@export
var mouse_sensitivity: float = 0.003

@onready
var head: Node3D = $Head
@onready
var init_fov: float = $Head/CameraMount/CameraPoint/Camera3D.fov
@onready
var camera_ray: RayCast3D = $Head/CameraMount/CameraRay
@onready
var camera: Camera3D = $Head/CameraMount/CameraPoint/Camera3D
@onready
var camera_point: Node3D = $Head/CameraMount/CameraPoint
@onready
var aim_ray: RayCast3D = $AimRay
@onready
var arm_point: Node3D = $ArmPoint
@onready
var camera_aim_ray: RayCast3D = $Head/CameraMount/CameraPoint/Camera3D/CameraAimRay
@onready
var gun_origin: Node3D = $ArmPoint/GunOrigin

var player_state: PlayerState = PlayerState.STILL

var grounded: bool = false

var height = 1.0


const SPEED = 5.0
const SPRINT_SPEED = 9.0
const CROUCH_SPEED = 3.5
const JUMP_VELOCITY = 4.5
const GROUND_FRICTION: float = 40.0
const SLIDE_FRICTION: float = 0.01
const BULLET_JUMP_SPEED = 15.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if (event is InputEventKey):
		if (event.pressed && event.keycode == KEY_ESCAPE):
			if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED):
		if (event is InputEventMouseMotion):
			rotation.y += -event.relative.x * mouse_sensitivity
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation_degrees.x = clamp(head.rotation_degrees.x, -90+15, 90-15)
		
		if (event is InputEventMouseButton):
			if (event.pressed && event.button_index == MOUSE_BUTTON_LEFT):
				shoot.emit(gun_origin.global_position, aim_ray.to_global(aim_ray.target_position))

func _process(delta):
	$Mesh.mesh.height = move_toward($Mesh.mesh.height, height*2.0, delta*10.0)
	$Mesh.position.y = move_toward($Mesh.position.y, height, delta*10.0)
	$Head.position.y = move_toward($Head.position.y, height*1.8, delta*10.0)
	
	var horizontal_velocity = velocity
	horizontal_velocity.y = 0
	var speed_fraction: float = 1.0 + pow((horizontal_velocity.length()/45.0),2)
	
	var current_fov: float = camera.fov
	var target_fov: float =  init_fov*speed_fraction
	
	camera.fov = move_toward(current_fov, target_fov, delta*15.0)
	
	
	
	arm_point.look_at(aim_ray.to_global(aim_ray.target_position))
	

func _apply_friction(delta: float, friction: float):
	var new_velocity = velocity.move_toward(Vector3(0,velocity.y,0), delta*friction)
	velocity.x = new_velocity.x
	velocity.z = new_velocity.z
func _physics_process(delta):
	
	
	if (camera_ray.is_colliding()):
		camera_point.position = camera_ray.to_local(camera_ray.get_collision_point())
	else:
		camera_point.position = camera_ray.target_position
	

	
	var aim_point: Vector3 = Vector3(0,0,0)
	
	if (camera_aim_ray.is_colliding()):
		aim_point = camera_aim_ray.get_collision_point()
	else:
		aim_point = camera_aim_ray.to_global(camera_aim_ray.target_position)
	
	aim_ray.target_position = aim_ray.to_local(aim_point)
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= 10.0 * delta
		grounded = false
	else:
		grounded = true
	
	var input_dir = Input.get_vector("action_move_left", "action_move_right", "action_move_up", "action_move_down")
	
	
	match (player_state):
		PlayerState.STILL:
			_process_still(delta, input_dir)
		PlayerState.WALKING:
			_process_walk(delta, input_dir)
		PlayerState.JUMPING:
			_process_jumping(input_dir)
		PlayerState.FALLING:
			_process_falling(input_dir)
		PlayerState.CROUCHING:
			_process_crouching(delta, input_dir)
		PlayerState.SNEAKING:
			_process_sneak(delta, input_dir)
		PlayerState.SLIDING:
			_process_sliding(delta, input_dir)
		PlayerState.RUNNING:
			_process_sprint(delta, input_dir)
		PlayerState.BULLET_JUMPING:
			_process_bullet_jumping(input_dir)
		_:
			pass

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	
	

	move_and_slide()


func _check_jump(bullet_jump: bool = false) -> bool:
	if (grounded and Input.is_action_just_pressed("action_jump")):
		if (!bullet_jump):
			player_state = PlayerState.JUMPING
			velocity.y = JUMP_VELOCITY
		else:
			player_state = PlayerState.BULLET_JUMPING
			
			var jump_angle = Vector3(head.rotation.x, 0.0, 0.0)
			
			var jump_quaternion = Quaternion.from_euler(jump_angle)
			var jump_direction = jump_quaternion * Vector3(0,0,-1)
			
			velocity += transform.basis * jump_direction * BULLET_JUMP_SPEED
			
		return true
	return false


func _check_crouch(next_state: PlayerState) -> bool:
	if (grounded and Input.is_action_pressed("action_crouch")):
		height = 0.5
		if (velocity.length() > 5.0):
			player_state = PlayerState.SLIDING
		else:
			player_state = next_state
		return true
	else:
		height = 1.0
		return false

func _check_sprint() -> bool:
	if (grounded and Input.is_action_pressed("action_sprint")):
		player_state = PlayerState.RUNNING
		return true
	else:
		return false

func _check_falling() -> bool:
	if (velocity.y < 0):
		player_state = PlayerState.FALLING
		return true
	return false

func _process_still(delta: float, input_vector: Vector2):
	
	if (_check_falling()):
		return
	if (!input_vector.is_zero_approx()):
		player_state = PlayerState.WALKING
		return
	if (_check_jump()):
		return
	if (_check_crouch(PlayerState.CROUCHING)):
		return
	
	_apply_friction(delta, GROUND_FRICTION)

func _process_jumping(_input_vector: Vector2):
	if (grounded):
		player_state = PlayerState.STILL
		return
	if (_check_falling()):
		return

func _process_falling(input_vector: Vector2):
	if (grounded):
		if (input_vector):
			player_state = PlayerState.WALKING
			return
		else:
			player_state = PlayerState.STILL
			return

func _process_walk(_delta: float, input_vector: Vector2):
	if (_check_falling()):
		return
	if (_check_jump()):
		return
	if (_check_crouch(PlayerState.SNEAKING)):
		return
	if (_check_sprint()):
		return
	var direction = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	if direction:
		velocity.x = (direction * SPEED).x
		velocity.z = (direction * SPEED).z
	else:
		player_state = PlayerState.STILL
		return

func _process_sprint(_delta: float, input_vector: Vector2):
	if (_check_falling()):
		return
	if (!_check_sprint()):
		player_state = PlayerState.WALKING
		return
	
	if (_check_crouch(PlayerState.SLIDING)):
		return
	
	if (_check_jump()):
		return
	
	var direction = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	if direction:
		velocity.x = (direction * SPRINT_SPEED).x
		velocity.z = (direction * SPRINT_SPEED).z
	else:
		player_state = PlayerState.STILL
		return

func _process_bullet_jumping(_input_vector: Vector2):
	if (grounded):
		player_state = PlayerState.STILL
		return
	if (_check_falling()):
		return

func _process_sliding(delta: float, input_vector: Vector2):
	if (_check_jump(true)):
		return
	if (!_check_crouch(PlayerState.SLIDING)):
		var walking: bool = !input_vector.is_zero_approx()
		if (walking):
			player_state = PlayerState.WALKING
			return
		else:
			player_state = PlayerState.STILL
			return
	if (velocity.is_zero_approx()):
		player_state = PlayerState.CROUCHING
		return
		
	_apply_friction(delta, SLIDE_FRICTION)


func _process_sneak(_delta: float, input_vector: Vector2):
	if (_check_falling()):
		return
	var walking: bool = !input_vector.is_zero_approx()
	if (!_check_crouch(PlayerState.SNEAKING)):
		if (walking):
			player_state = PlayerState.WALKING
		else:
			player_state = PlayerState.STILL
		return
	if (!walking):
		player_state = PlayerState.CROUCHING
		return
	var direction = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	if direction:
		velocity.x = (direction * CROUCH_SPEED).x
		velocity.z = (direction * CROUCH_SPEED).z
	

func _process_crouching(delta: float, input_vector: Vector2):
	if (_check_falling()):
		return
	if (!input_vector.is_zero_approx()):
		player_state = PlayerState.SNEAKING
		return
	if (!_check_crouch(PlayerState.CROUCHING)):
		player_state = PlayerState.STILL
		return
	if (_check_jump(true)):
		return
	_apply_friction(delta, GROUND_FRICTION)
