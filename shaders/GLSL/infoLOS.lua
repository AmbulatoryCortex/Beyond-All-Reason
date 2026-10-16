local Spring = Spring
local alwaysColor, losColor, radarColor, jamColor, radarColor2 = Spring.GetLosViewColors()

return {
	definitions = {
		Spring.GetConfigInt("HighResInfoTexture") and "#define HIGH_QUALITY" or "",
		-- Engines that grade LOS from explicit codes register InfoTexStrength.
		-- Older engines get the legacy gray overlay.
		(Spring.GetConfigFloat("InfoTexStrength", -1) >= 0) and "#define LOS_EXPLICIT_CODES" or "",
	},
	vertex = [[#version 130
		varying vec2 texCoord;
		void main() {
			texCoord = gl_MultiTexCoord0.st;
			gl_Position = vec4(gl_Vertex.xyz, 1.0);
		}
	]],
	fragment = [[#version 130
	#ifdef HIGH_QUALITY
		//#extension GL_ARB_texture_query_lod : enable
	#endif
		uniform float time;
		uniform vec4 alwaysColor;
		uniform vec4 losColor;
		uniform vec4 radarColor1;
		uniform vec4 radarColor2;
		uniform vec4 jamColor;
		uniform sampler2D tex0;
		uniform sampler2D tex1;
		uniform sampler2D tex2;
		uniform sampler2D tex3;
		varying vec2 texCoord;
		const float LOS_CODE_RADAR  = 1.0 / 3.0;
		const float LOS_CODE_AIR    = 2.0 / 3.0;
		const float LOS_CODE_GROUND = 1.0;
		// The combiner blends each update over the previous frame. Codes are
		// linear, so this only smooths LOS edges over time. High enough that
		// RGB10 rounding cannot stall short of a level (stall < 0.004).
		const float LOS_CODE_BLEND  = 0.15;
	#ifdef HIGH_QUALITY
		//! source: http://www.ozone3d.net/blogs/lab/20110427/glsl-random-generator/
		float rand(const in vec2 n)
		{
			return fract(sin(dot(n, vec2(12.9898, 78.233))) * 43758.5453);
		}
		vec4 getTexel(in sampler2D tex, in vec2 p)
		{
			//int lod = int(textureQueryLOD(tex, p).x);
			int lod = 0;
			vec2 texSize = vec2(textureSize(tex, lod));
			vec4 c = vec4(0.0);
			for (int i = 0; i<4; i++) {
				// previously, offset was identical for all pixels, resulting in little gain from multisampling, makes offsets random for each texel fetch
				vec2 off = vec2(time + float(i) * 0.234567); 
				off = (vec2(rand(p.st + off.st), rand(p.ts - off.ts)) * 2.0 - 1.0) / texSize;
				c += texture2D(tex, p + off);
			}
			c *= 0.25;
			return smoothstep(0.5, 1.0, c);
		}
	#else
		#define getTexel texture2D
	#endif

		float diagLines(vec2 uv) {
			// Returns a value between 0 and 1 that form a diagonal pattern.

			// To produce "diagonal values", we just add x and y.
			float xy = uv.x + uv.y;

			// Multiply xy to decrease the period of the sine wave.
			// This is just an arbitrary number. Lower numbers will result in
			// wider lines and gaps.
			xy *= 1000.0;

                        // This is a sin wave, graphing it will help understand it.
                        // Graph it on desmos or something: (sin(x) * 0.5 + 0.5)^2
                        // The important thing is that all return values are between 0 and 1.
			return pow(sin(xy - time) * 0.5 + 0.5, 2);
		}

		void main() {
			// $info:los and $info:airlos are 0/1 coverage (filtered on edges),
			// $info:radar is r = radar, g = jammer coverage.
			float groundlos = getTexel(tex0, texCoord).r;
			float airlos = getTexel(tex1, texCoord).r;
			vec4 tex2Texel = getTexel(tex2, texCoord);
			float radar = tex2Texel.r;
			float jamming = tex2Texel.g;

		#ifdef LOS_EXPLICIT_CODES
			// Explicit level codes, decoded exactly by the engine (SMFFragProg
			// LosGradeApply) which grades the map by luminance/saturation:
			//   R = intel level, max() over the levels present:
			//       0 fog, 1/3 radar, 2/3 air-only LOS, 1 ground LOS
			//       (no never-seen state; fog is the lowest level)
			//   G = jammer coverage 0..1, independent of the level
			//   B = 1, marks the texel as explicit codes
			// Grading strength is the InfoTexStrength springsetting, not a color.
			float level = max(max(radar * LOS_CODE_RADAR, airlos * LOS_CODE_AIR), groundlos * LOS_CODE_GROUND);
			gl_FragColor = vec4(level, jamming, 1.0, LOS_CODE_BLEND);
		#else
			// Legacy: 3 levels of intel blended as gray, plus an additive jam tint.
			gl_FragColor = alwaysColor;
			gl_FragColor = max(gl_FragColor, radarColor2 * radar);
			float losCombined = mix(groundlos, airlos, 0.2);
			gl_FragColor = max(gl_FragColor, losColor * losCombined);
			gl_FragColor += jamColor * jamming;
			gl_FragColor.a = 0.03;
		#endif
		}
	]],
	uniformFloat = {
		alwaysColor = alwaysColor,
		losColor = losColor,
		radarColor1 = radarColor,
		jamColor = jamColor,
		radarColor2 = radarColor2,
	},
	uniformInt = {
		tex0 = 0,
		tex1 = 1,
		tex2 = 2,
		tex3 = 3,
	},
	textures = {
		[0] = "$info:los",
		[1] = "$info:airlos",
		[2] = "$info:radar",
		[3] = "$heightmap",
	},
}
