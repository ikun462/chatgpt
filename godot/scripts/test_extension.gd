extends SceneTree
var failures := 0
func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	if not ClassDB.class_exists("SolarSimulation"):
		push_error("SolarSimulation not registered")
		quit(1)
		return
	var sim: RefCounted = ClassDB.instantiate("SolarSimulation")
	var initial: Array = sim.get_bodies()
	check(initial.size() == 2, "two massive bodies")
	check(initial[0].position_m is PackedFloat64Array, "physical state must retain float64")
	sim.advance(1.0/60.0,3600.0,8.0)
	check(sim.get_diagnostics().time == 60.0, "fixed-step advance")
	var before_pause: float = sim.get_diagnostics().time
	sim.advance(1.0,0.0,8.0)
	check(sim.get_diagnostics().time == before_pause,"paused state advanced")
	sim.reset()
	var reference: RefCounted = ClassDB.instantiate("SolarSimulation")
	check(sim.set_mass(1, initial[0].mass*2.0),"valid mass edit rejected")
	check(not sim.set_mass(1,-1),"negative mass accepted")
	check(not sim.set_mass(99,1e24),"unknown ID accepted")
	check(sim.get_bodies()[0].velocity_m_s == initial[0].velocity_m_s,"mass edit changed velocity")
	check(sim.get_bodies()[0].position_m == initial[0].position_m,"mass edit changed position")
	for i in range(100):
		sim.advance(0.1,600.0,8.0)
		reference.advance(0.1,600.0,8.0)
	var changed: PackedFloat64Array = sim.get_bodies()[1].position_m
	var normal: PackedFloat64Array = reference.get_bodies()[1].position_m
	check(absf(changed[0]-normal[0])>1000,"mass change did not change trajectory")
	check(sim.get_diagnostics().relative_energy_error < 1e-6,"post-edit energy baseline")
	var positions: PackedVector3Array = sim.get_render_positions(0,1e6)
	check(positions[0] == Vector3.ZERO,"floating-origin subtraction")
	sim.advance(0.25,1e9,0.1)
	check(sim.get_diagnostics().limited,"excessive rate must be limited")
	var time_before: float = sim.get_diagnostics().time
	var prediction: Array = sim.predict_orbits(20,3600.0)
	check(prediction.size()==2 and prediction[0].size()==20,"numerical prediction missing")
	check(sim.get_diagnostics().time == time_before,"preview mutated live simulation")
	sim.advance(0.25,864000.0,0.1)
	check(sim.get_diagnostics().physics_ms>=0,"budget telemetry")
	sim.set_fixed_step(10.0)
	check(sim.get_diagnostics().fixed_step==10.0,"step setting")
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child.call_deferred(main)
	await process_frame
	await process_frame
	main.paused = true
	main.mass_sliders[0].value = 2.0
	check(main.sim.get_bodies()[0].mass==initial[0].mass*2.0,"UI mass change")
	var physical_radius: float = main.sim.get_bodies()[0].radius
	main._scale_changed(1)
	check(main.sim.get_bodies()[0].radius==physical_radius,"visual scaling leaked into physics")
	main._focus(1)
	check(main.selected==1,"moon camera selection")
	var distance_before: float = main.camera.distance
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	main.camera._unhandled_input(wheel)
	check(main.camera.distance < distance_before,"camera zoom input")
	main._focus_system()
	check(main.system_view,"system camera selection")
	main._set_quality(0)
	check(not main.clouds.visible,"low quality cloud switch")
	main._reset()
	check(main.sim.get_bodies()[0].mass==initial[0].mass,"reset mass")
	main._toggle_pause()
	check(main.paused,"pause control")
	main.queue_free()
	await process_frame
	print("EXTENSION_AND_UI_TESTS ", "PASSED" if failures==0 else "FAILED", " failures=",failures)
	quit(0 if failures==0 else 1)
