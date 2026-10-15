extends Control

var game: Node3D
var move_finger := -1
var look_finger := -1
var fire_finger := -1
var stick_center := Vector2.ZERO
var stick_offset := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _draw() -> void:
	if not game.active or not game.touch_mode:
		return
	var center := Vector2(145, size.y - 135)
	if move_finger >= 0:
		center = stick_center
	draw_circle(center, 68, Color(0.4, 0.9, 0.83, 0.08))
	draw_arc(center, 68, 0, TAU, 64, Color(0.5, 0.9, 0.85, 0.35), 2, true)
	draw_circle(center + stick_offset, 25, Color(0.5, 0.9, 0.85, 0.35))
	draw_circle(Vector2(size.x - 130, size.y - 145), 51, Color(0.9, 0.65, 0.4, 0.15))
	draw_arc(Vector2(size.x - 130, size.y - 145), 51, 0, TAU, 64, Color("ffd49a"), 2, true)
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 149, size.y - 139), "FIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("ffd49a"))

func release_all() -> void:
	move_finger = -1
	look_finger = -1
	fire_finger = -1
	stick_offset = Vector2.ZERO
	game.player.move_input = Vector2.ZERO
	game.firing = false
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not game.active or not game.touch_mode:
		return
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if not event.pressed:
			if event.index == move_finger:
				move_finger = -1
				stick_offset = Vector2.ZERO
				game.player.move_input = Vector2.ZERO
			if event.index == look_finger:
				look_finger = -1
			if event.index == fire_finger:
				fire_finger = -1
				game.firing = false
		elif p.distance_to(Vector2(size.x - 130, size.y - 145)) < 64:
			fire_finger = event.index
			game.firing = true
		elif p.x < size.x * 0.42 and p.y > size.y * 0.4 and move_finger < 0:
			move_finger = event.index
			stick_center = p
		elif p.x > size.x * 0.42 and p.y > 100 and look_finger < 0:
			look_finger = event.index
		queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == move_finger:
			stick_offset = (event.position - stick_center).limit_length(60)
			game.player.move_input = stick_offset / 60.0
			queue_redraw()
		elif event.index == look_finger:
			game.player.look(event.relative)
