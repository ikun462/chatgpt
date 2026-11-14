shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D day_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D night_map : source_color, filter_linear_mipmap;
uniform sampler2D clouds_map : filter_linear_mipmap;
uniform vec3 sun_direction = vec3(0.8,0.2,0.6);
uniform float cloud_offset = 0.0;
uniform bool cloud_shadows = true;
varying vec3 world_normal;
void vertex() { world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); }
void fragment() {
    vec3 day = texture(day_map, UV).rgb;
    float ocean = smoothstep(0.01, 0.08, day.b - max(day.r, day.g * 0.92));
    float clouds = texture(clouds_map, vec2(UV.x + cloud_offset,UV.y)).r;
    ALBEDO = day * (cloud_shadows ? (1.0 - 0.18*clouds) : 1.0);
    ROUGHNESS = mix(0.85,0.22,ocean);
    SPECULAR = mix(0.22,0.65,ocean);
    float daylight = dot(normalize(world_normal),normalize(sun_direction));
    vec3 night = texture(night_map,UV).rgb;
    // Suppress ocean/background from NASA's night composite; lights only on night hemisphere.
    float lights = smoothstep(0.12,0.65,max(night.r,max(night.g,night.b)));
    EMISSION = vec3(1.0,0.67,0.30) * lights * (1.0-smoothstep(-0.15,0.12,daylight)) * 1.8;
}
