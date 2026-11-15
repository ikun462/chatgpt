#pragma once
#include <cmath>
#include <cstdint>
#include <vector>
#include <string>

namespace solar {
constexpr double G = 6.67430e-11;
constexpr double PI = 3.14159265358979323846;
struct Vec3 {
    double x=0, y=0, z=0;
    Vec3 operator+(Vec3 b) const { return {x+b.x,y+b.y,z+b.z}; }
    Vec3 operator-(Vec3 b) const { return {x-b.x,y-b.y,z-b.z}; }
    Vec3 operator*(double s) const { return {x*s,y*s,z*s}; }
    Vec3 operator/(double s) const { return *this*(1.0/s); }
    Vec3& operator+=(Vec3 b) { *this=*this+b; return *this; }
    Vec3& operator-=(Vec3 b) { *this=*this-b; return *this; }
    double dot(Vec3 b) const { return x*b.x+y*b.y+z*b.z; }
    Vec3 cross(Vec3 b) const { return {y*b.z-z*b.y,z*b.x-x*b.z,x*b.y-y*b.x}; }
    double norm() const { return std::sqrt(dot(*this)); }
    bool finite() const { return std::isfinite(x)&&std::isfinite(y)&&std::isfinite(z); }
};
struct Body {
    uint64_t id=0;
    std::string name;
    double mass=1, radius=1, spin_period=86400;
    Vec3 position, velocity;
    bool fragment=false;
    Vec3 spin_angular_momentum;
    double density() const { return mass/(4.0/3.0*PI*radius*radius*radius); }
};
struct Diagnostics {
    double energy=0;
    Vec3 momentum, angular_momentum, center_of_mass;
};
// SI units, inertial Cartesian coordinates, double precision throughout.
// Direct symmetric pair summation is deliberate for stage 1's two massive bodies.
struct CollisionEvent {
    uint64_t first, second;
    double time, relative_speed, impact_energy;
    size_t fragments;
};
class System {
    std::vector<Body> bodies_;
    std::vector<Body> trial_;
    std::vector<Vec3> a0_, a1_;
    double time_=0;
    bool response_=false;
    size_t fragment_count_=100;
    uint64_t next_id_=1;
    std::vector<CollisionEvent> events_;
    bool step_impl(double dt);
    void resolve(size_t first, size_t second);
    void accelerations(const std::vector<Body>& state, std::vector<Vec3>& out) const;
public:
    void set_bodies(std::vector<Body> bodies);
    void reset_earth_moon();
    void reset_solar_system();
    void reset_collision_demo(int scenario, double speed=1000);
    void enable_collisions(bool value) { response_=value; }
    void set_fragment_count(size_t count);
    const std::vector<CollisionEvent>& events() const { return events_; }
    void set_mass(uint64_t id, double mass);
    bool step(double dt); // transactional; false on physical contact, state is unchanged
    const std::vector<Body>& bodies() const { return bodies_; }
    double time() const { return time_; }
    Diagnostics diagnostics() const;
};
}
