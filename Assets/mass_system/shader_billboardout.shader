// UNITY_SHADER_NO_UPGRADE

Shader "mass_system/billboardout" 
{
	Properties 
	{
		_SpriteTex ("Base (RGB)", 2D) = "white" {}
		_RVData ("RV Data", 2D) = "" {}
	}

	SubShader 
	{

		Pass
		{
			Tags { "RenderType"="Opaque" "LightModel"="ForwardBase"}
			LOD 200
		
			CGPROGRAM
			#include "/Assets/hashwithoutsine/hashwithoutsine.cginc"
			#pragma target 5.0
			#pragma vertex VS_Main
			#pragma fragment FS_Main
			#pragma geometry GS_Main
			#include "UnityCG.cginc" 

			struct v2g
			{
				float4	pos		: POSITION;
				float3	normal	: NORMAL;
				float2  uv	: TEXCOORD0;
				float4  opos    : TEXCOORD1;
			};

			struct g2f
			{
				float4	pos		: POSITION;
				float2  uv	: TEXCOORD0;
				float4  color   : COLOR;
				float4  ballcenter : TEXCOORD1;
				float3  hitworld : TEXCOORD2;
				float4  props : TEXCOORD3;
			};

			float4x4 _VP;
			Texture2D _SpriteTex;
			SamplerState sampler_SpriteTex;
			
			texture2D<float4> _RVData;
			float4 _RVData_TexelSize;

			v2g VS_Main(appdata_base v)
			{
				v2g output = (v2g)0;

				output.pos =  mul(unity_ObjectToWorld, v.vertex);
				output.normal = v.normal;
				output.uv = float2(0, 0);
				output.opos = v.vertex;

				return output;
			}

			[maxvertexcount(32)]
			void GS_Main(point v2g p[1], inout TriangleStream<g2f> triStream)
			{
				int3 transadd;
				for( transadd.x = 0; transadd.x < 2; transadd.x++ )
				for( transadd.y = 0; transadd.y < 2; transadd.y++ )
				for( transadd.z = 0; transadd.z < 2; transadd.z++ )
				{
					//based on https://github.com/MarekKowalski/LiveScan3D-Hololens/blob/master/HololensReceiver/Assets/GS%20Billboard.shader

					float3 rvpos = p[0].pos;	// World pos of center of object.
					int3  oposid = p[0].opos * float3( -1, 1, 1 ) + float3( 0., 0., 0. );
					
					oposid += transadd * 16;
					
					// Set based on data
					uint2 opo = uint2( oposid.x + oposid.y * 32, oposid.z * 2 );
					float4 DataPos = _RVData[opo + uint2( 0, 0 )];
					float4 DataVel = _RVData[opo + uint2( 0, 1 )];
					
					rvpos = DataPos;

					float3 up = float3(0, 1, 0);
					float3 look = _WorldSpaceCameraPos - rvpos;
					//look.y = 0; //uncomment to force horizontal billboard.
					look = normalize(look);
					float3 right = cross(up, look);
					
					//Make actually face directly.
					up = normalize(cross( look, right ));
					right = normalize(right);

					float4 color = 
							//float4( DataVel.xyz, 1 );
							//( float4( oposid.xyz, 1. ) )/32 * float4( 0, 0, 1, 1 );
							//( float4( oposid.xyz, 1. ) )/32;
							float4( hash33((DataVel.www*10.+10.1)), 1. );
							//float4(DataVel.www,1);

					float size = DataPos.w*2+.1; //DataPos.w is radius. (Add a little to not clip edges.)
					float halfS = 0.5f * size;
							
					float4 v[4];
					v[0] = float4(rvpos + halfS * right - halfS * up, 1.0f);
					v[1] = float4(rvpos + halfS * right + halfS * up, 1.0f);
					v[2] = float4(rvpos - halfS * right - halfS * up, 1.0f);
					v[3] = float4(rvpos - halfS * right + halfS * up, 1.0f);

					float4x4 vp = mul( UNITY_MATRIX_MVP, unity_WorldToObject);

					g2f pIn;
					pIn.pos = mul(vp, v[0]);
					pIn.uv = float2(1.0f, 0.0f);
					pIn.color = color;
					pIn.ballcenter = DataPos.xyzw;
					pIn.hitworld = v[0];
					pIn.props = float4( DataVel.w, 0, 0, 1 );
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[1]);
					pIn.uv = float2(1.0f, 1.0f);
					pIn.color = color;
					pIn.hitworld = v[1];
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[2]);
					pIn.uv = float2(0.0f, 0.0f);
					pIn.color = color;
					pIn.hitworld = v[2];
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[3]);
					pIn.uv = float2(0.0f, 1.0f);
					pIn.color = color;
					pIn.hitworld = v[3];
					triStream.Append(pIn);
					triStream.RestartStrip();
				}
			}

			float4 FS_Main(g2f input, out float outDepth : SV_DepthLessEqual) : COLOR
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
					discard;
				float2 answers = float2(-b - sqrt(disc), -b + sqrt(disc)) / (2.0 * a);
				float minr = min( answers.x, answers.y );
	
	
				float3 worldhit = ro + rd * minr;
				float3 hitnorm = worldhit-s0;
				
				float4 albcolor = dot( _WorldSpaceLightPos0.xyz, hitnorm );
				
				
				const float shininessVal = 8;
				const float Kd = 1;
				const float Ks = 1;
				
				float3 N = normalize(hitnorm);
				float3 L = normalize(_WorldSpaceLightPos0);
				// Lambert's cosine law
				float lambertian = max(dot(N, L), 0.0);
				float specular = 0.0;
				if(lambertian > 0.0) {
					float3 R = reflect(-L, N);      // Reflected light vector
					float3 V = normalize(-rd); // Vector to viewer
					// Compute the specular term
					float specAngle = max(dot(R, V), 0.0);
					specular = pow(specAngle, shininessVal);
				}
				albcolor = float4( float3(.1,.1,.1) +
					   Kd * lambertian * input.color +
					   Ks * specular * float3(1.,1.,1.), 1.0);
			   

                UNITY_APPLY_FOG(i.fogCoord, col);
				float4 clipPos = mul(UNITY_MATRIX_VP, float4(worldhit, 1.0));
				outDepth = clipPos.z / clipPos.w;
				
				
				return _SpriteTex.Sample(sampler_SpriteTex, input.uv) * input.color * albcolor;
			}

			ENDCG
		}
	} 
}
