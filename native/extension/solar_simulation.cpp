#include "solar_simulation.hpp"
#include <godot_cpp/core/class_db.hpp>
#include <chrono>
#include <algorithm>
using namespace godot;
static PackedFloat64Array pack(solar::Vec3 v) {PackedFloat64Array a;a.push_back(v.x);a.push_back(v.y);a.push_back(v.z);return a;}
void SolarSimulation::_bind_methods() {
    ClassDB::bind_method(D_METHOD("load_scenario","scenario","speed","fragments"),&SolarSimulation::load_scenario);
    ClassDB::bind_method(D_METHOD("get_collision_events"),&SolarSimulation::get_collision_events);
    ClassDB::bind_method(D_METHOD("set_mass","id","mass"),&SolarSimulation::set_mass);
    ClassDB::bind_method(D_METHOD("predict_orbits","samples","sample_seconds"),&SolarSimulation::predict_orbits);
    ClassDB::bind_method(D_METHOD("reset"),&SolarSimulation::reset);
    ClassDB::bind_method(D_METHOD("advance","real_seconds","time_scale","budget_ms"),&SolarSimulation::advance);
    ClassDB::bind_method(D_METHOD("set_fixed_step","seconds"),&SolarSimulation::set_fixed_step);
    ClassDB::bind_method(D_METHOD("get_diagnostics"),&SolarSimulation::get_diagnostics);
    ClassDB::bind_method(D_METHOD("get_bodies"),&SolarSimulation::get_bodies);
    ClassDB::bind_method(D_METHOD("get_render_positions","origin_index","meters_per_unit"),&SolarSimulation::get_render_positions);
}
SolarSimulation::SolarSimulation(){reset();}
void SolarSimulation::reset(){system.reset_earth_moon();baseline=system.diagnostics();accumulator=0;contact=false;limited=false;error="";last_steps=0;last_ms=0;actual_rate=0;}
void SolarSimulation::set_fixed_step(double seconds){
    if(std::isfinite(seconds)&&seconds>=0.01&&seconds<=600){fixed_step=seconds;accumulator=0;}
}
void SolarSimulation::advance(double real_seconds,double time_scale,double budget_ms){
    last_steps=0;last_ms=0;actual_rate=0;limited=false;
    if(contact||!error.is_empty()||!std::isfinite(real_seconds)||real_seconds<=0||
       !std::isfinite(time_scale)||time_scale<=0||!std::isfinite(budget_ms))return;
    const double wall=std::min(real_seconds,0.25),rate=std::min(time_scale,864000.0);
    limited=real_seconds>0.25||time_scale>864000;
    accumulator+=wall*rate;
    const auto start=std::chrono::steady_clock::now();
    const double budget=std::clamp(budget_ms,0.1,8.0);
    try {
        while(accumulator>=fixed_step && last_steps<4096){
            if(!system.step(fixed_step)){contact=true;accumulator=0;break;}
            accumulator-=fixed_step;++last_steps;
            last_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();
            if(last_ms>=budget)break;
        }
    } catch(const std::exception& e){error=String::utf8(e.what());accumulator=0;}
    if(accumulator>=fixed_step){limited=true;accumulator=std::fmod(accumulator,fixed_step);}
    actual_rate=last_steps*fixed_step/real_seconds;
    last_ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count();
}
Dictionary SolarSimulation::get_diagnostics() const {
    const auto d=system.diagnostics();Dictionary r;
    r["time"]=system.time();r["fixed_step"]=fixed_step;r["physics_ms"]=last_ms;
    r["steps"]=last_steps;r["actual_rate"]=actual_rate;r["limited"]=limited;r["contact"]=contact;r["error"]=error;
    r["energy_j"]=d.energy;r["relative_energy_error"]=std::abs((d.energy-baseline.energy)/std::max(std::abs(baseline.energy),1.0));
    r["relative_angular_error"]=(d.angular_momentum-baseline.angular_momentum).norm()/std::max(baseline.angular_momentum.norm(),1.0);
    r["momentum_residual"]=(d.momentum-baseline.momentum).norm();
    r["barycenter_m"]=pack(d.center_of_mass);return r;
}
Array SolarSimulation::get_bodies() const {
    Array a;
    for(const auto& b:system.bodies()){
        Dictionary d;d["id"]=int64_t(b.id);d["name"]=String::utf8(b.name.c_str());d["mass"]=b.mass;d["radius"]=b.radius;
        d["fragment"]=b.fragment;d["density"]=b.density();d["spin_period"]=b.spin_period;d["position_m"]=pack(b.position);d["velocity_m_s"]=pack(b.velocity);
        a.push_back(d);
    }return a;
}
PackedVector3Array SolarSimulation::get_render_positions(int origin_index,double meters_per_unit) const {
    PackedVector3Array a;const auto& b=system.bodies();
    if(!std::isfinite(meters_per_unit)||meters_per_unit<=0)return a;
    const solar::Vec3 origin=origin_index>=0&&size_t(origin_index)<b.size()?b[origin_index].position:solar::Vec3{};
    for(const auto& body:b){const auto p=(body.position-origin)/meters_per_unit;a.push_back(Vector3(p.x,p.y,p.z));}
    return a;
}

bool SolarSimulation::set_mass(int64_t id,double mass){
    if(!std::isfinite(mass)||mass<1e20||mass>1e27)return false;
    try{system.set_mass(uint64_t(id),mass);}catch(const std::exception&){return false;}
    // A user edit is an external intervention, not a conservation law violation.
    baseline=system.diagnostics();accumulator=0;contact=false;error="";return true;
}
Array SolarSimulation::predict_orbits(int samples,double sample_seconds) const {
    Array result;
    if(samples<2||samples>1024||!std::isfinite(sample_seconds)||sample_seconds<=0||sample_seconds>7200)return result;
    solar::System prediction=system;
    prediction.enable_collisions(false);
    std::vector<PackedVector3Array> paths(system.bodies().size());
    // The same Newtonian solver produces this preview. It never drives the live simulation.
    const int substeps=int(std::ceil(sample_seconds/600.0));
    for(int i=0;i<samples;++i){
        for(size_t j=0;j<paths.size();++j){auto p=prediction.bodies()[j].position/1e6;paths[j].push_back(Vector3(p.x,p.y,p.z));}
        for(int k=0;k<substeps;++k)if(!prediction.step(sample_seconds/substeps)){
            for(auto& path:paths)result.push_back(path);return result;
        }
    }
    for(auto& path:paths)result.push_back(path);return result;
}

void SolarSimulation::load_scenario(int scenario,double speed,int fragments) {
    try {
        solar::System candidate;
        candidate.set_fragment_count(fragments);
        if(scenario==3) candidate.reset_solar_system();
        else candidate.reset_collision_demo(scenario,speed);
        system=std::move(candidate);
        baseline=system.diagnostics(); accumulator=0; contact=false; error="";
        limited=false;last_steps=0;last_ms=0;actual_rate=0;
    } catch(const std::exception& e) { error=String::utf8(e.what()); }
}
Array SolarSimulation::get_collision_events() const {
    Array result;
    for(const auto& e:system.events()) {
        Dictionary d;d["first"]=int64_t(e.first);d["second"]=int64_t(e.second);
        d["time"]=e.time;d["speed"]=e.relative_speed;d["energy"]=e.impact_energy;
        d["fragments"]=int64_t(e.fragments);result.push_back(d);
    }
    return result;
}
