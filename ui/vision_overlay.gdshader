shader_type canvas_item;
render_mode unshaded;

// Vision-cone overlay — pure representation of the entity's C_Vision component.
//
// The whole field of view is covered by a mist; the cone (the component's
// exported vision area) is carved out and left fully clear. Outside the cone the
// mist does NOT erase the world — it only REDUCES visibility (it is translucent),
// so remembered terrain stays faintly readable. Raise mist_color's alpha to hide
// more, lower it to show more; 1.0 would erase the tiles entirely.
//
// All values arrive in the overlay's own logical space (the ColorRect fills the
// viewport), so no world transforms are needed here. UV * resolution gives the
// fragment position in that space, which stays correct under the project's
// canvas_items stretch (FRAGCOORD would be physical pixels instead):
//   resolution- the overlay size in logical pixels (uniform)
//   center    - the cone apex (the player) in logical pixels
//   radius    - the cone length in logical pixels (already scaled by camera zoom)
//   facing    - the look direction in logical space (unit)
//   half_angle- half the cone opening, in radians
//   mist_color- colour/alpha of the mist outside the cone (rgb, a)
uniform vec2 resolution = vec2(1152.0, 648.0);
uniform vec2 center = vec2(0.0, 0.0);
uniform float radius = 160.0;
uniform vec2 facing = vec2(1.0, 0.0);
uniform float half_angle = 0.785398;
uniform float softness = 10.0;
// Clear radius around the player, independent of the directional wedge, to ensure
// the entire sprite remains visible.
uniform float inner_radius = 16.0;
uniform float origin_offset = -12.0;
uniform float body_clear_radius = 24.0;
uniform vec4 mist_color : source_color = vec4(0.10, 0.11, 0.16, 0.75);

void fragment() {
	vec2 player_delta = UV * resolution - center;
	// Offset the cone apex behind the player's body so the cone contains
	// the entire player and points outward from their face.
	vec2 delta = player_delta + normalize(facing) * origin_offset;
	float player_dist = length(player_delta);
	float dist = length(delta);
	vec2 cone_dir = dist > 0.0001 ? delta / dist : normalize(facing);

	// 1 inside the cone, 0 outside. The feather softens the arc and the edges so
	// the transition into the mist is smooth rather than a hard cut.
	float radial = 1.0 - smoothstep(radius - softness, radius, dist);
	float angular = 1.0 - smoothstep(
		half_angle - softness / max(radius, 1.0),
		half_angle,
		acos(clamp(dot(cone_dir, normalize(facing)), -1.0, 1.0))
	);
	float cone = radial * angular;
	// Clear the sprite body footprint independently from the directional cone.
	float body_clear = 1.0 - smoothstep(body_clear_radius - softness, body_clear_radius, player_dist);
	float visible = max(cone, body_clear);

	COLOR = vec4(mist_color.rgb, mist_color.a * (1.0 - visible));
}