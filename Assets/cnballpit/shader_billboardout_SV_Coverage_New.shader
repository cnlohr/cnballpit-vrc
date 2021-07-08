// UNITY_SHADER_NO_UPGRADE

Shader "cnballpit/billboardoutSV_Coverage_New" 
{
	Properties 
	{
		_PositionsIn ("Positions", 2D) = "" {}
		_VelocitiesIn ("Velocities", 2D) = "" {}
		_Mode ("Mode", float) = 0
		_Smoothness( "Smoothness", float ) = 0
		_Metallic("Metallic", float ) = 0
		_ScreenshotMode("Screenshot Mode", float) = 0
		[ToggleUI] _ExtraPretty( "Extra Pretty", float ) = 0
	}

	SubShader 
	{
	
		// shadow caster rendering pass, implemented manually
		// using macros from UnityCG.cginc
		Pass
		{
			Tags {"LightMode"="ShadowCaster"}

			CGINCLUDE
			
			#include "/Assets/hashwithoutsine/hashwithoutsine.cginc"
			#include "/Assets/AudioLink/Shaders/AudioLink.cginc"
			#pragma vertex vert
			#pragma geometry geo

			#pragma target 5.0

			//#define SHADOWS_SCREEN
			
			#include "UnityCG.cginc"
			#include "cnballpit.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"
			#include "UnityShadowLibrary.cginc"
			#include "UnityPBSLighting.cginc"


			#define SHADOW_SIZE 0.4
			#define OVERDRAW_FUDGE 0.6

			struct v2g
			{
				float4	pos		: POSITION;
				float3	normal	: NORMAL;
				float2  uv	: TEXCOORD0;
				float4  opos	: TEXCOORD1;
			};
			struct g2f
			{
				float4	pos		: POSITION;
				float2  uv	: TEXCOORD0;
				float4  ballcenter : TEXCOORD1;
				float3  hitworld : TEXCOORD2;
				float4  props : TEXCOORD3;
				float4  colorDiffuse : TEXCOORD4;
				float4  colorAmbient : TEXCOORD5;
			};

			float4x4 _VP;
			
			float _Mode, _Smoothness, _Metallic;
			texture2D<float4> _RVData;
			float4 _RVData_TexelSize;
			float _ExtraPretty;
			float _ScreenshotMode;
			
			v2g vert(appdata_base v)
			{
				v2g output = (v2g)0;

				output.pos =  mul(unity_ObjectToWorld, v.vertex);
				output.normal = v.normal;
				output.uv = float2(0, 0);
				output.opos = v.vertex;

				return output;
			}

			[maxvertexcount(32)]
			void geo(point v2g p[1], inout TriangleStream<g2f> triStream, uint id : SV_PrimitiveID)
			{
				int transadd;
				for( transadd = 0; transadd < 8; transadd++ )
				{
					//based on https://github.com/MarekKowalski/LiveScan3D-Hololens/blob/master/HololensReceiver/Assets/GS%20Billboard.shader

					float3 worldoffset = p[0].pos;	// World pos of center of system.
					//int3  oposid = p[0].opos * float3( -1, 1, 1 ) + float3( 0., 0., 0. );
					
					//oposid += transadd * 16;
					
					// Set based on data
					//int ballid = oposid.x + oposid.y * 32 + oposid.z * 1024;
					uint ballid = id * 8 + transadd;
					
					float4 DataPos = GetPosition(ballid);
					float3 PositionRelativeToCenterOfBallpit = DataPos;
					float4 DataVel = GetVelocity(ballid);
					DataPos.xyz += worldoffset ;
					
					float3 rvpos = DataPos;

					float3 up, look, right;

					up = float3(0, 1, 0);
 
					if ((UNITY_MATRIX_P[3].x == 0.0) && (UNITY_MATRIX_P[3].y == 0.0) && (UNITY_MATRIX_P[3].z == 0.0)){
						//look = UNITY_MATRIX_V[2].xyz;
						look = normalize(_WorldSpaceLightPos0.xyz - rvpos * _WorldSpaceLightPos0.w);
					}
					else
					{
						look = _WorldSpaceCameraPos - rvpos;
						//look.y = 0; //uncomment to force horizontal billboard.
					}
 


					look = normalize(look);
					right = cross(up, look);
					
					//Make actually face directly.
					up = normalize(cross( look, right ));
					right = normalize(right);

					float size = DataPos.w*2+.1; //DataPos.w is radius. (Add a little to not clip edges.)
					float halfS = 0.5f * size * OVERDRAW_FUDGE;
					
					//Pushthe view plane away a tiny bit, to prevent nastiness when doing the SV_DepthLessEqual for perf.
					rvpos += look*halfS;
							
					float4 v[4];
					v[0] = float4(rvpos + halfS * right - halfS * up, 1.0f);
					v[1] = float4(rvpos + halfS * right + halfS * up, 1.0f);
					v[2] = float4(rvpos - halfS * right - halfS * up, 1.0f);
					v[3] = float4(rvpos - halfS * right + halfS * up, 1.0f);

					float4x4 vp = mul( UNITY_MATRIX_MVP, unity_WorldToObject);


					float4 colorDiffuse = float4( hash33((DataVel.www*10.+10.1)), 1. ) - .1;
					
					float3 SmoothHue = AudioLinkHSVtoRGB( float3(  frac(ballid/1024. + AudioLinkDecodeDataAsSeconds(ALPASS_GENERALVU_NETWORK_TIME)*.05), 1, .8 ) );
					float4 colorAmbient = 0.;

					if( _ScreenshotMode > 0.5 )
					{
						float dfc = length( PositionRelativeToCenterOfBallpit.xz ) / 15;
						float intensity = saturate(sin(dfc*15.+2.5)+0.3);//(glsl_mod( dfc * 5, 1.0 )>0.5)?1:0;
						static const float3 ballcolors[7] = { float3( .984, .784, 0 ), float3( 0.0, .635, .820 ), float3( .918, .271, .263 ),
							float3( .729, .739, .059 ), float3( .941, .490, .024 ), float3( .682, .859, .941 ), float3( .537, .451, .776 ) };

						colorDiffuse.xyz = ballcolors[ballid%7];

						//colorDiffuse *= intensity; 
						colorAmbient += colorDiffuse * intensity * .3;
						colorDiffuse = colorDiffuse * .5 + .04;
					} else if( _Mode == 0 )
					{
						colorAmbient   += colorDiffuse * .1;
					}
					else if( _Mode == 1 )
					{
						colorDiffuse = abs(float4( 1.-abs(glsl_mod(PositionRelativeToCenterOfBallpit.xyz,2)), 1 )) * .8;
						colorAmbient   += colorDiffuse * .1;
					}
					else if( _Mode == 2 )
					{
						colorDiffuse.xyz = SmoothHue;
						colorAmbient   += colorDiffuse * .1;

					}
					else if( _Mode == 3 )
					{
						float dfc = length( PositionRelativeToCenterOfBallpit.xz ) / 15;
						float intensity = saturate( AudioLinkData( ALPASS_AUDIOLINK + uint2( dfc * 128, (ballid / 128)%4 ) ) * 6 + .05 );
						colorDiffuse.xyz = SmoothHue;
						//colorDiffuse *= intensity; 
						colorAmbient += colorDiffuse * intensity * .3;
						colorDiffuse = colorDiffuse * .5 + .04;
					}
					else if( _Mode == 4 )
					{
						//float intensity = saturate( AudioLinkData( ALPASS_FILTEREDAUDIOLINK + uint2( 4, ( ballid / 128 ) % 4 ) ) * 6 + .1);

						uint selccnote = 0;
						uint balldiv = ballid % 7;
						if( balldiv < 3 ) selccnote = 0;
						else if( balldiv < 5 ) selccnote = 1;
						else if( balldiv < 6 ) selccnote = 2;
						else selccnote = 3;
						float4 rnote =  AudioLinkData( ALPASS_CCINTERNAL + uint2( selccnote % 4, 0 ) );
						float rgbcol;
						if( rnote.x >= 0 )
							colorDiffuse.xyz = AudioLinkCCtoRGB( rnote.x, rnote.z * 0.1 + 0.1, 0 );
						else
							colorDiffuse.xyz = SmoothHue * 0.1;

						colorAmbient   += colorDiffuse * .1;
					}
					else if( _Mode == 5 )
					{
						float dfc = length( PositionRelativeToCenterOfBallpit.xz ) / 15;
						float intensity = saturate( AudioLinkData( ALPASS_AUDIOLINK + uint2( dfc * 128, (ballid / 128)%4 ) ) * 6 + .05 );
						static const float3 ballcolors[7] = { float3( .984, .784, 0 ), float3( 0.0, .635, .820 ), float3( .918, .271, .263 ),
							float3( .729, .739, .059 ), float3( .941, .490, .024 ), float3( .682, .859, .941 ), float3( .537, .451, .776 ) };

						colorDiffuse.xyz = ballcolors[ballid%7];

						//colorDiffuse *= intensity; 
						colorAmbient += colorDiffuse * intensity * .3;
						colorDiffuse = colorDiffuse * .5 + .04;
					}
					
					g2f pIn;
					
					
					pIn.pos = mul(vp, v[0]);
					pIn.uv = float2(1.0f, 0.0f);
					pIn.ballcenter = DataPos.xyzw;
					pIn.hitworld = v[0];
					pIn.props = float4( DataVel.w, 0, 0, 1 );
					pIn.colorDiffuse = colorDiffuse;
					pIn.colorAmbient = colorAmbient;
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[1]);
					pIn.uv = float2(1.0f, 1.0f);
					pIn.hitworld = v[1];					
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[2]);
					pIn.uv = float2(0.0f, 0.0f);
					pIn.hitworld = v[2];
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[3]);
					pIn.uv = float2(0.0f, 1.0f);
					pIn.hitworld = v[3];
					triStream.Append(pIn);
					triStream.RestartStrip();
				}
			}

			ENDCG

			CGPROGRAM

			#pragma fragment frag alpha earlydepthstencil
			#pragma multi_compile_shadowcaster


			struct shadowHelper
			{
				float4 vertex;
				float3 normal;
				V2F_SHADOW_CASTER;
			};

			float4 colOut(shadowHelper data)
			{
				SHADOW_CASTER_FRAGMENT(data);
			}


			float4 frag(g2f input, out float outDepth : SV_DepthLessEqual) : COLOR
			{
				float4 props = input.props;
				float3 s0 = input.ballcenter;
				float sr = input.ballcenter.w;
				float3 hitworld = input.hitworld;
				float3 ro = _WorldSpaceCameraPos;
				float3 rd = normalize(hitworld-_WorldSpaceCameraPos);


				float a = dot(rd, rd);
				float3 s0_r0 = ro - s0;
				float b = 2.0 * dot(rd, s0_r0);
				float c = dot(s0_r0, s0_r0) - (sr * sr);
				
				float disc = b * b - 4.0 * a* c;

				//clip( disc );
				if (disc < 0.0)
					discard;
				float2 answers = float2(-b - sqrt(disc), -b + sqrt(disc)) / (2.0 * a);
				float minr = min( answers.x, answers.y );
	
	
				float3 worldhit = ro + rd * minr;
				float3 dist = worldhit.xyz - _LightPositionRange.xyz;

#if 1
				// Tricky - if we're doing the shadow pass, we're orthographic.
				// compute outDepth this other way.
				if ((UNITY_MATRIX_P[3].x == 0.0) && (UNITY_MATRIX_P[3].y == 0.0) && (UNITY_MATRIX_P[3].z == 0.0))
				{
					float4 clipPos = mul(UNITY_MATRIX_VP, float4(hitworld, 1.0));
					if( length( input.uv-0.5) < SHADOW_SIZE )
						outDepth = clipPos.z / clipPos.w;
					else
						outDepth = 0;
					return 0.;
				}
#endif
				//Charles way.
				float4 clipPos = mul(UNITY_MATRIX_VP, float4(worldhit, 1.0));
				
				//D4rkPl4y3r's way.				
				shadowHelper v;
				v.vertex = mul(unity_WorldToObject, float4(worldhit, 1));
				v.normal = normalize(mul((float3x3)unity_WorldToObject, worldhit - s0));
				TRANSFER_SHADOW_CASTER_NOPOS(v, clipPos);
				outDepth = clipPos.z / clipPos.w;

				float dx = length( float2( ddx(disc), ddy(disc) ) );
				float edge = disc/dx;
				if( edge < 1.0 ) outDepth = 0;

				//return colOut(v);
				return 0;
			}

			ENDCG
		}
		

		Pass
		{
			Tags { "RenderType"="Opaque" "LightModel"="ForwardBase"}
			//LOD 200
			//Tags {"Queue" = "Transparent" "RenderType"="Opaque" } 
			//AlphaToMask On

		
			CGPROGRAM


			#pragma fragment FS_Main alpha
			#pragma multi_compile_fwdadd_fullshadows



		#define FIXED_POSITION_RANGE 64
		#define SIGN_BIT 0x80000000
		#define GET_SIGN_BIT(f) ((asuint(f) & SIGN_BIT) >> 31)
		#define BITS_PER_POSITION 24
		#define MASK_BITS(bitCount) ((1 << (bitCount)) - 1)

		void decodeData(uint4 data, out float3 pos, out float3 vel, out uint colorId)
		{
			uint3 fixedPos;
			fixedPos.x = data.x >> 8;
			fixedPos.y = (data.x & MASK_BITS(8)) << 16 | data.y >> 16;
			fixedPos.z = (data.y & MASK_BITS(8)) << 16 | data.z >> 16;
			pos = (float3)(fixedPos & MASK_BITS(BITS_PER_POSITION - 1));
			pos *= ((float)FIXED_POSITION_RANGE) / (1 << (BITS_PER_POSITION - 1));
			pos = asfloat(asuint(pos) | ((fixedPos << (32 - BITS_PER_POSITION)) & SIGN_BIT));
			vel.x = f16tof32(data.z & MASK_BITS(16));
			vel.y = f16tof32(data.w >> 16);
			vel.z = f16tof32(data.w & MASK_BITS(16));
			colorId = (data.y >> 8) & MASK_BITS(8);
		}

		//L1 light probe sampling - from Bakery Standard
		float3 SHEvalL0L1Geomerics(float3 n)
		{
			// average energy
			//float R0 = L0;
			float3 R0 = { unity_SHAr.a, unity_SHAg.a, unity_SHAb.a };

			// avg direction of incoming light
			//float3 R1 = 0.5f * L1;
			float3 R1r = unity_SHAr.rgb;
			float3 R1g = unity_SHAg.rgb;
			float3 R1b = unity_SHAb.rgb;

			float3 rlenR1 = { dot(R1r,R1r), dot(R1g, R1g), dot(R1b, R1b) };
			rlenR1 = rsqrt(rlenR1);

			// directional brightness
			//float lenR1 = length(R1);
			float3 lenR1 = rcp(rlenR1) * .5;

			// linear angle between normal and direction 0-1
			//float q = 0.5f * (1.0f + dot(R1 / lenR1, n));
			//float q = dot(R1 / lenR1, n) * 0.5 + 0.5;
			//float q = dot(normalize(R1), n) * 0.5 + 0.5;
			float3 q = { dot(R1r, n), dot(R1g, n), dot(R1b, n) };
			q = q * rlenR1 * .5 + .5;
			q = isnan(q) ? 1 : q;

			// power for q
			// lerps from 1 (linear) to 3 (cubic) based on directionality
			float3 p = 1.0f + 2.0f * (lenR1 / R0);

			// dynamic range constant
			// should vary between 4 (highly directional) and 0 (ambient)
			float3 a = (1.0f - (lenR1 / R0)) / (1.0f + (lenR1 / R0));

			return max(0, R0 * (a + (1.0f - a) * (p + 1.0f) * pow(q, p)));
		}

		float3 BlendCubeMapOnDistance(float smoothness, float3 reflectedDir, float distanceBlend)
		{
			Unity_GlossyEnvironmentData envData;
			envData.roughness = 1 - smoothness;
			envData.reflUVW = reflectedDir;
			float3 result = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0),
				unity_SpecCube0_HDR, envData);
			float spec0interpolationStrength = unity_SpecCube0_BoxMin.w;
			UNITY_BRANCH
			if (spec0interpolationStrength < 0.999)
			{
				float spec0dist = length(unity_SpecCube0_ProbePosition - unity_ObjectToWorld._14_24_34);
				float spec1dist = length(unity_SpecCube1_ProbePosition - unity_ObjectToWorld._14_24_34);
				spec0interpolationStrength = smoothstep(-distanceBlend, distanceBlend, spec1dist - spec0dist);
				envData.reflUVW = reflectedDir;
				result = lerp(Unity_GlossyEnvironment(
					UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0),
					unity_SpecCube1_HDR, envData),
					result, spec0interpolationStrength);
			}
			return result;
		}

		float min3(float3 v)
		{
			return min(v.x, min(v.y, v.z));
		}

		half3 boxProjection(half3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax)
		{
			// Do we have a valid reflection probe?
			UNITY_BRANCH
			if (cubemapCenter.w > 0.0)
			{
				half3 nrdir = worldRefl;
				half3 rbmax = (boxMax.xyz - worldPos) / nrdir;
				half3 rbmin = (boxMin.xyz - worldPos) / nrdir;
				half3 rbminmax = (nrdir > 0.0f) ? rbmax : rbmin;
				worldRefl = worldPos - cubemapCenter.xyz + nrdir * min3(rbminmax);
			}
			return worldRefl;
		}

		float3 cubemapReflection(float smoothness, float3 reflectedDir, float3 pos)
		{
			float3 worldPos = pos;
			float3 worldReflDir = reflectedDir;
			Unity_GlossyEnvironmentData envData;
			envData.roughness = 1 - smoothness;
			envData.reflUVW = boxProjection(worldReflDir, worldPos,
				unity_SpecCube0_ProbePosition,
				unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
			float3 result = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0),
				unity_SpecCube0_HDR, envData);
			float spec0interpolationStrength = unity_SpecCube0_BoxMin.w;
			UNITY_BRANCH
			if (spec0interpolationStrength < 0.999)
			{
				envData.reflUVW = boxProjection(worldReflDir, worldPos,
					unity_SpecCube1_ProbePosition,
					unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
				result = lerp(Unity_GlossyEnvironment(
					UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0),
					unity_SpecCube1_HDR, envData),
					result, spec0interpolationStrength);
			}
			return result;
		}
		
		
			float4 FS_Main(g2f input, out float outDepth : SV_DepthLessEqual, out uint Coverage[1] : SV_Coverage ) : COLOR
			{
				float4 props = input.props;
				float3 s0 = input.ballcenter;
				float sr = input.ballcenter.w;
				float3 hitworld = input.hitworld;
				float3 ro = _WorldSpaceCameraPos;
				float3 rd = normalize(hitworld-_WorldSpaceCameraPos);
				
				float a = dot(rd, rd);
				float3 s0_r0 = ro - s0;
				float b = 2.0 * dot(rd, s0_r0);
				float c = dot(s0_r0, s0_r0) - (sr * sr);
				
				float disc = b * b - 4.0 * a* c;

				if (disc < 0.0)
				{
					//disc = 0;
					//return 0.;
				}
				float2 answers = float2(-b - sqrt(disc), -b + sqrt(disc)) / (2.0 * a);
				float minr = min( answers.x, answers.y );
	
	
				float3 worldhit = ro + rd * minr;
				float3 hitnorm = normalize(worldhit-s0);
				float4 clipPos = mul(UNITY_MATRIX_VP, float4(hitworld, 1.0));
				
				float4 albcolor = 1.;
				
				// Potentially subtract from shadowmap
				
				if( _ExtraPretty > 0.5 ) 
				{
					float4 col = input.colorDiffuse;
					float3 normal = hitnorm;
					float3 dir = rd;
					float3 wPos = worldhit;
					float attenuation = 1;
					
					float3 specularTint;
					float oneMinusReflectivity;
					float3 albedo = DiffuseAndSpecularFromMetallic(
						col.rgb, _Metallic, specularTint, oneMinusReflectivity
					);
					

					_Smoothness = saturate(_Smoothness + col.a * .1 - .1);
					UnityLight light;
					light.color = _LightColor0.rgb;
					light.dir = _WorldSpaceLightPos0.xyz;
					UnityIndirect indirectLight;
					indirectLight.diffuse = SHEvalL0L1Geomerics(normal);
					indirectLight.specular = cubemapReflection(_Smoothness, reflect(dir, normal), wPos);

					if (all(light.color == 0))
					{
						light.dir = normalize(unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz + 0.001);
						light.color = ShadeSH9(float4(light.dir, .25));
						indirectLight.diffuse = ShadeSH9(float4(0, 0, 0, 1));
					}
					else
					{
						indirectLight.diffuse += light.color * .25;
						light.color *= .75 * attenuation;
					}

					albcolor.rgb = UNITY_BRDF_PBS(
						albedo, specularTint,
						oneMinusReflectivity, _Smoothness,
						normal, -dir,
						light, indirectLight
					).rgb + input.colorAmbient.xyz;
				}
				else
				{
					const float shininessVal = 8;
					const float Kd = 1;
					const float Ks = 1;
					
					float3 N = normalize(hitnorm);
					float3 L = normalize(_WorldSpaceLightPos0);
					// Lambert's cosine law
					float lambertian = max(dot(N, L), 0.0);
					float specular = 0.0;
					if(lambertian > 0.0) {
						float3 R = reflect(-L, N);	  // Reflected light vector
						float3 V = normalize(-rd); // Vector to viewer
						// Compute the specular term
						float specAngle = max(dot(R, V), 0.0);
						specular = pow(specAngle, shininessVal);
					}
					
					albcolor = float4( input.colorAmbient.xyz +
						   Kd * lambertian * input.colorDiffuse +
						   Ks * specular * float3(.3, .3, .3), 1.0);
				   
				   
				   

					float attenuation = 1;

					//XXX TODO FIX SHADOWS
					#if 0
					struct shadowonly
					{
						float4 pos;
						float4 _LightCoord;
						SHADOW_COORDS(1)
					} so;
					so._LightCoord = 0.;
					so.pos = clipPos;
					UNITY_TRANSFER_SHADOW( so, 0. );
					attenuation = LIGHT_ATTENUATION( so );
					#else
					#endif
					
					albcolor *= attenuation;
				}

				UNITY_APPLY_FOG(i.fogCoord, col);
				outDepth = clipPos.z / clipPos.w;
				
				// Tricky - compute the edge-y-ness.  If we're on an edge
				// then reduce the alpha.
				float dx = length( float2( ddx_fine(disc), ddy_fine(disc) ) );

				//Thanks, D4rkPl4y3r.
				Coverage[0] = ( 1u << ((uint)(saturate(disc/dx)*GetRenderTargetSampleCount() + 0.5)) ) - 1;
				return albcolor;
			}

			ENDCG
		}
	} 
}
