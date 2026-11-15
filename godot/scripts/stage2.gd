extends "res://scripts/main.gd"

var registry: Dictionary = {}
var selector: OptionButton
var events_label: Label
var speed_input: SpinBox
var fragments_input: OptionButton
var scenario := 0
var units := 1000.0
var selected_id := 11
var event_count := 0

func _ready() -> void:
	super._ready()
	_load_experiment(0)
	if "--stage2-smoke" in OS.get_cmdline_user_args():
		for i in range(120): sim.advance(0.1,1.0,8.0)
		_physics_process(0.0)
		paused = true
		camera.focus_point(Vector3.ZERO,40.0,0.1)

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
	root.theme = theme
	var box := _panel(root, 20, 20, 345)
	box.add_child(_label("第二阶段 · 碰撞实验", 25))
	for entry in [["两颗小行星碰撞",0],["小行星撞击月球",1],["月球撞击地球",2],["恢复标准太阳系（近似）",3]]:
		box.add_child(_button(entry[0], _load_experiment.bind(entry[1])))
	box.add_child(_label("初始撞击速度 m/s（重新加载生效）",15))
	speed_input = SpinBox.new()
	speed_input.min_value = 0.1
	speed_input.max_value = 100000
	speed_input.value = 1000
	box.add_child(speed_input)
	fragments_input = OptionButton.new()
	for text in ["100 碎片","500 碎片","1000 碎片（实验）"]:
		fragments_input.add_item(text)
	box.add_child(fragments_input)
	box.add_child(_button("应用参数 / 重置当前实验", func(): _load_experiment(scenario)))
	selector = OptionButton.new()
	selector.item_selected.connect(func(index: int):
		selected_id = selector.get_item_id(index)
		_focus(index))
	box.add_child(selector)
	pause_button = _button("暂停", _toggle_pause)
	box.add_child(pause_button)
	var rates := OptionButton.new()
	for text in ["×1","×10","×100","×1000","×86400"]:
		rates.add_item(text)
	rates.item_selected.connect(func(index: int): time_scale = [1.0,10.0,100.0,1000.0,86400.0][index])
	box.add_child(rates)
	box.add_child(_button("返回第一阶段地月实验室", func(): get_tree().change_scene_to_file("res://scenes/main.tscn")))
	info_label = _label("",16)
	box.add_child(info_label)
	stats_label = _label("",16,ACCENT)
	box.add_child(stats_label)
	events_label = _label("",15)
	events_label.position = Vector2(390,30)
	root.add_child(events_label)
	status_label = _label("宏观破碎近似 · 全部碎片具有独立双精度状态",17)
	status_label.position = Vector2(390,1000)
	root.add_child(status_label)

func _load_experiment(index: int) -> void:
	if index != scenario and index < 3:
		speed_input.value = [1000.0,8000.0,25000.0][index]
	scenario = index
	units = 1000.0 if index == 0 else METERS_PER_UNIT
	var speed: float = speed_input.value
	sim.load_scenario(index,speed,[100,500,1000][fragments_input.selected])
	sim.set_fixed_step(0.1 if index == 0 else 1.0 if index < 3 else 60.0)
	time_scale = 1.0 if index == 0 else 100.0 if index < 3 else 3600.0
	paused = false
	event_count = 0
	pause_button.text = "暂停"
	bodies = sim.get_bodies()
	diagnostic = sim.get_diagnostics()
	selected_id = bodies[0].id
	selected = 0
	_sync_registry()
	_focus(0)

