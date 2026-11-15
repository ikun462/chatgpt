#include "physics.hpp"
#include <algorithm>
#include <stdexcept>
#include <unordered_set>

namespace solar {
void System::set_bodies(std::vector<Body> bodies) {
    if(bodies.empty()) throw std::invalid_argument("At least one body is required");
    std::unordered_set<uint64_t> ids;
    for(const auto& b:bodies) {
        if(!ids.insert(b.id).second || !std::isfinite(b.mass) || b.mass<=0 ||
           !std::isfinite(b.radius) || b.radius<=0 || !std::isfinite(b.spin_period) ||
           b.spin_period==0 || !b.position.finite() || !b.velocity.finite())
            throw std::invalid_argument("Invalid body state");
    }
    for(size_t i=0;i<bodies.size();++i) for(size_t j=i+1;j<bodies.size();++j)
        if((bodies[i].position-bodies[j].position).norm()<=bodies[i].radius+bodies[j].radius)
            throw std::invalid_argument("Initial bodies overlap");
    next_id_=1; for(const auto& b:bodies) next_id_=std::max(next_id_,b.id+1);
    events_.clear();
    bodies_=std::move(bodies); trial_=bodies_;
    a0_.resize(bodies_.size()); a1_.resize(bodies_.size()); time_=0;
}
void System::set_mass(uint64_t id, double mass) {
    if(!std::isfinite(mass)||mass<=0) throw std::invalid_argument("Mass must be positive and finite");
    for(size_t i=0;i<bodies_.size();++i) if(bodies_[i].id==id) { bodies_[i].mass=mass;  return; }
    throw std::invalid_argument("Unknown body ID");
}
void System::reset_earth_moon() {
    // NASA NSSDCA Moon Fact Sheet: rounded physical parameters, not epoch ephemerides.
    const double me=5.9724e24, mm=7.346e22, a=384400000, e=0.0549;
    const double r=a*(1-e), v=std::sqrt(G*(me+mm)*(1+e)/(a*(1-e)));
    const double inc=5.145*PI/180;
    const Vec3 separation{r,0,0}, relative_v{0,v*std::sin(inc),-v*std::cos(inc)};
    set_bodies({
        {1,"Earth",me,6371000,86164.1,separation*(-mm/(me+mm)),relative_v*(-mm/(me+mm))},
        {2,"Moon",mm,1737400,655.720*3600,separation*(me/(me+mm)),relative_v*(me/(me+mm))}
    });
}
void System::accelerations(const std::vector<Body>& s, std::vector<Vec3>& out) const {
    out.assign(s.size(),Vec3{});
    for(size_t i=0;i<s.size();++i) for(size_t j=i+1;j<s.size();++j) {
        const Vec3 r=s[j].position-s[i].position;
        const double r2=r.dot(r), inv_r3=1.0/(r2*std::sqrt(r2));
        const Vec3 field=r*(G*inv_r3);
        out[i]+=field*s[j].mass;
        out[j]-=field*s[i].mass;
    }
}
bool System::step(double dt) {
    if(!response_) return step_impl(dt);
    // Keep event response transactional if integration fails.
    System backup=*this;
    try { return step_impl(dt); }
    catch(...) { *this=std::move(backup); throw; }
}
bool System::step_impl(double dt) {
    if(!std::isfinite(dt)||dt<=0) throw std::invalid_argument("dt must be positive and finite");
    trial_=bodies_;
    accelerations(bodies_,a0_);
    for(size_t i=0;i<bodies_.size();++i) {
        trial_[i].position=bodies_[i].position+bodies_[i].velocity*dt+a0_[i]*(0.5*dt*dt);
        trial_[i].velocity=bodies_[i].velocity+a0_[i]*(0.5*dt);
    }
    double earliest=2;
    size_t first=0,second=0;
    for(size_t i=0;i<bodies_.size();++i) for(size_t j=i+1;j<bodies_.size();++j) {
        const Vec3 start=bodies_[j].position-bodies_[i].position;
        const Vec3 delta=trial_[j].position-trial_[i].position-start;
        const double radius=bodies_[i].radius+bodies_[j].radius;
        const double a=delta.dot(delta), b=start.dot(delta), c=start.dot(start)-radius*radius;
        double fraction=2;
        if(c<=0) fraction=0;
        else if(a>0 && b<0 && b*b-a*c>=0)
            fraction=c/(-b+std::sqrt(b*b-a*c));
        if(fraction>=0 && fraction<=1 && fraction<earliest) {
            earliest=fraction; first=i; second=j;
        }
    }
    if(earliest<=1) {
        if(!response_) return false;
        // Contact time is exact along this Verlet drift chord, not the curved orbit.
        for(size_t i=0;i<bodies_.size();++i) {
            bodies_[i].position+=(trial_[i].position-bodies_[i].position)*earliest;
            bodies_[i].velocity+=a0_[i]*(dt*earliest);
        }
        time_+=dt*earliest;
        resolve(first,second);
        const double remaining=dt*(1-earliest);
        if(remaining>dt*1e-12) return step_impl(remaining);
        return true;
    }
    accelerations(trial_,a1_);
    for(size_t i=0;i<bodies_.size();++i) {
        trial_[i].velocity+=a1_[i]*(0.5*dt);
        if(!trial_[i].position.finite()||!trial_[i].velocity.finite())
            throw std::runtime_error("Non-finite integration state");
    }
    bodies_.swap(trial_); time_+=dt;
    return true;
}
Diagnostics System::diagnostics() const {
    Diagnostics d; double mass=0;
    for(const auto& b:bodies_) {
        d.energy+=0.5*b.mass*b.velocity.dot(b.velocity);
        d.momentum+=b.velocity*b.mass;
        d.angular_momentum+=b.position.cross(b.velocity*b.mass)+b.spin_angular_momentum;
        d.center_of_mass+=b.position*b.mass; mass+=b.mass;
    }
    for(size_t i=0;i<bodies_.size();++i) for(size_t j=i+1;j<bodies_.size();++j)
        d.energy-=G*bodies_[i].mass*bodies_[j].mass/(bodies_[j].position-bodies_[i].position).norm();
    if(mass>0) d.center_of_mass=d.center_of_mass/mass;
    return d;
}
}
