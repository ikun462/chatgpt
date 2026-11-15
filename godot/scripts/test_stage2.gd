extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim = ClassDB.instantiate("SolarSimulation")
	sim.load_scenario(0,1000.0,100)
	sim.set_fixed_step(1.0)
	for i in range(1200):
		sim.advance(0.1,1.0,8.0)
	assert(sim.get_collision_events().size() == 1)
	assert(sim.get_bodies().size() == 100)
	assert(sim.get_diagnostics().time > 100)
	var scene = load("res://scenes/stage2.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.sim.load_scenario(0,1000.0,100)
	scene.sim.set_fixed_step(1.0)
	for i in range(1200):
		scene.sim.advance(0.1,1.0,8.0)
	scene._physics_process(0.0)
	scene._process(0.01)
	assert(scene.registry.size() == 100)
	assert(scene.selector.item_count == 100)
	scene._focus(99)
	scene._load_experiment(3)
	assert(scene.bodies.size() == 10)
	scene._process(0.01)
	assert(scene.registry.size() == 10)
	scene.queue_free()
	print("STAGE2_EXTENSION_AND_UI_PASSED")
	quit()