func _sync_registry() -> void:
	var alive: Dictionary = {}
	for b in bodies:
		alive[b.id] = true
		if not registry.has(b.id):
			var node: Node3D
			if b.id == 1:
				node = earth_axis
			elif b.id == 2:
				node = moon
			else:
				var material := StandardMaterial3D.new()
				material.albedo_color = Color("e2a870") if b.fragment else Color("8799ae")
				if b.id == 10:
					material.emission_enabled = true
					material.emission = Color("ffcf77")
				var mesh := SphereMesh.new()
				mesh.radius = 1.0
				mesh.height = 2.0
				mesh.radial_segments = 12 if b.fragment else 48
				mesh.rings = 6 if b.fragment else 24
				node = MeshInstance3D.new()
				node.mesh = mesh
				node.material_override = material
				add_child(node)
			registry[b.id] = node
	for id in registry.keys():
		if not alive.has(id):
			var node: Node3D = registry[id]
			if node != earth_axis and node != moon:
				node.queue_free()
			registry.erase(id)
	earth_axis.visible = alive.has(1)
	moon.visible = alive.has(2)
	if not alive.has(selected_id):
		selected_id = bodies[0].id
	selector.clear()
	for i in range(bodies.size()):
		var b: Dictionary = bodies[i]
		selector.add_item("%s #%d" % [b.name,b.id],b.id)
		if b.id == selected_id:
			selected = i
			selector.select(i)

func _physics_process(delta: float) -> void:
	if sim == null: return
	if not paused: sim.advance(delta,time_scale,physics_budget)
	bodies = sim.get_bodies()
	diagnostic = sim.get_diagnostics()
	if not str(diagnostic.error).is_empty():
		paused = true
		status_label.text = str(diagnostic.error)
	var events: Array = sim.get_collision_events()
	if events.size() != event_count or selector.item_count != bodies.size():
		_sync_registry()
		if events.size() > event_count:
			camera.focus_point(Vector3.ZERO,40.0 if scenario == 0 else camera.distance,0.1)
		event_count = events.size()
	if not events.is_empty():
		var e: Dictionary = events.back()
		events_label.text = "碰撞事件 %d  |  %.3f s\n相对速度 %.2f m/s  |  质心系撞击能量 %s J\n生成碎片 %d · 碰撞后继续积分" % [events.size(),e.time,e.speed,_scientific(e.energy),e.fragments]

func _process(delta: float) -> void:
	if sim == null or bodies.is_empty(): return
	var positions: PackedVector3Array = sim.get_render_positions(selected,units)
	for i in range(bodies.size()):
		var b: Dictionary = bodies[i]
		if not registry.has(b.id): continue
		var node: Node3D = registry[b.id]
		node.position = positions[i]
		var base := RADII[0] if b.id == 1 else RADII[1] if b.id == 2 else 1.0
		node.scale = Vector3.ONE * (b.radius / units / base)
	orbit_root.visible = false
	history_root.visible = false
	ui_elapsed += delta
	if ui_elapsed > 0.25:
		ui_elapsed = 0
		_update_stats()
	if "--stage2-smoke" in OS.get_cmdline_user_args():
		smoke_frames += 1
		if smoke_frames == 30:
			get_viewport().get_texture().get_image().save_png("user://stage2-smoke.png")
			print("STAGE2_RENDER_OK")
			get_tree().quit()

func _focus(index: int) -> void:
	if bodies.is_empty(): return
	selected = clampi(index,0,bodies.size()-1)
	selected_id = bodies[selected].id
	var radius: float = bodies[selected].radius / units
	camera.focus_point(Vector3.ZERO,maxf(radius*8,15.0 if scenario==0 else 20.0),maxf(radius*1.1,0.01))
	camera.far = 12000.0

func _refresh_prediction() -> void:
	pass

func _update_stats() -> void:
	if bodies.is_empty() or stats_label == null: return
	var b: Dictionary = bodies[selected]
	info_label.text = "%s #%d\n质量 %s kg\n半径 %.3f km\n密度 %.1f kg/m³" % [b.name,b.id,_scientific(b.mass),b.radius/1000.0,b.density]
	stats_label.text = "%d 个独立物理对象\n%d FPS · %.3f ms / 物理回调\n模拟时间 %.2f s\n动量残差 %s kg·m/s" % [bodies.size(),Engine.get_frames_per_second(),diagnostic.physics_ms,diagnostic.time,_scientific(diagnostic.momentum_residual)]
