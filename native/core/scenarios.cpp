#include "physics.hpp"
#include <stdexcept>
namespace solar {
void System::reset_collision_demo(int scenario,double speed) {
    if(!std::isfinite(speed)||speed<=0||speed>1e6) throw std::invalid_argument("Invalid impact speed");
    if(scenario==0) {
        set_bodies({{11,"Asteroid A",1e12,500,86400,{-5000,0,0},{speed/2,0,0}},
                    {12,"Asteroid B",1e12,500,86400,{5000,0,0},{-speed/2,0,0}}});
    } else if(scenario==1) {
        set_bodies({{2,"Moon",7.346e22,1737400,2360592,{},{ }},
                    {11,"Asteroid",1e18,50000,86400,{5e6,0,0},{-speed,0,0}}});
    } else {
        set_bodies({{1,"Earth",5.9724e24,6371000,86164,{},{ }},
                    {2,"Moon",7.346e22,1737400,2360592,{5e7,0,0},{-speed,0,0}}});
    }
    response_=true;
}
void System::reset_solar_system() {
    // Rounded NASA planetary fact-sheet values. Synthetic circular coplanar
    // initial conditions at simulation t=0, not an epoch-specific ephemeris.
    std::vector<Body> state{{10,"Sun",1.9885e30,695700000,2160000,{},{}}};
    const char* names[]={"Mercury","Venus","Earth","Mars","Jupiter","Saturn","Uranus","Neptune"};
    const double masses[]={0.33010e24,4.8673e24,5.9724e24,0.64169e24,1898.13e24,568.32e24,86.811e24,102.409e24};
    const double radii[]={2439700,6051800,6371000,3389500,69911000,58232000,25362000,24622000};
    const double distances[]={57.91e9,108.21e9,149.60e9,227.92e9,778.57e9,1433.53e9,2872.46e9,4495.06e9};
    for(size_t k=0;k<8;++k) {
        const double angle=k*0.7, r=distances[k], v=std::sqrt(G*(state[0].mass+masses[k])/r);
        state.push_back({k==2?1:20+k,names[k],masses[k],radii[k],86400,
            {r*std::cos(angle),0,r*std::sin(angle)},{-v*std::sin(angle),0,v*std::cos(angle)}});
    }
    const Body earth=state[3];
    state.push_back({2,"Moon",7.346e22,1737400,2360592,
        earth.position+Vec3{384400000,0,0},earth.velocity+Vec3{0,0,1022}});
    Vec3 center,velocity; double mass=0;
    for(const auto& b:state){mass+=b.mass;center+=b.position*b.mass;velocity+=b.velocity*b.mass;}
    for(auto& b:state){b.position-=center/mass;b.velocity-=velocity/mass;}
    set_bodies(std::move(state)); response_=true;
}
}
