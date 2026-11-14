extends Camera3D
# Camera coordinates are render-local; C++ subtracts the physical origin in double.
var distance := 23.0
var yaw := 0.7
var pitch := 0.23
var center := Vector3.ZERO
var pan := Vector3.ZERO
var minimum_distance := 7.0
var dragging := false

func _ready() -> void:
	near = 0.01
	far = 12000.0
	fov = 45.0
	update_pose()

func focus_point(point: Vector3, view_distance: float, minimum: float) -> void:
	center = point
	pan = Vector3.ZERO
	distance = view_distance
	minimum_distance = minimum
	update_pose()

func update_pose() -> void:
	position = center + pan + Vector3(sin(yaw)*cos(pitch), sin(pitch), cos(yaw)*cos(pitch))*distance
	look_at(center + pan, Vector3.UP)
	near = maxf(0.005, distance * 0.0001)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			dragging = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if dragging else Input.MOUSE_MODE_VISIBLE
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(minimum_distance, distance * 0.88)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(5000.0, distance / 0.88)
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch + event.relative.y * 0.004,-1.48,1.48)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		dragging = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	# Keyboard motion requires right-drag, so editing UI fields never moves the camera.
	if dragging:
		var move := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): move.z -= 1
		if Input.is_physical_key_pressed(KEY_S): move.z += 1
		if Input.is_physical_key_pressed(KEY_A): move.x -= 1
		if Input.is_physical_key_pressed(KEY_D): move.x += 1
		if Input.is_physical_key_pressed(KEY_Q): move.y -= 1
		if Input.is_physical_key_pressed(KEY_E): move.y += 1
		var speed := distance * (1.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 0.3)
		pan += global_basis * move * delta * speed
	update_pose()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		dragging = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
