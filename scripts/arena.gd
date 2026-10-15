extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const BotScript = preload("res://scripts/bot.gd")
const TouchScript = preload("res://scripts/touch_controls.gd")
const MAGAZINE := 30
const ROUND_SECONDS := 120.0
const SPAWNS := [Vector3(-12, 0.1, -12), Vector3(12, 0.1, -12), Vector3(-12, 0.1, 7), Vector3(12, 0.1, 7), Vector3(0, 0.1, -15)]

var player: CharacterBody3D
var bots: Array[CharacterBody3D] = []
var active := false
var paused := false
var touch_mode := OS.has_feature("mobile")
var firing := false
var health := 100
var ammo := MAGAZINE
var reloading := false
var reload_left := 0.0
var cooldown := 0.0
var remaining := ROUND_SECONDS
var kills := 0
var wave := 1
var spawn_pending := false
var spawn_left := 0.0
var quality := "Smooth"
var sun: DirectionalLight3D
var ui: Control
var menu: PanelContainer
var menu_title: Label
var menu_detail: Label
var start_button: Button
var hud_status: Label
var hud_ammo: Label
var hud_round: Label
var hud_message: Label
var health_bar: ProgressBar
var touch: Control
var flash: ColorRect
var crosshair: Label
var quality_button: Button
var hit_left := 0.0
var message_left := 0.0
var shot_count := 0
var settings := ConfigFile.new()
var smoke := false
var test_failures := 0
var gun_audio: AudioStreamPlayer

func _ready() -> void:
	smoke = "--smoke-test" in OS.get_cmdline_user_args()
	Engine.max_fps = 60
	_build_world()
	player = PlayerScript.new()
	player.game = self
	add_child(player)
	player.position = Vector3(0, 0.1, 12)
	_build_ui()
	_build_audio()
	if not smoke and settings.load("user://settings.cfg") == OK:
		quality = str(settings.get_value("graphics", "preset", "Smooth"))
	apply_quality(quality)
	show_menu("NEON OUTPOST", "TRAINING SECTOR 07\nClear hostile drones. Survive two minutes.")
	if smoke:
		_run_smoke.call_deferred()
	elif "--capture-preview" in OS.get_cmdline_user_args():
		_capture_preview.call_deferred()

func _build_audio() -> void:
	gun_audio = AudioStreamPlayer.new()
	gun_audio.volume_db = -17
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var samples := PackedByteArray()
	samples.resize(2205 * 2)
	var noise := RandomNumberGenerator.new()
	noise.seed = 7
	for i in range(2205):
		var t := float(i) / 22050.0
		var envelope := exp(-t * 65.0)
		var sample := (noise.randf_range(-1, 1) * 0.7 + sin(t * 180.0 * TAU) * 0.3) * envelope
		samples.encode_s16(i * 2, int(sample * 27000))
	sound.data = samples
	gun_audio.stream = sound
	add_child(gun_audio)

func _capture_preview() -> void:
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/menu.png")
	touch_mode = true
	start_round()
	for bot in bots:
		bot.set_physics_process(false)
	for i in range(8):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://build/arena.png")
	get_tree().quit()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material

