shader_type sky;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
void sky(){
    vec3 d=normalize(EYEDIR),p=d*420.0,cell=floor(p);
    float h=hash(cell),s=pow(max(0.0,1.0-length(fract(p)-0.5)*2.0),12.0);
    float star=step(0.994,h)*s;
    COLOR=vec3(0.0015,0.003,0.008)+vec3(0.65,0.78,1.0)*star*2.0;
}
