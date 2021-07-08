Shader "Custom/Yeet"
{
	Properties
	{
		_TextData ("TextData", 2D) = "white" {}
		_BackgroundColor( "Background Color", Color ) = ( 0, 0, 0, 0 )
		_ForegroundColor( "Foreground Color", Color ) = ( 1, 1, 1, 1 )
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" "Queue" = "Transparent"  }
		LOD 100
		Cull Off
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog
			#pragma target 5.0
			#include "UnityCG.cginc"
			#include "/Assets/AudioLink/Shaders/SmoothPixelFont.cginc"


			#ifndef glsl_mod
			#define glsl_mod(x, y) (x - y * floor(x / y))
			#endif

			Texture2D<float4> _TextData;
			float4 _TextData_TexelSize;
			float4 _BackgroundColor;
			float4 _ForegroundColor;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float3 hitworld : TEXCOORD1;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				o.hitworld = mul( unity_ObjectToWorld, v.vertex );
				return o;
			}

			fixed4 frag (v2f i, fixed facing : VFACE , out float outDepth : SV_DepthLessEqual) : SV_Target
			{
				float2 iuv = i.uv;
				
				if( facing < 0.5 )
					iuv.x = 1.0 - iuv.x;
				iuv.y = 1.0 - iuv.y;

				// Pixel location on font pixel grid
				float2 pos = iuv * float2(_TextData_TexelSize.zw);

				// Character location as uint (floor)
				uint2 character = (uint2)pos;

				float4 dataatchar = _TextData[character];
				
				// This line of code is tricky;  We determine how much we should soften the edge of the text
				// based on how quickly the text is moving across our field of view.  This gives us realy nice
				// anti-aliased edges.
				float2 softness_uv = pos * float2( 4, 6 );
				float softness = 4./(pow( length( float2( ddx( softness_uv.x ), ddy( softness_uv.y ) ) ), 0.5 ))-1.;

				float2 charUV = float2(4, 6) - glsl_mod(pos, 1.0) * float2(4.0, 6.0);
				
				float weight = (floor(dataatchar.w)/2.-1.)*.3;
				int charVal = frac(dataatchar.w)*256;
				float4 col = lerp( lerp( _BackgroundColor, float4( 0., 0., 0., 0. ), 1. - saturate( facing ) ), _ForegroundColor, saturate( PrintChar( charVal, charUV, softness, weight )*float4(dataatchar.rgb,1.) ) );
				
				float4 clipPos = mul(UNITY_MATRIX_VP, float4(i.hitworld, 1.0));
				outDepth = clipPos.z / clipPos.w;
				
				//Tricky if we're an ortho camera don't show the backside - yeeters should behave weird with balls.
				if ((UNITY_MATRIX_P[3].x == 0.0) && (UNITY_MATRIX_P[3].y == 0.0) && (UNITY_MATRIX_P[3].z == 0.0))
				{
					if( facing < 0.5 )
					{
						outDepth = 0;
					}
				}
				return col;
			}
			ENDCG
		}
	}
}
