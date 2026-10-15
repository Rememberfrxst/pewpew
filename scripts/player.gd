class_name OutpostPlayer
extends CharacterBody3D

var camera: Camera3D
var game: Node3D
var pitch := 0.0
var move_input := Vector2.ZERO
var aiming := false
var weapon: Node3D
var recoil := 0.0
var walk_time := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	camera = Camera3D.new()
	camera.position.y = 1.55
	camera.fov = 78.0
	camera.near = 0.06
	add_child(camera)
	camera.current = true
	weapon = Node3D.new()
	camera.add_child(weapon)
	_make_weapon()

func _make_weapon() -> void:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color("283b4b")
	steel.roughness = 0.65
	var mint := StandardMaterial3D.new()
	mint.albedo_color = Color("54efc5")
	for data in [[Vector3(0.17, 0.14, 0.52), Vector3(0.28, -0.23, -0.52), steel], [Vector3(0.07, 0.07, 0.35), Vector3(0.28, -0.21, -0.92), steel], [Vector3(0.09, 0.22, 0.12), Vector3(0.28, -0.36, -0.43), steel], [Vector3(0.18, 0.025, 0.18), Vector3(0.28, -0.15, -0.57), mint]]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = data[0]
		mesh.mesh = box
		mesh.position = data[1]
		mesh.material_override = data[2]
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		weapon.add_child(mesh)

func look(relative: Vector2) -> void:
	if not game.active:
		return
	var sensitivity := 0.0026 if not aiming else 0.0014
	rotation.y -= relative.x * sensitivity
	pitch = clampf(pitch - relative.y * sensitivity, -1.35, 1.35)
	camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
	if not game.active:
		velocity = Vector3.ZERO
		return
	var movement := move_input
	if not OS.has_feature("mobile"):
		movement += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	movement = movement.limit_length()
	var direction := global_basis * Vector3(movement.x, 0.0, movement.y)
	var speed := 3.3 if aiming else 6.0
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 28.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 28.0)
	if not is_on_floor():
		velocity.y -= 24.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	walk_time += delta * Vector2(velocity.x, velocity.z).length()
	recoil = move_toward(recoil, 0.0, delta * 0.8)
	weapon.position = Vector3(-0.18 if aiming else 0.0, sin(walk_time * 2.0) * 0.008, recoil)
	camera.fov = lerpf(camera.fov, 53.0 if aiming else 78.0, 1.0 - exp(-delta * 12.0))
