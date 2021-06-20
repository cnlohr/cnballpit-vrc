// UNITY_SHADER_NO_UPGRADE

Shader "mass_system/billboardout" 
{
	Properties 
	{
		_SpriteTex ("Base (RGB)", 2D) = "white" {}
		_RVData ("RV Data", 3D) = "" {}
	}

	SubShader 
	{

		Pass
		{
			Tags { "RenderType"="Opaque" }
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
			};

			float4x4 _VP;
			Texture2D _SpriteTex;
			SamplerState sampler_SpriteTex;
			
			texture3D<float4> _RVData;

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
					float4 DataPos = _RVData[oposid * uint3( 1, 1, 2 ) + uint3( 0, 0, 0 )];
					float4 DataVel = _RVData[oposid * uint3( 1, 1, 2 ) + uint3( 0, 0, 1 )];
					
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
							( float4( oposid.xyz, 1. ) )/32 * float4( 0, 0, 1, 1 );
							//float4( hash33((DataPos.www*10.+10.1)), 1. );

					float size = DataVel.w;
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
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[1]);
					pIn.uv = float2(1.0f, 1.0f);
					pIn.color = color;
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[2]);
					pIn.uv = float2(0.0f, 0.0f);
					pIn.color = color;
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[3]);
					pIn.uv = float2(0.0f, 1.0f);
					pIn.color = color;
					triStream.Append(pIn);
					triStream.RestartStrip();
				}
			}

			float4 FS_Main(g2f input) : COLOR
			{
				if( length(input.uv-0.5) > 0.5 ) discard;
				return _SpriteTex.Sample(sampler_SpriteTex, input.uv) * input.color * ( 1.- length( input.uv-0.3 ) );
			}

			ENDCG
		}
	} 
}
