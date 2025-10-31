class_name Player
extends CharacterBody3D

## ⚙️ MOVEMENT PROPERTIES ⚙️
@export var SPEED : float = 5.0
@export var SPRINT_SPEED: float = 8.0 
@export var JUMP_VELOCITY : float = 4.5

@onready var camera_3d: Camera3D = $Camera3D

## 📸 CAMERA PROPERTIES 📸
@export_group("Camera Settings")
@export var MOUSE_SENSITIVITY : float = 0.5
@export var CAMERA_DISTANCE : float = 4.0
@export var MIN_CAMERA_DISTANCE : float = 1.0
@export var MAX_CAMERA_DISTANCE : float = 10.0
@export var ZOOM_SPEED : float = 2.0
@export var CAMERA_HEIGHT : float = 2.0
@export var MIN_PITCH_DEG : float = -89.9
@export var MAX_PITCH_DEG : float = 50.0

@export var TURN_SPEED : float = 10.0
@onready var SPIDER_MODEL: Node3D = $RootNode

## 🟢 ONREADY VARIABLES 🟢
@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var MODEL_YAW_OFFSET: float = 0.0

## 🌍 CONSTANTS
var GRAVITY = ProjectSettings.get_setting("physics/3d/default_gravity")

## 🔄 INTERNAL STATE 🔄
var _rotation_input : float = 0.0
var _tilt_input : float = 0.0
# Camera rotation in degrees (pitch, yaw)
var _camera_pitch_deg: float = 0.0
var _camera_yaw_deg: float = 0.0

# --- INPUT HANDLING ---
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_rotation_input = -event.relative.x 
		_tilt_input = -event.relative.y
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			CAMERA_DISTANCE -= ZOOM_SPEED * 0.1
			CAMERA_DISTANCE = clampf(CAMERA_DISTANCE, MIN_CAMERA_DISTANCE, MAX_CAMERA_DISTANCE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			CAMERA_DISTANCE += ZOOM_SPEED * 0.1
			CAMERA_DISTANCE = clampf(CAMERA_DISTANCE, MIN_CAMERA_DISTANCE, MAX_CAMERA_DISTANCE)
		
	if event.is_action_pressed("exit"):
		get_tree().quit()

# --- CAMERA & PLAYER ROTATION LOGIC ---
func _update_camera() -> void:
	if camera_3d == null:
		return
	
	# Update camera rotation from mouse input
	_camera_yaw_deg += _rotation_input * MOUSE_SENSITIVITY
	_camera_pitch_deg += _tilt_input * MOUSE_SENSITIVITY
	
	# Wrap yaw and clamp pitch
	_camera_yaw_deg = wrapf(_camera_yaw_deg, 0.0, 360.0)
	_camera_pitch_deg = clampf(_camera_pitch_deg, MIN_PITCH_DEG, MAX_PITCH_DEG)
	
	# Do not rotate the player body; only move the camera around it
	
	# Calculate camera position behind the player
	var pitch_rad = deg_to_rad(_camera_pitch_deg)
	var yaw_rad = deg_to_rad(_camera_yaw_deg)
	
	# Camera pivot point (around player's head/upper body)
	var pivot_point = global_position + Vector3(0, CAMERA_HEIGHT, 0)
	
	# Calculate offset direction (spherical coordinates)
	var offset = Vector3(
		sin(yaw_rad) * cos(pitch_rad) * CAMERA_DISTANCE,
		sin(pitch_rad) * CAMERA_DISTANCE,
		cos(yaw_rad) * cos(pitch_rad) * CAMERA_DISTANCE
	)
	
	# Position camera relative to pivot point
	camera_3d.global_position = pivot_point + offset
	
	# Make camera look at pivot point
	camera_3d.look_at(pivot_point, Vector3.UP)

	# consume inputs for next frame
	_rotation_input = 0.0
	_tilt_input = 0.0

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Initialize camera rotation
	if camera_3d:
		# Start with a reasonable third-person angle (looking slightly down)
		_camera_pitch_deg = -20.0
		_camera_yaw_deg = rad_to_deg(rotation.y)
		# Update camera position on first frame
		_update_camera()

func _physics_process(delta):
	# Update camera movement based on mouse movement
	_update_camera()
	
	# gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Jump.
	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		animation_player.play("SpiderArmature|Spider_Jump")

	# --- Get the input direction --- (use down/up order so up is forward)
	var input_dir = Input.get_vector("move_left", "move_right", "move_down", "move_up")
	var is_moving = input_dir.length_squared() > 0
	var is_sprinting = Input.is_action_pressed("move_sprint") and is_moving
	animation_player.speed_scale = 2 if is_sprinting else 1
	var current_speed = SPRINT_SPEED if is_sprinting else SPEED

	# Transform input into world-space **relative to the camera** (typical TPS)
	var direction: Vector3 = Vector3.ZERO
	if camera_3d:
		var cam_basis = camera_3d.global_transform.basis
		var cam_forward = -cam_basis.z
		var cam_right = cam_basis.x
		direction = (cam_right * input_dir.x + cam_forward * input_dir.y)
		if direction.length_squared() > 0:
			direction = direction.normalized()
	else:
		# fallback to player relative movement if camera missing
		direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# debug prints (comment out when not needed)
	# print("input_dir:", input_dir, " direction:", direction)

	if direction.length_squared() > 0.000001:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed

		# Smoothly rotate the visual model to face movement direction
		if SPIDER_MODEL:
			var flat_dir = Vector3(direction.x, 0.0, direction.z).normalized()
			var target_yaw = atan2(flat_dir.x, flat_dir.z) + MODEL_YAW_OFFSET
			var current_yaw = SPIDER_MODEL.rotation.y
			var new_yaw = lerp_angle(current_yaw, target_yaw, TURN_SPEED * delta)
			SPIDER_MODEL.rotation.y = new_yaw

		# play a moving animation if you have one (optional)
		# animation_player.play("SpiderArmature|Spider_Run")
	else:
		animation_player.play("SpiderArmature|Spider_Idle")
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	

	move_and_slide()