func _box(where: Vector3, dimensions: Vector3, color: Color, solid := true) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.position = where
	mesh.material_override = _material(color)
	add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collider.shape = shape
		body.add_child(collider)
		mesh.add_child(body)
	return mesh

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color("101d2e")
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color("9cb6ce")
	sky.ambient_light_energy = 0.65
	environment.environment = sky
	add_child(environment)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_color = Color("ffdfb3")
	sun.light_energy = 1.15
	sun.directional_shadow_max_distance = 45
	add_child(sun)
	_box(Vector3(0, -0.3, 0), Vector3(40, 0.6, 40), Color("243744"))
	for z in [-20, 20]:
		_box(Vector3(0, 2, z), Vector3(41, 4, 1), Color("304855"))
		_box(Vector3(0, 3.9, z - sign(z) * 0.53), Vector3(40, 0.12, 0.08), Color("57d4bb"), false)
	for x in [-20, 20]:
		_box(Vector3(x, 2, 0), Vector3(1, 4, 40), Color("304855"))
	for x in range(-16, 20, 4):
		_box(Vector3(x, 0.012, 0), Vector3(0.035, 0.015, 39), Color("34505c"), false)
	for z in range(-16, 20, 4):
		_box(Vector3(0, 0.015, z), Vector3(39, 0.015, 0.035), Color("34505c"), false)
	for point in [Vector3(-6, 0, -5), Vector3(6, 0, -5), Vector3(-8, 0, 4), Vector3(8, 0, 4)]:
		_box(point + Vector3(0, 0.9, 0), Vector3(3, 1.8, 3), Color("4e666d"))
		_box(point + Vector3(0, 1.72, 0), Vector3(3.04, 0.12, 3.04), Color("d2a462"), false)
	_box(Vector3(0, 1.3, -3), Vector3(3, 2.6, 4), Color("405961"))
	_box(Vector3(0, 2.62, -3), Vector3(3.05, 0.08, 4.05), Color("5ae0bc"), false)
	for x in [-17, 17]:
		for z in [-17, 17]:
			_box(Vector3(x, 4, z), Vector3(1.1, 8, 1.1), Color("22313f"))
			_box(Vector3(x, 7.8, z), Vector3(1.2, 0.3, 1.2), Color("7de6d1"), false)

