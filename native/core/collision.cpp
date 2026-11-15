#include "physics.hpp"
#include <algorithm>
#include <stdexcept>
namespace solar {
void System::set_fragment_count(size_t count) {
    if(count<2 || count>2000 || count%2) throw std::invalid_argument("Use an even fragment count from 2 to 2000");
    fragment_count_=count;
}
void System::resolve(size_t i,size_t j) {
    const Body a=bodies_[i], b=bodies_[j];
    const double mass=a.mass+b.mass;
    const Vec3 center=(a.position*a.mass+b.position*b.mass)/mass;
    const Vec3 velocity=(a.velocity*a.mass+b.velocity*b.mass)/mass;
    const Vec3 relative=b.velocity-a.velocity;
    const double energy=0.5*(a.mass/mass)*b.mass*relative.dot(relative);
    const Vec3 angular=(a.position-center).cross((a.velocity-velocity)*a.mass)
        +(b.position-center).cross((b.velocity-velocity)*b.mass)
        +a.spin_angular_momentum+b.spin_angular_momentum;
    Body merged=a.mass>=b.mass?a:b;
    merged.mass=mass;
    merged.radius=std::cbrt(a.radius*a.radius*a.radius+b.radius*b.radius*b.radius);
    merged.position=center; merged.velocity=velocity;
    merged.spin_angular_momentum=angular;
    std::vector<Body> products;
    // Phenomenological disruption threshold; no material-strength or hydrodynamic model.
    const double escape_squared=2*G*mass/(a.radius+b.radius);
    const bool disrupt=!a.fragment && !b.fragment &&
        relative.dot(relative)>4*escape_squared && bodies_.size()+fragment_count_<=2102;
    if(disrupt) {
        const bool retain_primary=std::max(a.mass,b.mass)>10*std::min(a.mass,b.mass);
        const double ejecta_mass=retain_primary?2*std::min(a.mass,b.mass):mass;
        const double radius=merged.radius*std::cbrt(ejecta_mass/mass/double(fragment_count_));
        const double cloud_radius=6*merged.radius*std::pow(double(fragment_count_),1.0/6.0);
        const double speed=std::sqrt(0.4*energy/ejecta_mass);
        // Antipodal deterministic directions give zero net ejecta momentum.
        for(size_t k=0;k<fragment_count_/2;++k) {
            const double y=(double(k)+0.5)/double(fragment_count_/2);
            const double azimuth=k*PI*(3-std::sqrt(5.0));
            const Vec3 direction{std::sqrt(1-y*y)*std::cos(azimuth),y,
                                 std::sqrt(1-y*y)*std::sin(azimuth)};
            for(double sign:{-1.0,1.0}) {
                Body piece=merged;
                piece.id=next_id_++; piece.name="Fragment"; piece.fragment=true;
                piece.mass=ejecta_mass/fragment_count_; piece.radius=radius;
                piece.position=center+direction*(sign*cloud_radius);
                piece.velocity=velocity+direction*(sign*speed);
                piece.spin_angular_momentum=angular*(piece.mass/mass);
                products.push_back(piece);
            }
        }
        // Do not teleport ejecta into an unrelated body. Fall back to accretion.
        bool overlap=false;
        for(size_t p=0;p<products.size();++p) {
            for(size_t q=0;q<p;++q)
                overlap |= (products[p].position-products[q].position).norm()<=2*radius;
            for(size_t k=0;k<bodies_.size();++k) if(k!=i && k!=j)
                overlap |= (products[p].position-bodies_[k].position).norm()<=radius+bodies_[k].radius;
        }
        if(overlap) products.clear();
        else if(retain_primary) {
            merged.mass=mass-ejecta_mass;
            merged.radius*=std::cbrt(merged.mass/mass);
            merged.spin_angular_momentum=angular*(merged.mass/mass);
            products.push_back(merged);
        }
    }
    if(products.empty()) products.push_back(merged);
    if(events_.size()>=4096) throw std::runtime_error("Collision event limit reached; reset scenario");
    events_.push_back({a.id,b.id,time_,relative.norm(),energy,products.size()>1?fragment_count_:0});
    bodies_.erase(bodies_.begin()+j);
    bodies_.erase(bodies_.begin()+i);
    bodies_.insert(bodies_.end(),products.begin(),products.end());
}
}
