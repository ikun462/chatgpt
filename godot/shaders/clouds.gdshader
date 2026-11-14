shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley;
uniform sampler2D cloud_map : filter_linear_mipmap_anisotropic;
void fragment(){
    float c=texture(cloud_map,UV).r;
    ALBEDO=vec3(0.95,0.97,1.0);ROUGHNESS=1.0;
    ALPHA=smoothstep(0.13,0.95,c)*0.88;
}
