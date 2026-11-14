#pragma once
#include "physics.hpp"
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_float64_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>

class SolarSimulation : public godot::RefCounted {
    GDCLASS(SolarSimulation, godot::RefCounted)
    solar::System system;
    solar::Diagnostics baseline;
    double accumulator=0, fixed_step=60, last_ms=0, actual_rate=0;
    int last_steps=0;
    bool limited=false, contact=false;
    godot::String error;
protected:
    static void _bind_methods();
public:
    SolarSimulation();
    void reset();
    void advance(double real_seconds, double time_scale, double budget_ms);
    void set_fixed_step(double seconds);
    bool set_mass(int64_t id, double mass);
    godot::Array predict_orbits(int samples, double sample_seconds) const;
    godot::Dictionary get_diagnostics() const;
    godot::Array get_bodies() const;
    godot::PackedVector3Array get_render_positions(int origin_index, double meters_per_unit) const;
};
