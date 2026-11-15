#include "physics.hpp"
#include <chrono>
#include <iostream>
#include <stdexcept>
#include <set>
using namespace solar;
void check(bool ok,const char* message){if(!ok)throw std::runtime_error(message);}
double mass(const System& s){double m=0;for(const auto& b:s.bodies())m+=b.mass;return m;}
void impact(size_t count) {
    System s; s.reset_collision_demo(0,1000);s.set_fragment_count(count);
    const double m=mass(s);const auto d=s.diagnostics();
    check(s.step(11),"collision step");
    check(s.events().size()==1,"event count");
    check(s.events()[0].time>8 && s.events()[0].time<10,"contact time");
    check(s.bodies().size()==count,"independent fragment count");
    check(std::abs(mass(s)/m-1)<1e-12,"fragment mass");
    check((s.diagnostics().momentum-d.momentum).norm()<m*1e-10,"fragment momentum");
    std::set<uint64_t> ids;
    for(const auto& b:s.bodies()){check(b.fragment,"fragment flag");check(ids.insert(b.id).second,"unique ID");}
    const Vec3 first=s.bodies()[0].position;
    const auto start=std::chrono::steady_clock::now();
    for(int i=0;i<100;++i)check(s.step(0.1),"continued fragment step");
    check((s.bodies()[0].position-first).norm()>0,"fragments move");
    const double ms=std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-start).count()/100;
    std::cout<<"fragments="<<count<<" full_pair_gravity_and_contacts_ms_per_step="<<ms<<"\n";
}
int main(){try{
    for(size_t count:{100,500,1000}) impact(count);
    System oblique; oblique.enable_collisions(true);
    oblique.set_bodies({{1,"A",1000,1,1,{-10,-0.25,0},{1000,0,0}},
                       {2,"B",1000,1,1,{10,0.25,0},{-1000,0,0}}});
    const auto angular=oblique.diagnostics().angular_momentum;
    check(oblique.step(0.02),"oblique impact");
    check((oblique.diagnostics().angular_momentum-angular).norm()/angular.norm()<1e-9,"spin plus orbital angular momentum");
    System merge;merge.reset_collision_demo(0,0.1);
    check(merge.step(1e6),"low-speed impact");check(merge.bodies().size()==1,"low-speed merge");
    check(merge.step(1),"merge continues");
    System repeated; repeated.enable_collisions(true);
    repeated.set_bodies({{1,"a",1,1,1,{-10,0,0},{10,0,0},true},
                         {2,"b",1e12,1,1,{0,0,0},{},true},
                         {3,"c",1,1,1,{10,0,0},{-10,0,0},true}});
    check(repeated.step(2),"extreme ratio repeated collision");
    check(repeated.bodies().size()==1,"secondary accretion");
    check(std::abs(mass(repeated)-(1e12+2))<0.01,"repeat mass");
    check(repeated.diagnostics().momentum.norm()<1e-2,"repeat momentum");
    for(int scenario:{1,2}) {
        System demo; demo.reset_collision_demo(scenario,scenario==1?8000:25000);
        const double initial_mass=mass(demo);
        const Vec3 initial_momentum=demo.diagnostics().momentum;
        for(int i=0;i<3000 && demo.events().empty();++i)check(demo.step(1),"planet impact");
        check(!demo.events().empty() && demo.events()[0].fragments==100,"planet ejecta");
        check(std::abs(mass(demo)/initial_mass-1)<1e-12,"planet mass");
        check((demo.diagnostics().momentum-initial_momentum).norm()/(initial_mass*25000)<1e-12,"planet momentum");
        check(demo.step(1),"planet continuation");
    }
    System sun;sun.reset_solar_system();check(sun.bodies().size()==10,"solar bodies");
    const double e=sun.diagnostics().energy;
    for(int i=0;i<1000;++i)check(sun.step(60),"solar step");
    check(std::abs(sun.diagnostics().energy/e-1)<1e-6,"solar stability");
    std::cout<<"STAGE2 CORE PASSED\n";
}catch(const std::exception& e){std::cerr<<e.what()<<"\n";return 1;}}