func _label(text: String, font_size: int, color := Color("e1eee9")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170, 48)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	button.focus_mode = Control.FOCUS_NONE
	return button

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var theme := Theme.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("19353e")
	style.border_color = Color("4d8d83")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	theme.set_stylebox("normal", "Button", style)
	var hover := style.duplicate()
	hover.bg_color = Color("2a645f")
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", hover)
	ui.theme = theme
	var brand := _label("P / P    NEON OUTPOST", 22, Color("69e8c5"))
	brand.position = Vector2(32, 22)
	ui.add_child(brand)
	hud_status = _label("", 18)
	hud_status.position = Vector2(32, 60)
	ui.add_child(hud_status)
	health_bar = ProgressBar.new()
	health_bar.position = Vector2(32, 92)
	health_bar.size = Vector2(220, 8)
	health_bar.show_percentage = false
	var health_background := StyleBoxFlat.new()
	health_background.bg_color = Color("19353e")
	var health_fill := StyleBoxFlat.new()
	health_fill.bg_color = Color("61e9bf")
	health_bar.add_theme_stylebox_override("background", health_background)
	health_bar.add_theme_stylebox_override("fill", health_fill)
	ui.add_child(health_bar)
	hud_round = _label("", 19)
	hud_round.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hud_round.position = Vector2(-340, 24)
	hud_round.size.x = 190
	ui.add_child(hud_round)
	var pause_button := _button("II  PAUSE", pause_round)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-140, 19)
	pause_button.custom_minimum_size.x = 116
	pause_button.size.x = 116
	ui.add_child(pause_button)
	hud_ammo = _label("", 32)
	hud_ammo.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hud_ammo.position = Vector2(-250, -77)
	ui.add_child(hud_ammo)
	var weapon_name := _label("AR-01  /  AUTO RIFLE", 14, Color("83aaa9"))
	weapon_name.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_name.position = Vector2(-250, -36)
	ui.add_child(weapon_name)
	crosshair = _label("+", 34, Color("80f6d2"))
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-11, -24)
	ui.add_child(crosshair)
	hud_message = _label("", 20, Color("ffcf8c"))
	hud_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hud_message.position = Vector2(-160, 45)
	hud_message.size.x = 320
	hud_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(hud_message)
	touch = TouchScript.new()
	touch.game = self
	ui.add_child(touch)
	var reload_button := _button("RELOAD", reload_weapon)
	reload_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	reload_button.position = Vector2(-360, -151)
	reload_button.custom_minimum_size.x = 125
	reload_button.size.x = 125
	ui.add_child(reload_button)
	var aim_button := _button("AIM", func(): player.aiming = not player.aiming)
	aim_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	aim_button.position = Vector2(-195, -260)
	aim_button.custom_minimum_size.x = 125
	aim_button.size.x = 125
	ui.add_child(aim_button)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(0.9, 0.15, 0.08, 0)
	ui.add_child(flash)
	menu = PanelContainer.new()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.035, 0.075, 0.11, 0.97)
	panel.border_color = Color("3b746d")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(12)
	panel.content_margin_left = 38
	panel.content_margin_right = 38
	panel.content_margin_top = 28
	panel.content_margin_bottom = 28
	menu.add_theme_stylebox_override("panel", panel)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-305, -230)
	menu.custom_minimum_size = Vector2(610, 460)
	ui.add_child(menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	menu.add_child(column)
	column.add_child(_label("P / P     •     ANDROID TRAINING PROTOTYPE", 15, Color("62dfbc")))
	menu_title = _label("NEON OUTPOST", 38)
	column.add_child(menu_title)
	menu_detail = _label("", 20, Color("a6baba"))
	column.add_child(menu_detail)
	column.add_child(_label("TOUCH   Left stick: move · Right side: look\nFire: hold · Aim: toggle · Reload: tap\nPC   WASD · Mouse · Left click · R · Esc", 17, Color("789798")))
	quality_button = _button("", toggle_quality)
	column.add_child(quality_button)
	start_button = _button("DEPLOY  →", start_or_resume)
	column.add_child(start_button)
	column.add_child(_label("OFFLINE  /  ORIGINAL ARENA  /  NO ACCOUNT REQUIRED", 13, Color("648583")))

func start_or_resume() -> void:
	if paused:
		paused = false
		active = true
		menu.hide()
	else:
		start_round()
	if not touch_mode and not smoke:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func start_round() -> void:
	for bot in bots:
		if is_instance_valid(bot):
			bot.queue_free()
	bots.clear()
	health = 100
	ammo = MAGAZINE
	kills = 0
	wave = 1
	remaining = ROUND_SECONDS
	reloading = false
	reload_left = 0
	cooldown = 0
	spawn_pending = false
	firing = false
	paused = false
	player.position = Vector3(0, 0.1, 12)
	player.rotation = Vector3.ZERO
	player.pitch = 0
	player.camera.rotation = Vector3.ZERO
	player.aiming = false
	player.velocity = Vector3.ZERO
	active = true
	menu.hide()
	touch.release_all()
	spawn_wave()
	message("SECTOR 07  /  ENGAGE")

func spawn_wave() -> void:
	spawn_pending = false
	for i in range(mini(2 + wave, 5)):
		var bot := BotScript.new()
		bot.game = self
		bot.position = SPAWNS[i]
		add_child(bot)
		bots.append(bot)

func show_menu(title: String, detail: String) -> void:
	active = false
	firing = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	touch.release_all()
	menu_title.text = title
	menu_detail.text = detail
	menu.show()

func pause_round() -> void:
	if not active:
		return
	paused = true
	start_button.text = "RESUME  →"
	show_menu("TAKE A BREATHER", "Training paused. Your sector is waiting.")

func finish_round(won: bool) -> void:
	paused = false
	start_button.text = "DEPLOY AGAIN  →"
	show_menu("SECTOR SECURED" if won else "SIGNAL LOST", "%d eliminations  /  Wave %d\n%s" % [kills, wave, "Training complete. Well played." if won else "Regroup and try another approach."])

func message(text: String) -> void:
	hud_message.text = text
	message_left = 2.0

func apply_quality(preset: String) -> void:
	quality = "High" if preset == "High" else "Smooth"
	var high := quality == "High"
	sun.shadow_enabled = high
	get_viewport().scaling_3d_scale = 1.0 if high else 0.75
	get_viewport().msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
	quality_button.text = "GRAPHICS:  %s   ↔" % quality.to_upper()
	if not smoke:
		settings.set_value("graphics", "preset", quality)
		settings.save("user://settings.cfg")

func toggle_quality() -> void:
	apply_quality("High" if quality == "Smooth" else "Smooth")

func _process(delta: float) -> void:
	flash.color.a = move_toward(flash.color.a, 0, delta * 0.8)
	hit_left = maxf(hit_left - delta, 0)
	crosshair.text = "×" if hit_left > 0 else "+"
	crosshair.modulate = Color("ffcf8c") if hit_left > 0 else Color.WHITE
	if active:
		message_left -= delta
		if message_left <= 0:
			hud_message.text = ""
	hud_status.text = "%03d  HEALTH    /    %s" % [health, quality.to_upper()]
	health_bar.value = health
	hud_ammo.text = "RELOADING…" if reloading else "%02d  /  ∞" % ammo
	hud_round.text = "%02d:%02d   /   %02d KILLS" % [int(remaining) / 60, int(remaining) % 60, kills]
	crosshair.visible = active
	touch.queue_redraw()

func _physics_process(delta: float) -> void:
	if not active:
		return
	remaining = maxf(remaining - delta, 0)
	if remaining <= 0:
		finish_round(true)
		return
	cooldown = maxf(cooldown - delta, 0)
	if reloading:
		reload_left -= delta
		if reload_left <= 0:
			reloading = false
			ammo = MAGAZINE
	if spawn_pending:
		spawn_left -= delta
		if spawn_left <= 0:
			wave += 1
			spawn_wave()
	if firing:
		shoot()

func shoot() -> bool:
	if not active or reloading or cooldown > 0:
		return false
	if ammo <= 0:
		reload_weapon()
		return false
	ammo -= 1
	shot_count += 1
	if not smoke:
		gun_audio.play()
	cooldown = 0.115
	player.recoil = 0.075
	var origin: Vector3 = player.camera.global_position
	var end: Vector3 = origin - player.camera.global_basis.z * 70
	var query := PhysicsRayQueryParameters3D.create(origin, end, 1 | 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		end = hit.position
		if hit.collider is OutpostBot:
			hit.collider.take_hit(34)
			hit_left = 0.13
	tracer(origin + player.camera.global_basis * Vector3(0.22, -0.16, -0.8), end, Color("9ff7d2"))
	return true

func tracer(origin: Vector3, end: Vector3, color: Color) -> void:
	var length := origin.distance_to(end)
	if length < 0.01:
		return
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.018, 0.018, length)
	line.mesh = mesh
	line.material_override = _material(color)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(line)
	line.global_position = (origin + end) * 0.5
	line.look_at(end, Vector3.UP if absf((end - origin).normalized().y) < 0.99 else Vector3.RIGHT)
	get_tree().create_timer(0.045).timeout.connect(line.queue_free)

func reload_weapon() -> void:
	if not active or reloading or ammo == MAGAZINE:
		return
	reloading = true
	reload_left = 1.5
	message("RELOADING  /  1.5 SEC")

func bot_eliminated(bot: CharacterBody3D) -> void:
	bots.erase(bot)
	kills += 1
	if bots.is_empty():
		health = mini(health + 25, 100)
		spawn_pending = true
		spawn_left = 2.5
		message("WAVE CLEAR  /  +25 HEALTH")

func take_damage(amount: int) -> void:
	if not active:
		return
	health = maxi(health - amount, 0)
	flash.color.a = 0.22
	if health <= 0:
		finish_round(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			if active:
				pause_round()
			elif paused:
				start_or_resume()
		if event.physical_keycode == KEY_R:
			reload_weapon()
	if not active:
		return
	if touch_mode:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.look(event.relative)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			firing = event.pressed
		if event.button_index == MOUSE_BUTTON_RIGHT:
			player.aiming = event.pressed

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(touch) and active:
		pause_round()

func _check(condition: bool, description: String) -> void:
	if not condition:
		test_failures += 1
		push_error("FAIL: " + description)
		return
	print("PASS: " + description)

func _run_smoke() -> void:
	await get_tree().physics_frame
	start_round()
	_check(active and bots.size() == 3, "deployment creates player and three bots")
	# Freeze bots so raycast and wall-occlusion checks are deterministic.
	for bot in bots:
		bot.set_physics_process(false)
	player.set_physics_process(false)
	var target := bots[0]
	target.global_position = Vector3(0, 0.1, 7)
	await get_tree().physics_frame
	target.attack_timer = 0
	target._physics_process(0.01)
	_check(health == 92, "bot with line of sight damages player")
	_check(shoot() and ammo == 29 and target.health == 66, "camera ray damages visible target and consumes ammo")
	_check(not shoot() and ammo == 29, "fire rate blocks immediate duplicate shot")
	for i in range(2):
		cooldown = 0
		shoot()
	_check(kills == 1 and bots.size() == 2, "three rifle hits eliminate a bot exactly once")
	var blocked := bots[0]
	blocked.global_position = Vector3(0, 0.1, -8)
	await get_tree().physics_frame
	blocked.attack_timer = 0
	blocked._physics_process(0.01)
	_check(health == 92, "cover also blocks bot attacks")
	cooldown = 0
	shoot()
	_check(blocked.health == 100, "solid central cover blocks shots")
	reload_weapon()
	_check(reloading and not shoot(), "reload prevents firing")
	reload_left = 0.001
	_physics_process(0.01)
	_check(ammo == MAGAZINE and not reloading, "timed reload restores magazine")
	pause_round()
	var saved_time := remaining
	_physics_process(1)
	_check(not active and paused and remaining == saved_time and not shoot(), "pause freezes round and blocks shots")
	start_or_resume()
	_check(active and not paused, "resume restores active round")
	touch_mode = true
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = Vector2(145, 585)
	down.pressed = true
	touch._input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(205, 585)
	touch._input(drag)
	_check(player.move_input.x > 0.9, "touch joystick produces movement")
	var fire := InputEventScreenTouch.new()
	fire.index = 1
	fire.position = Vector2(1150, 575)
	fire.pressed = true
	touch._input(fire)
	_check(firing and touch.move_finger == 0, "second touch fires while joystick stays active")
	var look_touch := InputEventScreenTouch.new()
	look_touch.index = 2
	look_touch.position = Vector2(900, 300)
	look_touch.pressed = true
	touch._input(look_touch)
	var look_drag := InputEventScreenDrag.new()
	look_drag.index = 2
	look_drag.relative = Vector2(20, 10)
	touch._input(look_drag)
	_check(player.rotation.y < 0 and player.pitch < 0, "third touch independently rotates aim")
	touch.release_all()
	_check(not firing and player.move_input == Vector2.ZERO and touch.look_finger == -1, "touch reset prevents stuck movement and firing")
	apply_quality("High")
	_check(sun.shadow_enabled and get_viewport().msaa_3d == Viewport.MSAA_2X, "High enables shadows and antialiasing")
	apply_quality("Smooth")
	_check(not sun.shadow_enabled and get_viewport().scaling_3d_scale == 0.75, "Smooth reduces rendering cost")
	for bot in bots.duplicate():
		bot.take_hit(100)
	_check(spawn_pending and health == 100, "cleared wave restores health and schedules reinforcements")
	_physics_process(2.6)
	_check(wave == 2 and bots.size() == 4, "next wave spawns after intermission")
	take_damage(100)
	_check(not active and health == 0 and menu.visible, "lethal damage ends round")
	start_round()
	_check(health == 100 and ammo == 30 and kills == 0 and bots.size() == 3, "restart resets gameplay state")
	remaining = 0.001
	_physics_process(0.01)
	_check(not active and menu_title.text == "SECTOR SECURED", "surviving timer completes training")
	print("SMOKE TEST COMPLETE: %d failures" % test_failures)
	get_tree().quit(0 if test_failures == 0 else 1)
