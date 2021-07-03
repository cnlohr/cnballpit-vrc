Shader "Error.mdl/Water Flowmap 2 SSR"
{
	Properties
	{
		_Refraction ("Index of Refraction", Range (0.00, 2.0)) = 1.0
		_Power ("Power", Range (0.01, 10.0)) = 1.0
		_AlphaPower ("Vertex Alpha Power", Range (1.00, 10.0)) = 1.0
		_BumpMap("Normal Map", 2D) = "bump" {}
		_BumpMap2("Normal Map 2", 2D) = "bump" {}
		_FlowMap("Flow Map", 2D) = "bump" {}
		_BumpScale("Reflection Normal Scale", range(0,2)) = 1.0
		_BumpScale2("Refraction Normal Scale", range(0,2)) = 1.0
		_Scroll("Scroll (u1,v1,u2,v2)", Vector) = (1,0,0,-0.5)
		_ScrollU("U Scroll Speed", float) = 0.0
		_ScrollV("V Scroll Speed", float) = 0.0
		_CubeStr("Cubemap reflection strength", range(0,1)) = 0.25
		_DepthFade("Edge Fade Factor", float) = 0.1
		_BaseColor ("Base Fog Color", color) = (1, 1, 1, 1)
		_DepthColor ("Depth Color", color) = (0.5, 0.5, 0.5, 1)
		_fogDepth ("Fog Depth", float) = 2
		_flowSpeed("Flowmap Max Speed", Float) = 1.0
		
	 [Header(Screen Space Reflection Settings)]
		_SSRTex("SSR mask", 2D) = "white" {}
		_NoiseTex("Noise Texture", 2D) = "black" {}
		_alpha("Reflection Strength", Range(0.0, 1.0)) = 1
		_rtint("Reflection Tint Strength", Range(0.0, 1.0)) = 0
		_blur("Blur (does ^2 texture samples!)", Float) = 8
		_MaxSteps("Max Steps", Int) = 100
		_step("Ray step size", Float) = 0.09
		_lrad("Large ray intersection radius", Float) = 0.2
		_srad("Small ray intersection radius", Float) = 0.02
		_edgeFade("Edge Fade", Range(0,1)) = 0.1
	}

	SubShader
	{
		Tags { "Queue" = "Transparent-50" }

		GrabPass
		{
			"_TransparentGrabPass"
		}
			
		Pass
		{
			Cull off
			//Blend One One
			//Blend SrcAlpha OneMinusSrcAlpha
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 3.0
		
			#include "UnityCG.cginc"
			#include "AutoLight.cginc"
			#include "Lighting.cginc"
			#include "BoxReflection.cginc"
			#include "SSR.cginc"
		
			struct VertIn
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float4 color: COLOR;
			};
		
			struct VertOut
			{
				float4 vertex : SV_POSITION;
				float2 uv0 : TEXCOORD0;
				float4 uv : TEXCOORD1;
				float2 uv1 : TEXCOORD2;
				half3 tspace0 : TEXCOORD3;
				half3 tspace1 : TEXCOORD4;
				half3 tspace2 : TEXCOORD5;
				float4 wPos : TEXCOORD6;
				half3 faceNormal : TEXCOORD7;
				float3 ray : TEXCOORD8;
				float4 color: COLOR;
				float2 uv2 : TEXCOORD9;
				//	 float2 uv3: TEXCOORD9;
			};
		
			//sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D  _BumpMap;
			sampler2D  _BumpMap2;
			half4  _BumpMap_ST;
			half4  _BumpMap2_ST;
			sampler2D _FlowMap;
			float4 _FlowMap_ST;
			float _flowSpeed;
			float _BumpScale;
			float _BumpScale2;
			float _fogDepth;
			//sampler2D _Metallic;
					
			VertOut vert(VertIn v, float3 normal : NORMAL, float4 tangent : TANGENT)
			{
				VertOut o;
				
			
					o.vertex = UnityObjectToClipPos(v.vertex);
					o.uv = ComputeGrabScreenPos(o.vertex);
					half3 wNormal = normalize(UnityObjectToWorldNormal(normal));
					o.color = v.color;
					o.wPos = mul(unity_ObjectToWorld, v.vertex);

					o.faceNormal = wNormal;

					// Tangent info for calculating world-space normals from a normal map
					half3 wTangent = UnityObjectToWorldDir(tangent.xyz);
					half tangentSign = tangent.w * unity_WorldTransformParams.w;
					half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
					
					o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
					o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
					o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);

					o.ray = mul(UNITY_MATRIX_MV, v.vertex).xyz * float3(-1, -1, 1);
					
					o.uv0 = TRANSFORM_TEX(v.uv, _BumpMap);
					o.uv1 = TRANSFORM_TEX(v.uv, _FlowMap);
					o.uv2 = TRANSFORM_TEX(v.uv, _BumpMap2);
					return o;
			}
		
			sampler2D _SSRTex;
			sampler2D _NoiseTex;
			float4 _NoiseTex_TexelSize;
			int _dith;
			float _alpha;
			float _blur;
			
			float _edgeFade;
			half _rtint;
			half _lrad;
			half _srad;
			float _step;
			int _MaxSteps;
			float _ScrollU;
			float _ScrollV;
			float _Refraction;
			float _Power;
			float _CubeStr;
			float _DepthFade;
			float4 _Scroll;
			float4 _BaseColor;
			float4 _DepthColor;
			
			sampler2D _TransparentGrabPass;
			float4 _TransparentGrabPass_TexelSize;

			
			float getDepthDifference(float4 wPos, float2 uvDepth, float facing)
			{


				//static const float4x4 worldToDepth = mul(UNITY_MATRIX_MV, unity_WorldToObject);
				float rawDepth = DecodeFloatRG(tex2Dlod(_CameraDepthTexture, float4(uvDepth, 0, 0)));
				float depthDifference, FarDepth, NearDepth, realDepth;
				UNITY_BRANCH if (facing > 0)
				{
					FarDepth = Linear01Depth(rawDepth);
					NearDepth = -mul(UNITY_MATRIX_V, wPos).z;
					realDepth = FarDepth * _ProjectionParams.z;
					depthDifference = -NearDepth + realDepth;
				}
				else
				{
					FarDepth = -mul(UNITY_MATRIX_V, wPos).z;
					depthDifference = FarDepth;
				}
				return depthDifference;
			}

			float getDepthFade(float4 wPos, float facing)
			{
				float4 spos = ComputeGrabScreenPos(mul(UNITY_MATRIX_VP, wPos));
				float2 uvDepth = spos.xy / spos.w;
				float depthDifference = getDepthDifference(wPos, uvDepth, facing);
				float depthFactor = smoothstep(0, _DepthFade, depthDifference);
				return depthFactor;
			}

			float4 getRefractedPos(float4 vertex, float3 viewDir, float4 wPos, float3 wNormal, float rIndex, const float power)
			{
				float3 refracted = refract(viewDir, wNormal, 1.0 / rIndex);
				if (refracted.x == 0.0 && refracted.y == 0.0 && refracted.z == 0.0)
				{
					return float4(1.#INF, 0, 0, 1);
				}
				refracted = normalize(refracted);

				/*
				 * If we exceed the angle of total internal reflection, refract returns 0,0,0
				 * in which case the ratio of reflection to refraction needs to be 1. Otherwise
				 * linearly interpolate from 1 to the specified cubemap strength as the refracted
				 * ray goes from orthogonal to the normal to parallel with it
				 */
				 //float refrReflFactor = lerp(1, _CubeStr, saturate(-2*(dot(refracted, wNormal))  - 0.001)); 

				float4 offsetPos = wPos + float4(refracted * power, 0);
				return offsetPos;
			}

			float4 getRefractedUVs(float4 offsetPos, float4 wPos)
			{
				float4 sPos = ComputeGrabScreenPos(mul(UNITY_MATRIX_VP, offsetPos));
				float4 sPos1 = ComputeGrabScreenPos(mul(UNITY_MATRIX_VP, wPos));
				float2 UV = sPos.xy / sPos.w;
				float2 UV1 = sPos1.xy / sPos1.w;
				//float2 UV2 = UV;
				UV.y = lerp(UV.y, UV1.y, smoothstep(0.5, 0.2, UV.y + 0.1));
				
				return float4(UV, UV1);
			}

			float4 getRefractedColor(float4 offsetPos, float4 wPos, float facing, const sampler2D GrabPass)
			{
				float4 UVs = getRefractedUVs(offsetPos, wPos);
				float2 UV = UVs.xy;
				float2 UV1 = UVs.zw;
				float depthDiff = getDepthDifference(wPos, UV, facing);
				float FrontFade = depthDiff > -0.1 ? smoothstep(0,_fogDepth,depthDiff) : 1;

				float4 finalColor = tex2D(GrabPass, UV);
				finalColor.rgb = lerp(finalColor.rgb, _DepthColor.rgb, FrontFade);
				//finalColor.rgb = lerp(finalColor.rgb,  _BaseColor.rgb, power*FrontFade);
				/*
				 * if refracted is (0,0,0), then we have total internal reflection and we should
				 * be 100% reflective. In order to signal this, we'll give final color a negative
				 * alpha
				 */
				finalColor.a = _CubeStr;
				return finalColor;
			}

			
			float3 getWaterNormalSimple(sampler2D BumpMap, sampler2D BumpMap2, float4 scroll, float2 uv0, float2 uv1)
			{
				float4 uvScroll = frac(_Time[0]*scroll);
				half3 tnormal1 = UnpackNormal(tex2D(BumpMap, uv0 + uvScroll.xy));
				half3 tnormal2 = UnpackNormal(tex2D(BumpMap2, uv1 + uvScroll.zw));
				//half3 tnormal = normalize(tnormal1 + tnormal2);
				float3 tnormal = float3(tnormal1.xy*tnormal2.z + tnormal2.xy*tnormal1.z, tnormal1.z*tnormal2.z);
				tnormal.xy *= _BumpScale;
				//tnormal = normalize(tnormal);
				return tnormal;
			}
			
			float sawtoothwave(float x, float p)
			{
				return (x / p - floor(x / p));
			}

			float trianglewave(float x, float p)
			{
				return 2 * abs(x / p - floor(x / p + 0.5));
			}

			float3 ScrollTex(sampler2D BumpMap, sampler2D BumpMap2, sampler2D FlowMap, float2 uv, float2 uv2, float2 uv_flowmap, float4 scroll)
			{
				float2 flow = 2.0 * tex2D(FlowMap, uv_flowmap).rg - float2(1.0, 1.0);
				flow.g = -flow.g;
				//flow = abs(flow);
				flow *= _flowSpeed;
				scroll.xy = lerp(scroll.xy, flow, saturate(length(flow)));
				scroll.zw = lerp(scroll.zw, flow, saturate(length(flow)));
				float period = 1;
				float time1 = _Time[1] * 0.25;
				float saw1 = sawtoothwave(time1, period);
				float saw2 = sawtoothwave(time1 + 0.5 * period, period);
				//float uvScroll = frac(_Time[0]);
				//float4 uv1 = uv.xyxy + scroll * frac(uvScroll) - 0.5*scroll;
				//float4 uv2 = uv.xyxy + scroll * frac(uvScroll + 0.5) - 0.5*scroll;
				float4 uv_1 = float4(uv,uv2) + 0.1 * scroll * saw1;
				float4 uv_2 = float4(uv,uv2) + 0.1 * scroll * saw2;
				//float blend1 = 2 * abs(uvScroll - floor(uvScroll + 0.5));
				float blend1 = trianglewave(time1, period);
				float blend2 = 1 - blend1;
				float3 tnormal11 = UnpackNormal(tex2D(BumpMap, uv_1.xy));
				float3 tnormal12 = UnpackNormal(tex2D(BumpMap, uv_2.xy));


				float3 tnormal1 = normalize(blend1 * tnormal11 + blend2 * tnormal12);

				float3 tnormal21 = UnpackNormal(tex2D(BumpMap2, uv_1.zw));
				float3 tnormal22 = UnpackNormal(tex2D(BumpMap2, uv_2.zw));

				float3 tnormal2 = normalize(blend1 * tnormal21 + blend2 * tnormal22);

				float3 tnormal = float3(tnormal1.xy * tnormal2.z + tnormal2.xy * tnormal1.z, tnormal1.z * tnormal2.z);
				//tnormal.xy *= _BumpScale;
				//tnormal = normalize(tnormal);
				return tnormal;
				//return blend1 * color1 + blend2 * color2;
				//return float4(blend,blend,blend,1);
			}
					
//--------------------------------------------------------------------------------------------------------------
		
			float4 frag(VertOut i, fixed facing : VFACE) : SV_Target
			{
				/*
				 * We can't use unity's screen params variable as it is actually wrong
				 * in VR (for some reason the width is smaller by some amount than the
				 * true width. However, we're taking a grabpass and the dimensions of
				 * that texture are the true screen dimensions.
				 */
				#define scrnParams _PostTransparentGrabPass_TexelSize.zw
				
				half3 tnormal = ScrollTex(_BumpMap, _BumpMap2, _FlowMap, i.uv0, i.uv2, i.uv1, _Scroll);
				half3 tnormal2 = float3(tnormal.xy * _BumpScale2, tnormal.z);
				tnormal.xy *= _BumpScale;
				//tnormal2.xy *= _BumpScale2;
				
				float4 metallic = float4(0,0,0,1);
				float smoothness = metallic.a;
				float4 albedo = float4(1,1,1,1);
				
				
				
				//tnormal = lerp(half3(0, 0, 1), tnormal, depthFade);
				//tnormal2 = lerp(half3(0, 0, 1), tnormal2, depthFade);
				tnormal = normalize(tnormal);
				tnormal2 = normalize(tnormal2);

				// Mask for defining what areas can have SSR
				float mask = tex2D(_SSRTex, i.uv0).r;
				
				// Get the world-space normal direction from the normal map
				half3 wNormal;
				wNormal.x = dot(i.tspace0, tnormal);
				wNormal.y = dot(i.tspace1, tnormal);
				wNormal.z = dot(i.tspace2, tnormal);

				half3 wNormal2;
				wNormal2.x = dot(i.tspace0, tnormal2);
				wNormal2.y = dot(i.tspace1, tnormal2);
				wNormal2.z = dot(i.tspace2, tnormal2);
				
				float refrIndex = _Refraction;
				half3 faceNormal = i.faceNormal;

				//Correct for if we're looking at a back face
				if (facing <= 0)
				{
					refrIndex = 1/refrIndex;
					faceNormal = -faceNormal;
					wNormal = -wNormal;
					wNormal2 = -wNormal2;
				}

				float3 viewDir = normalize(i.wPos.xyz - _WorldSpaceCameraPos);
				float4 rayDir = float4(reflect(viewDir, wNormal).xyz, 0);
				

				
				float4 SSR = float4(0, 0, 0, 0);
				UNITY_BRANCH if (!IsInMirror())
				{
					SSR = getSSRColor2(
						i.wPos,
						viewDir,
						rayDir,
						faceNormal,
						_lrad,
						_srad,
						_step,
						_blur,
						_MaxSteps,
						_dith,
						smoothness,
						_edgeFade,
						_TransparentGrabPass_TexelSize.zw,
						_TransparentGrabPass,
						_NoiseTex,
						_NoiseTex_TexelSize.zw,
						albedo,
						metallic.r,
						_rtint,
						mask,
						_alpha
					);

					SSR = facing > 0 ? SSR : SSR * _BaseColor;
				}




				float4 cubemap = getCubemapColor(i.wPos.xyz, rayDir.xyz, 1.0);
				cubemap = lerp(cubemap, SSR, min(1,SSR.a*4.0));
				cubemap.a = _CubeStr;
				float depthFade1 = getDepthFade(i.wPos, facing);

				float4 offsetPos = getRefractedPos(i.vertex, viewDir, i.wPos, wNormal2, refrIndex, _Power * i.color.r * depthFade1);


				float depthFade; 
				float4 BaseColor; 
				float4 refract;
				float4 output;
				if (offsetPos.x != 1.#INF)
				{
					depthFade = getDepthFade(offsetPos, facing);
					BaseColor = lerp(float4(1, 1, 1, 1), _BaseColor, depthFade1);
					refract = getRefractedColor(offsetPos, i.wPos, facing, _TransparentGrabPass);
					output = lerp(BaseColor * refract, cubemap, refract.a);
				}
				else
				{
					depthFade = 1;
					BaseColor = _BaseColor;
					refract = float4(0, 0, 0, 1);
					output = cubemap * _BaseColor;
				}

				//output.a *= i.color.r;
				//float refractReflectFactor = refract.a <= 0 ? 1 : _CubeStr; 
				return output;//float4(_BaseColor.rgb + cubemap.rgb*_CubeStr, _BaseColor.a);
			}
			ENDCG
		}
	}
}