// Shared LOS grade for BAR GL4 shaders. Insert with //__LOSGRADEDEFS__
// (LuaShader substitutes it). Lua side: LuaShader.BindLosGrade(shader, unit)
// after Activate(), with uniformInt losGradeTex = unit.
//
// On engines with Engine.FeatureSupport.losInfoTexCodes, "los" mode exposes
// "$info:losgrade": the engine's decoded, filterable LOS factors
//   r luminance multiplier of the level (fog .52, radar .72, air .88, ground 1)
//   g saturation multiplier (fog .45, radar .65, air .85, ground 1)
//   b jammer coverage
//   r < 0.25: the info texture is not coded (use the legacy $info gray)
// $info itself stays a legacy-compatible gray in that mode, so shaders that
// were not migrated keep working. Keep the math in sync with the engine's
// LosGradeApply (SMFFragProg.glsl).
#ifndef BAR_LOSGRADE_DEFS
#define BAR_LOSGRADE_DEFS

uniform sampler2D losGradeTex;
uniform vec4 losGradeParams; // x: 1 = use losGradeTex, y: InfoTexStrength, z: game seconds

const vec3  LOSG_LUMA  = vec3(0.2126, 0.7152, 0.0722);
const float LOSG_FLOOR = 0.06;
const float LOSG_JAM   = 0.92;

float LosGradeJamPhase(vec2 worldXZ, float t) {
	return dot(worldXZ, vec2(0.012, 0.009)) - t * 0.40;
}

float LosGradeBlue(float lumMul) {
	return (lumMul < 0.72) ? mix(0.02, 0.01, (lumMul - 0.52) / 0.20) : (0.01 * clamp((0.88 - lumMul) / 0.16, 0.0, 1.0));
}

// factors = (lumMul, satMul, blueAdd, jam), unscaled by strength.
// false: not available or not coded -> caller uses its legacy $info path.
bool LosGradeAvailable(vec2 infoUV, out vec4 factors) {
	factors = vec4(1.0, 1.0, 0.0, 0.0);
	if (losGradeParams.x < 0.5)
		return false;
	vec3 g = textureLod(losGradeTex, infoUV, 0.0).rgb;
	factors = vec4(g.r, g.g, LosGradeBlue(g.r), g.b);
	return (g.r >= 0.25);
}

float LosGradeJamMul(vec4 factors, vec2 worldXZ) {
	return mix(1.0, LOSG_JAM * (0.97 + 0.03 * sin(LosGradeJamPhase(worldXZ, losGradeParams.z))), clamp(factors.w, 0.0, 1.0));
}

// full grade (luminance, saturation, blue, jam, floor) of a color
vec3 LosGradeColor(vec3 col, vec4 factors, vec2 worldXZ) {
	float strength = clamp(losGradeParams.y, 0.0, 1.25);
	float lumMul = 1.0 + (factors.x - 1.0) * strength;
	float satMul = 1.0 + (factors.y - 1.0) * strength;
	float jamMul = 1.0 + (LosGradeJamMul(factors, worldXZ) - 1.0) * strength;

	float lum0 = dot(col, LOSG_LUMA);
	vec3 graded = mix(vec3(lum0), col, satMul) * (lumMul * jamMul);
	float lum1 = dot(graded, LOSG_LUMA);
	graded *= max(lum1, min(LOSG_FLOOR, lum0)) / max(lum1, 1.0e-5);
	graded.b += factors.z * strength;
	return graded;
}

// luminance-only multiplier (for shaders that only had a scalar LOS factor)
float LosGradeScalar(vec4 factors, vec2 worldXZ) {
	float strength = clamp(losGradeParams.y, 0.0, 1.25);
	return (1.0 + (factors.x - 1.0) * strength) * (1.0 + (LosGradeJamMul(factors, worldXZ) - 1.0) * strength);
}

// 1 under ground LOS, 0 under air-only/radar/fog (gameplay visibility; not
// scaled by strength). Fades over the engine's short temporal blend.
float LosGradeGroundVisibility(vec4 factors) {
	return smoothstep(0.94, 1.0, factors.x);
}

#endif
