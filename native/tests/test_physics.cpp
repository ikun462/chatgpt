#include "physics.hpp"
#include <iostream>
#include <stdexcept>
#include <iomanip>
using namespace solar;
void require(bool ok,const char* message) { if(!ok) throw std::runtime_error(message); }
void orbit_conservation() {
    System s; s.reset_earth_moon();
    auto initial=s.diagnostics();
    const double period=2*PI*std::sqrt(std::pow(384400000.0,3)/(G*(5.9724e24+7.346e22)));
    double max_e=0,max_p=0,max_l=0,min_r=1e99,max_r=0;
    for(int k=0;k<int(20*period/300);++k) {
        require(s.step(300),"unexpected contact");
        auto d=s.diagnostics();
        max_e=std::max(max_e,std::abs((d.energy-initial.energy)/initial.energy));
        max_p=std::max(max_p,(d.momentum-initial.momentum).norm()/(7.346e22*1100));
        max_l=std::max(max_l,(d.angular_momentum-initial.angular_momentum).norm()/initial.angular_momentum.norm());
        double r=(s.bodies()[1].position-s.bodies()[0].position).norm();
        min_r=std::min(min_r,r);max_r=std::max(max_r,r);
    }
    std::cout<<"20 orbits dt=300s: max relative energy="<<max_e<<", momentum="<<max_p<<", angular momentum="<<max_l<<", radius=["<<min_r<<","<<max_r<<"] m\n";
    require(max_e<1e-6,"energy drift");require(max_p<1e-11,"momentum drift");require(max_l<1e-11,"angular momentum drift");
    require(min_r>384400000*(1-0.0549)*0.99999 && max_r<384400000*(1+0.0549)*1.00001,"unstable orbit");
    require(s.diagnostics().center_of_mass.norm()<1,"barycenter drift");
}
Vec3 analytic_relative(double t) {
    const double a=384400000,e=0.0549,n=std::sqrt(G*(5.9724e24+7.346e22)/std::pow(a,3));
    const double M=n*t;double E=M;
    for(int i=0;i<20;++i)E-=(E-e*std::sin(E)-M)/(1-e*std::cos(E));
    double z=-a*std::sqrt(1-e*e)*std::sin(E), inc=5.145*PI/180;
    return {a*(std::cos(E)-e),-z*std::sin(inc),z*std::cos(inc)};
}
double error(double dt) {
    System s;s.reset_earth_moon();const double duration=864000;
    for(int i=0;i<int(duration/dt);++i)require(s.step(dt),"convergence contact");
    return (s.bodies()[1].position-s.bodies()[0].position-analytic_relative(duration)).norm();
}
void convergence() {
    const double a=error(7200),b=error(3600),c=error(1800);
    std::cout<<"Kepler reference position errors (m), dt=7200/3600/1800: "<<a<<", "<<b<<", "<<c<<"; ratios "<<a/b<<", "<<b/c<<"\n";
    require(a/b>3.8&&a/b<4.2&&b/c>3.8&&b/c<4.2,"not second-order convergence");
}
void generic_nbody() {
    System s;s.set_bodies({{11,"A",1e20,100,1,{-1e7,0,0},{0,0,20}},
        {12,"B",2e20,100,1,{2e7,0,0},{0,0,-10}},
        {13,"C",3e20,100,1,{0,3e7,0},{10,0,0}},
        {14,"D",4e20,100,1,{0,0,4e7},{-7.5,0,0}}});
    auto d0=s.diagnostics();
    for(int i=0;i<10000;++i)require(s.step(10),"N-body contact");
    auto d=s.diagnostics();
    require((d.momentum-d0.momentum).norm()<1e10,"N-body momentum");
    require(std::abs((d.energy-d0.energy)/d0.energy)<1e-6,"N-body energy");
    std::cout<<"4 massive bodies: conservation passed\n";
}
void guards() {
    System s;s.reset_earth_moon();bool rejected=false;
    try{s.step(0);}catch(const std::invalid_argument&){rejected=true;}require(rejected,"zero step accepted");
    rejected=false;try{s.set_bodies({{1,"A",-1,1,1,{},{}}});}catch(const std::invalid_argument&){rejected=true;}require(rejected,"negative mass accepted");
    require(s.bodies().size()==2,"failed validation modified state");
    s.set_bodies({{1,"A",1,1,1,{-10,0,0},{100,0,0}},{2,"B",1,1,1,{10,0,0},{-100,0,0}}});
    require(!s.step(1),"swept collision missed");require(s.time()==0 && s.bodies()[0].position.x==-10,"contact must roll back");
    std::cout<<"Input validation and swept-contact rollback passed\n";
}
void mass_edit() {
    System a,b;a.reset_earth_moon();b.reset_earth_moon();
    auto original=a.bodies()[0];a.set_mass(1,original.mass*2);
    require((a.bodies()[0].velocity-original.velocity).norm()==0,"mass edit changes velocity");
    require((a.bodies()[0].position-original.position).norm()==0,"mass edit changes position");
    const auto baseline=a.diagnostics();
    for(int i=0;i<100;++i){require(a.step(60),"mass-edited contact");require(b.step(60),"reference contact");}
    const double change=(a.bodies()[1].position-b.bodies()[1].position).norm();
    require(change>1000,"mass edit does not affect orbit");
    require(std::abs((a.diagnostics().energy-baseline.energy)/baseline.energy)<1e-6,"edited orbit energy");
    std::cout<<"Mass edit trajectory difference after 6000s: "<<change<<" m\n";
}
int main(){try{std::cout<<std::setprecision(12);orbit_conservation();convergence();generic_nbody();guards();mass_edit();std::cout<<"ALL PHYSICS TESTS PASSED\n";}catch(const std::exception& e){std::cerr<<"FAIL: "<<e.what()<<'\n';return 1;}}
