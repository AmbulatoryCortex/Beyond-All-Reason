// Shared LOS grade for BAR GL4 shaders. Insert with //__LOSGRADEDEFS__
// (LuaShader substitutes it). Lua side: LuaShader.BindLosGrade(shader, unit
// [, codeUnit]) after Activate() and LuaShader.UnbindLosGrade(unit [, codeUnit])
// after drawing, with uniformInt losGradeTex = unit (losCodeTex = codeUnit).
//
// On engines with Engine.FeatureSupport.losInfoTexCodes, "los" mode exposes
// "$info:losgrade": the engine's decoded, filterable LOS factors
//   r luminance multiplier of the level (fog .52, radar .76, air .88, ground 1)
//   g saturation multiplier (fog .45, radar .65, air .85, ground 1)
//   b jammer coverage
//   r < 0.25: the info texture is not coded (use the legacy $info gray)
// and "$info:loscodes": the raw, unfiltered level codes (R 0/.33/.67/1,
// B >= .75 coded), read with texelFetch for exact gates.
// $info itself stays a legacy-compatible gray in that mode, so shaders that
// were not migrated keep working.
// Tint is derived from the stored luminance (not packed in the texture):
// fog (-0.012, -0.002, +0.044), radar (0, 0, +0.008), air and ground none.
// LosGradeHoldRadar eases mixes between fog and radar; fog, radar, air and
// ground stay fixed points. Luminance is floored at 0.07, and an empty
// texel (under 0.005) is lifted with gray because an RGB scale cannot fill it.
// Keep the math in sync with the engine's LosGradeApply (SMFFragProg.glsl).
#ifndef BAR_LOSGRADE_DEFS
#define BAR_LOSGRADE_DEFS

uniform sampler2D losGradeTex;
uniform sampler2D losCodeTex;
uniform vec4 losGradeParams; // x: 1 = use losGradeTex, y: InfoTexStrength, z: game seconds

const vec3  LOSG_LUMA    = vec3(0.2126, 0.7152, 0.0722);
const float LOSG_FOG_LUM = 0.52;
const float LOSG_RAD_LUM = 0.76;
const float LOSG_AIR_LUM = 0.88;
const float LOSG_FLOOR   = 0.07;
const float LOSG_BLACK   = 0.005; // below this, an RGB scale cannot fill the texel
const float LOSG_JAM     = 0.92;

float LosGradeJamPhase(vec2 worldXZ, float t) {
	return dot(worldXZ, vec2(0.012, 0.009)) - t * 0.40;
}

// Ease-out on (fog, radar). Endpoints and every factor at or above radar
// stay put, so air/ground and the fog shelf do not move.
float LosGradeHoldRadar(float lum, float fogLum, float radarLum) {
	if (lum <= fogLum || lum >= radarLum || radarLum <= fogLum)
		return lum;
	float u = (lum - fogLum) / (radarLum - fogLum);
	float held = 1.0 - (1.0 - u) * (1.0 - u);
	return mix(fogLum, radarLum, held);
}

// Cool bias from the stored factor, before the hold and before strength.
// Fog -> (-0.012, -0.002, +0.044), radar -> (0, 0, +0.008), air/ground -> 0.
vec3 LosGradeTint(float lumMul) {
	vec3 fogTint = vec3(-0.012, -0.002, 0.044);
	vec3 radTint = vec3( 0.000,  0.000, 0.008);
	if (lumMul >= LOSG_AIR_LUM)
		return vec3(0.0);
	if (lumMul >= LOSG_RAD_LUM)
		return radTint * ((LOSG_AIR_LUM - lumMul) / (LOSG_AIR_LUM - LOSG_RAD_LUM));
	float t = clamp((lumMul - LOSG_FOG_LUM) / (LOSG_RAD_LUM - LOSG_FOG_LUM), 0.0, 1.0);
	return mix(fogTint, radTint, t);
}

// factors = (lumMul, satMul, unused, jam), unscaled by strength.
// Tint is derived from factors.x. false: not available or not coded ->
// caller uses its legacy $info path.
bool LosGradeAvailable(vec2 infoUV, out vec4 factors) {
	factors = vec4(1.0, 1.0, 0.0, 0.0);
	if (losGradeParams.x < 0.5)
		return false;
	vec3 g = textureLod(losGradeTex, infoUV, 0.0).rgb;
	factors = vec4(g.r, g.g, 0.0, g.b);
	return (g.r >= 0.25);
}

float LosGradeJamMul(vec4 factors, vec2 worldXZ) {
	return mix(1.0, LOSG_JAM * (0.97 + 0.03 * sin(LosGradeJamPhase(worldXZ, losGradeParams.z))), clamp(factors.w, 0.0, 1.0));
}

// full grade (luminance, saturation, RGB tint, jam, floor) of a color
vec3 LosGradeColor(vec3 col, vec4 factors, vec2 worldXZ) {
	float strength = clamp(losGradeParams.y, 0.0, 1.25);
	float jamMul = LosGradeJamMul(factors, worldXZ);

	float fogLum = 1.0 + (LOSG_FOG_LUM - 1.0) * strength;
	float radLum = 1.0 + (LOSG_RAD_LUM - 1.0) * strength;
	float lumMul = LosGradeHoldRadar(1.0 + (factors.x - 1.0) * strength, fogLum, radLum);
	float satMul = 1.0 + (factors.y - 1.0) * strength;
	vec3 tint = LosGradeTint(factors.x) * strength;
	jamMul = 1.0 + (jamMul - 1.0) * strength;

	float lum0 = dot(col, LOSG_LUMA);
	vec3 graded = mix(vec3(lum0), col, satMul) * (lumMul * jamMul);
	graded += tint;
	graded = max(graded, vec3(0.0));

	float lum1 = dot(graded, LOSG_LUMA);
	// Absolute floor. A near-black texel has no chroma to scale up.
	if (lum1 < LOSG_BLACK)
		graded += vec3(LOSG_FLOOR - lum1);
	else if (lum1 < LOSG_FLOOR)
		graded *= LOSG_FLOOR / lum1;
	return max(graded, vec3(0.0));
}

// luminance-only multiplier (for shaders that only had a scalar LOS factor).
// Same radar hold as LosGradeColor; jam still applies.
float LosGradeScalar(vec4 factors, vec2 worldXZ) {
	float strength = clamp(losGradeParams.y, 0.0, 1.25);
	float fogLum = 1.0 + (LOSG_FOG_LUM - 1.0) * strength;
	float radLum = 1.0 + (LOSG_RAD_LUM - 1.0) * strength;
	float lumMul = LosGradeHoldRadar(1.0 + (factors.x - 1.0) * strength, fogLum, radLum);
	return lumMul * (1.0 + (LosGradeJamMul(factors, worldXZ) - 1.0) * strength);
}

// Exact gameplay gate from the unfiltered codes (not scaled by strength):
// vis = 1 under ground LOS, 0 under air-only/radar/fog. Needs losCodeTex.
// false: not available or not coded -> caller uses its legacy path.
bool LosGradeGroundVisibility(vec2 infoUV, out float vis) {
	vis = 0.0;
	if (losGradeParams.x < 0.5)
		return false;
	ivec2 size = textureSize(losCodeTex, 0);
	ivec2 tc = clamp(ivec2(infoUV * vec2(size)), ivec2(0), size - ivec2(1));
	vec4 c = texelFetch(losCodeTex, tc, 0);
	if (c.b < 0.75)
		return false;
	vis = (c.r > 0.83) ? 1.0 : 0.0;
	return true;
}

#endif
