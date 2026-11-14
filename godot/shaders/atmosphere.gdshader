shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
uniform vec3 sun_direction = vec3(0.8,0.2,0.6);
varying vec3 world_normal;
void vertex(){world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
    // Artistic thin-shell / Fresnel approximation; not multi-scattering radiative transfer.
    float rim=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),3.5);
    float sun=dot(normalize(world_normal),normalize(sun_direction));
    vec3 tint=mix(vec3(1.0,0.24,0.06),vec3(0.12,0.42,1.0),smoothstep(-0.1,0.3,sun));
    ALBEDO=tint*rim*1.1;
    ALPHA=rim*smoothstep(-0.3,0.35,sun)*0.72;
}
