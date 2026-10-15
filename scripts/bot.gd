class_name OutpostBot
extends CharacterBody3D

var game: Node3D
var health := 100
var attack_timer := 1.0
var body_mesh: MeshInstance3D
var phase := 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	body_mesh = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.7
	body_mesh.mesh = mesh
	body_mesh.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d9664e")
	body_mesh.material_override = material
	add_child(body_mesh)
	var visor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.57, 0.13, 0.3)
	visor.mesh = box
	visor.position = Vector3(0.0, 1.39, -0.30)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("ffcf7e")
	visor.material_override = glow
	add_child(visor)
	phase = position.x

func _physics_process(delta: float) -> void:
	if not game.active or health <= 0:
		return
	var offset: Vector3 = game.player.global_position - global_position
	offset.y = 0.0
	var distance := offset.length()
	if distance > 0.1:
		look_at(global_position + offset)
	phase += delta
	var direction := offset.normalized()
	if distance < 7.0:
		direction = Vector3(-direction.z, 0, direction.x) * sin(phase)
	velocity.x = direction.x * 2.0
	velocity.z = direction.z * 2.0
	velocity.y -= 24.0 * delta
	move_and_slide()
	attack_timer -= delta
	if attack_timer <= 0.0 and distance < 23.0:
		attack_timer = 1.6
		var origin := global_position + Vector3.UP * 1.35
		var target: Vector3 = game.player.global_position + Vector3.UP * 1.2
		var query := PhysicsRayQueryParameters3D.create(origin, target, 1 | 2)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit and hit.collider == game.player:
			game.tracer(origin, target, Color("ff8d6a"))
			game.take_damage(8)

func take_hit(damage: int) -> void:
	if health <= 0:
		return
	health -= damage
	if health <= 0:
		game.bot_eliminated(self)
		queue_free()
