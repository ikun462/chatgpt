extends Node3D

const METERS_PER_UNIT := 1.0e6
const BASE_MASSES := [5.9724e24, 7.346e22]
const RADII := [6.371, 1.7374]
const INK := Color("e7efff")
const MUTED := Color("8d9eb8")
const ACCENT := Color("72e4d0")
const BLUE := Color("6cafff")
const SUN_DIRECTION := Vector3(-0.35, 0.22, 0.91)

var sim: RefCounted
var camera: Camera3D
var earth: MeshInstance3D
var earth_axis: Node3D
var moon: MeshInstance3D
var clouds: MeshInstance3D
var atmosphere: MeshInstance3D
var environment: Environment
var earth_material: ShaderMaterial
var orbit_root: Node3D
var history_root: MeshInstance3D
var predicted_paths: Array = []
var history: Array[Vector3] = []
var bodies: Array = []
var diagnostic: Dictionary = {}
var selected := 0
var system_view := false
var paused := false
var time_scale := 3600.0
var visual_scale := 1.0
var physics_budget := 3.0
var show_orbits := true
var quality := 1
var ui_elapsed := 0.0
var last_trail_time := -1.0
var measured_time := 0.0
var measured_wall := 0.0
var effective_rate := 0.0
var status_label: Label
var info_label: Label
var stats_label: Label
var time_label: Label
var rate_label: Label
var pause_button: Button
var mass_sliders: Array[HSlider] = []
var mass_labels: Array[Label] = []
var preview_timer: Timer
var notice := "初始状态：理想化近地点 · 非实时星历"
var orbit_check: CheckBox
var smoke_frames := 0

func _ready() -> void:
	if not ClassDB.class_exists("SolarSimulation"):
		var missing := Label.new()
		missing.text = "C++ 物理扩展未加载。请先执行 Windows 构建脚本，检查 godot/bin 中的 DLL。"
		missing.position = Vector2(40, 50)
		add_child(missing)
		push_error(missing.text)
		return
	sim = ClassDB.instantiate("SolarSimulation")
	bodies = sim.get_bodies()
	diagnostic = sim.get_diagnostics()
	_build_world()
	_build_ui()
	preview_timer = Timer.new()
	preview_timer.one_shot = true
	preview_timer.wait_time = 0.3
	preview_timer.timeout.connect(_refresh_prediction)
	add_child(preview_timer)
	_refresh_prediction()
	_focus(0)
	if "--smoke-system" in OS.get_cmdline_user_args(): _focus_system()
	if "--smoke-moon" in OS.get_cmdline_user_args(): _focus(1)
	_update_stats()

