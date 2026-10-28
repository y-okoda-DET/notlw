// Static set: real-time direct light and shadows from the film lights, plus the bounce light baked in Blender
// (indirect diffuse irradiance on UV2), added as albedo * lightmap.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_tex = true;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float roughness_v = 0.8;
uniform float metallic_v = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy = 0.0;
uniform sampler2D lightmap : hint_default_black, filter_linear;
uniform float bounce = 1.0;

void fragment() {
	vec3 a = albedo_color.rgb;
	if (use_tex) a *= texture(albedo_tex, UV).rgb;
	ALBEDO = a;
	ROUGHNESS = roughness_v;
	METALLIC = metallic_v;
	EMISSION = a * texture(lightmap, UV2).rgb * bounce + emission_color.rgb * emission_energy;
}