func _sphere(radius: float, material: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 128
	mesh.rings = 64
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	parent.add_child(node)
	return node

func _build_world() -> void:
	var world := WorldEnvironment.new()
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var star_material := ShaderMaterial.new()
	star_material.shader = load("res://shaders/stars.gdshader")
	sky.sky_material = star_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("293751")
	environment.ambient_light_energy = 0.12
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	environment.glow_intensity = 0.45
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 1.8
	# Physical radii are not inflated for lighting; shadow eclipses are not in stage 1.
	sun.shadow_enabled = false
	add_child(sun)
	sun.look_at(-SUN_DIRECTION, Vector3.UP)
	earth_axis = Node3D.new()
	add_child(earth_axis)
	earth_axis.rotation.z = deg_to_rad(-23.44)
	earth_material = ShaderMaterial.new()
	earth_material.shader = load("res://shaders/earth.gdshader")
	earth_material.set_shader_parameter("day_map", load("res://assets/earth_day.jpg"))
	earth_material.set_shader_parameter("night_map", load("res://assets/earth_night.jpg"))
	earth_material.set_shader_parameter("clouds_map", load("res://assets/earth_clouds.png"))
	earth_material.set_shader_parameter("sun_direction", SUN_DIRECTION)
	earth = _sphere(RADII[0], earth_material, earth_axis)
	var cloud_material := ShaderMaterial.new()
	cloud_material.shader = load("res://shaders/clouds.gdshader")
	cloud_material.set_shader_parameter("cloud_map", load("res://assets/earth_clouds.png"))
	clouds = _sphere(RADII[0] * 1.004, cloud_material, earth_axis)
	var atmo_material := ShaderMaterial.new()
	atmo_material.shader = load("res://shaders/atmosphere.gdshader")
	atmo_material.set_shader_parameter("sun_direction", SUN_DIRECTION)
	atmosphere = _sphere(RADII[0] * 1.025, atmo_material, earth_axis)
	var moon_material := StandardMaterial3D.new()
	moon_material.albedo_texture = load("res://assets/moon.jpg")
	moon_material.roughness = 1.0
	moon = _sphere(RADII[1], moon_material, self)
	orbit_root = Node3D.new()
	add_child(orbit_root)
	history_root = MeshInstance3D.new()
	add_child(history_root)
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/camera.gd"))
	add_child(camera)
	camera.current = true
	_set_quality(1)

func _panel_style(color: Color, border := Color("263447")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style

func _button_style(color: Color, border := Color("263447")) -> StyleBoxFlat:
	var style := _panel_style(color,border)
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style

func _label(text: String, size: int, color := INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 43
	b.pressed.connect(action)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

func _section(box: VBoxContainer, text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	box.add_child(spacer)
	box.add_child(_label(text, 16, MUTED))

func _panel(parent: Control, left: float, top: float, width: float) -> VBoxContainer:
	var p := PanelContainer.new()
	p.position = Vector2(left,top)
	p.custom_minimum_size.x = width
	p.add_theme_stylebox_override("panel", _panel_style(Color(0.025,0.043,0.075,0.94)))
	parent.add_child(p)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	return box

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var theme := Theme.new()
	theme.default_font = load("res://assets/NotoSansSC.otf")
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", INK)
	theme.set_color("font_color", "Button", INK)
	theme.set_stylebox("normal", "Button", _button_style(Color("101e30")))
	theme.set_stylebox("hover", "Button", _button_style(Color("20364a"), ACCENT))
	theme.set_stylebox("pressed", "Button", _button_style(Color("25514e"), ACCENT))
	theme.set_stylebox("focus", "Button", _button_style(Color(0,0,0,0), ACCENT))
	root.theme = theme
	var heading := _label("SOLAR SANDBOX", 30)
	heading.position = Vector2(32,24)
	root.add_child(heading)
	var subheading := _label("太阳系物理沙盒  /  01 地月实验室", 17, MUTED)
	subheading.position = Vector2(34,68)
	root.add_child(subheading)
	var badge := _label("●  C++ 双精度引力  ·  Velocity Verlet", 17, ACCENT)
	badge.position = Vector2(1370,38)
	root.add_child(badge)
	var left := _panel(root, 28, 120, 325)
	left.add_child(_label("观察与实验", 24))
	left.add_child(_label("两颗有质量天体 · 相互引力", 16, MUTED))
	var focus_row := HBoxContainer.new()
	left.add_child(focus_row)
	for i in range(2):
		var b := _button("地球" if i == 0 else "月球", _focus.bind(i))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		focus_row.add_child(b)
	left.add_child(_button("查看完整地月系统", _focus_system))
	_section(left, "物理参数 / 即时生效")
	for i in range(2):
		var mass_label := _label(("地球" if i == 0 else "月球") + "质量  × 1.00", 18)
		left.add_child(mass_label)
		mass_labels.append(mass_label)
		var slider := HSlider.new()
		slider.min_value = 0.1
		slider.max_value = 10.0
		slider.step = 0.05
		slider.value = 1.0
		slider.custom_minimum_size = Vector2(270,28)
		slider.value_changed.connect(_mass_changed.bind(i))
		left.add_child(slider)
		mass_sliders.append(slider)
	var mass_note := _label("0.1–10 倍原始质量；保留当前位置、速度。\n修改会重置守恒误差基线。", 14, MUTED)
	left.add_child(mass_note)
	_section(left, "显示")
	var scale_mode := OptionButton.new()
	scale_mode.add_item("真实尺寸与距离")
	scale_mode.add_item("视觉放大 ×4（不改变物理）")
	scale_mode.item_selected.connect(_scale_changed)
	left.add_child(scale_mode)
	orbit_check = CheckBox.new()
	orbit_check.text = "远景显示预测轨道与实际轨迹"
	orbit_check.button_pressed = true
	orbit_check.toggled.connect(func(value: bool): show_orbits = value)
	left.add_child(orbit_check)
	var quality_menu := OptionButton.new()
	for text in ["低画质 · 无云层 / 无辉光", "标准画质 · 4K / 2× MSAA", "高画质 · 4K / 4× MSAA"]:
		quality_menu.add_item(text)
	quality_menu.select(1)
	quality_menu.item_selected.connect(_set_quality)
	left.add_child(quality_menu)
	_section(left, "积分精度（固定步长）")
	var step_menu := OptionButton.new()
	for text in ["精细 · 10 秒", "标准 · 60 秒", "快速 · 300 秒"]: step_menu.add_item(text)
	step_menu.select(1)
	step_menu.item_selected.connect(func(index: int): sim.set_fixed_step([10.0,60.0,300.0][index]))
	left.add_child(step_menu)
	left.add_child(_button("重置地月系统", _reset))
	var right := _panel(root, 1565, 120, 325)
	right.add_child(_label("天体档案", 24))
	info_label = _label("", 18)
	right.add_child(info_label)
	_section(right, "运行监测")
	stats_label = _label("", 16, ACCENT)
	right.add_child(stats_label)
	_section(right, "当前模型")
	right.add_child(_label("地月双向引力；太阳仅照明。\n大气为薄壳近似；云层视觉漂移。\n物理接触时暂停，尚无碰撞响应。", 14, MUTED))
	var help := _label("右键拖动：旋转  ·  滚轮：缩放  ·  右键 + WASD / QE：平移\n空格：暂停 / 继续  ·  F：聚焦  ·  Shift：加速  ·  Esc：释放鼠标", 17, MUTED)
	help.position = Vector2(405,885)
	root.add_child(help)
	var bottom := _panel(root, 385, 975, 1140)
	bottom.get_parent().custom_minimum_size.y = 80
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	bottom.add_child(row)
	pause_button = _button("暂停", _toggle_pause)
	pause_button.custom_minimum_size.x = 100
	row.add_child(pause_button)
	var speed_menu := OptionButton.new()
	for text in ["实时 ×1", "×60 · 1 分钟/秒", "×600 · 10 分钟/秒", "×3600 · 1 小时/秒", "×21600 · 6 小时/秒", "×86400 · 1 天/秒", "×864000 · 10 天/秒"]:
		speed_menu.add_item(text)
	speed_menu.select(3)
	speed_menu.item_selected.connect(func(index: int): time_scale = [1.0,60.0,600.0,3600.0,21600.0,86400.0,864000.0][index])
	row.add_child(speed_menu)
	time_label = _label("", 19)
	row.add_child(time_label)
	rate_label = _label("", 16, ACCENT)
	row.add_child(rate_label)
	status_label = _label("", 16, MUTED)
	status_label.position = Vector2(405,941)
	root.add_child(status_label)

func _physics_process(delta: float) -> void:
	if sim == null: return
	if not paused:
		sim.advance(delta, time_scale, physics_budget)
	bodies = sim.get_bodies()
	diagnostic = sim.get_diagnostics()
	if diagnostic.contact or not str(diagnostic.error).is_empty():
		paused = true
		pause_button.text = "已停止"
		notice = "检测到物理接触，已停止积分（碰撞响应将在第三阶段实现）。" if diagnostic.contact else "积分错误：" + str(diagnostic.error)
	if diagnostic.time - last_trail_time >= 1800.0 or last_trail_time < 0:
		var p: PackedFloat64Array = bodies[1].position_m
		history.append(Vector3(p[0]/METERS_PER_UNIT,p[1]/METERS_PER_UNIT,p[2]/METERS_PER_UNIT))
		if history.size() > 2048: history.pop_front()
		last_trail_time = diagnostic.time
		_rebuild_history()

func _process(delta: float) -> void:
	if sim == null: return
	var origin_index := -1 if system_view else selected
	var positions: PackedVector3Array = sim.get_render_positions(origin_index, METERS_PER_UNIT)
	earth_axis.position = positions[0]
	moon.position = positions[1]
	var t: float = diagnostic.get("time", 0.0)
	earth.rotation.y = fmod(t * TAU / 86164.1, TAU) + 1.1
	clouds.rotation.y = earth.rotation.y + fmod(t * TAU / (86400.0*12.0), TAU)
	earth_material.set_shader_parameter("cloud_offset", (earth.rotation.y-clouds.rotation.y)/TAU)
	moon.rotation.y = fmod(t * TAU / (655.720*3600.0), TAU)
	var origin := Vector3.ZERO
	if origin_index >= 0:
		var p: PackedFloat64Array = bodies[origin_index].position_m
		origin = Vector3(p[0]/METERS_PER_UNIT,p[1]/METERS_PER_UNIT,p[2]/METERS_PER_UNIT)
	orbit_root.position = -origin
	history_root.position = -origin
	orbit_root.visible = show_orbits and (system_view or camera.distance > 50.0*visual_scale)
	history_root.visible = orbit_root.visible
	ui_elapsed += delta
	measured_wall += delta
	if ui_elapsed >= 0.25:
		effective_rate = (t - measured_time)/maxf(measured_wall,0.001)
		measured_time = t
		measured_wall = 0.0
		ui_elapsed = 0.0
		_update_stats()
	# Automated render smoke test captures the real viewport, not a mock-up.
	if "--render-smoke" in OS.get_cmdline_user_args():
		smoke_frames += 1
		if smoke_frames == 8:
			paused = true
		if smoke_frames == 12:
			get_viewport().get_texture().get_image().save_png("user://render_smoke.png")
			print("RENDER_SMOKE_OK ", OS.get_user_data_dir())
			get_tree().quit()

func _focus(index: int) -> void:
	selected = index
	system_view = false
	camera.focus_point(Vector3.ZERO, (23.0 if index == 0 else 7.0)*visual_scale, RADII[index]*visual_scale*1.08)
	if info_label != null: _update_stats()

func _focus_system() -> void:
	system_view = true
	camera.yaw = 0.15
	camera.pitch = 0.72
	camera.focus_point(Vector3.ZERO, 1150.0, 10.0)

func _scale_changed(index: int) -> void:
	visual_scale = 1.0 if index == 0 else 4.0
	earth_axis.scale = Vector3.ONE * visual_scale
	moon.scale = Vector3.ONE * visual_scale
	if not system_view: _focus(selected)

func _set_quality(index: int) -> void:
	quality = index
	if clouds == null: return
	clouds.visible = index > 0
	atmosphere.visible = true
	earth_material.set_shader_parameter("cloud_shadows", index > 0)
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][index]
	environment.glow_enabled = index > 0 and RenderingServer.get_current_rendering_method() != "gl_compatibility"

func _mass_changed(multiplier: float, index: int) -> void:
	if sim.set_mass(index+1, BASE_MASSES[index]*multiplier):
		mass_labels[index].text = ("地球" if index == 0 else "月球") + "质量  × %.2f" % multiplier
		history.clear()
		last_trail_time = -1.0
		notice = "质量已修改；轨道由新引力重新演化。守恒误差从本次修改后统计。"
		preview_timer.start()

func _refresh_prediction() -> void:
	predicted_paths = sim.predict_orbits(721,3600.0)
	for child in orbit_root.get_children():
		orbit_root.remove_child(child)
		child.queue_free()
	for index in range(predicted_paths.size()):
		var line := MeshInstance3D.new()
		line.mesh = _line_mesh(predicted_paths[index], Color("295969") if index == 0 else Color("366a93"))
		orbit_root.add_child(line)

func _line_mesh(points: PackedVector3Array, color: Color) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	if points.size() < 2: return mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, material)
	for point in points: mesh.surface_add_vertex(point)
	mesh.surface_end()
	return mesh

func _rebuild_history() -> void:
	history_root.mesh = _line_mesh(PackedVector3Array(history), ACCENT)

func _toggle_pause() -> void:
	if diagnostic.get("contact",false): return
	paused = not paused
	pause_button.text = "继续" if paused else "暂停"

func _reset() -> void:
	sim.reset()
	bodies = sim.get_bodies()
	diagnostic = sim.get_diagnostics()
	history.clear()
	last_trail_time = -1
	measured_time = 0
	measured_wall = 0
	paused = false
	pause_button.text = "暂停"
	for i in range(2):
		mass_sliders[i].set_value_no_signal(1.0)
		mass_labels[i].text = ("地球" if i == 0 else "月球") + "质量  × 1.00"
	notice = "已重置：理想化地月轨道，初始位置为近地点。"
	_refresh_prediction()

func _update_stats() -> void:
	var body: Dictionary = bodies[selected]
	var v: PackedFloat64Array = body.velocity_m_s
	var velocity := sqrt(v[0]*v[0]+v[1]*v[1]+v[2]*v[2])
	var ep: PackedFloat64Array = bodies[0].position_m
	var mp: PackedFloat64Array = bodies[1].position_m
	var separation := sqrt(pow(mp[0]-ep[0],2)+pow(mp[1]-ep[1],2)+pow(mp[2]-ep[2],2))
	info_label.text = "%s\n\n质量       %s kg\n物理半径   %.1f km\n平均密度   %.0f kg/m³\n惯性系速度 %.2f m/s\n\n地月距离   %.0f km" % ["地球 · EARTH" if selected == 0 else "月球 · MOON",_scientific(body.mass),body.radius/1000.0,body.density,velocity,separation/1000.0]
	stats_label.text = "帧率           %d FPS\n物理耗时       %.3f ms\n固定步长       %.0f s\n能量相对误差   %s\n角动量相对误差 %s\n动量残差       %s kg·m/s" % [Engine.get_frames_per_second(),diagnostic.physics_ms,diagnostic.fixed_step,_scientific(diagnostic.relative_energy_error),_scientific(diagnostic.relative_angular_error),_scientific(diagnostic.momentum_residual)]
	time_label.text = "模拟时间  %.3f 天" % (diagnostic.time/86400.0)
	rate_label.text = "实际 ×%.0f" % effective_rate
	status_label.text = "预算已触发：实际倍率受限，固定步长不变。" if diagnostic.limited else notice
	status_label.add_theme_color_override("font_color", Color("ffbe78") if diagnostic.limited else MUTED)

func _unhandled_key_input(event: InputEvent) -> void:
	if sim == null: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _toggle_pause()
		if event.keycode == KEY_F: _focus(selected)

func _scientific(value: float) -> String:
	if value == 0.0: return "0.0000"
	var exponent := int(floor(log(absf(value))/log(10.0)))
	return "%.4f" % (value/pow(10.0,exponent)) + "e" + ("+" if exponent >= 0 else "") + str(exponent)
