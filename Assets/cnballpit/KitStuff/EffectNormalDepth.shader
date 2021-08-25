Shader "Effects/WorldSpace"
{
	//Shader from https://gist.github.com/netri/8f48994252f3437d9a22c9ae82cb9cb2
	Properties
	{
	}
	SubShader
	{
        Tags { "RenderType"="Transparent" "Queue"="Transparent+100" "LightMode"="ForwardBase"}
  
        Pass
        {
            AlphaToMask On
            ZWrite Off
            Cull Front
            Blend SrcAlpha OneMinusSrcAlpha
		
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
            #pragma target 5.0
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};
			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 worldDirection : TEXCOORD0;
				float4 screenPosition : TEXCOORD1;
			};

			sampler2D _CameraDepthTexture;

			v2f vert (appdata v)
			{
				v2f o;

				//Normally, we would do this:
				//o.vertex = UnityObjectToClipPos(v.vertex);
				//But...
				//Cursed mechansm to draw effect on top. https://forum.unity.com/threads/pull-to-camera-shader.459767/
                float3 pullPos = mul(unity_ObjectToWorld,v.vertex);
                // Determine cam direction (needs Normalize)
                float3 camDirection=_WorldSpaceCameraPos-pullPos; 
				float camdist = length(camDirection);
				camDirection = normalize( camDirection );
                // Pull in the direction of the camera by a fixed amount
				float dotdepth = camdist;
				float moveamount = 5;
				float near = _ProjectionParams.y*1.8;  //Center of vision hits near, but extremes may exceed.
				if( moveamount > dotdepth-near ) moveamount = dotdepth-near;
				float3 camoff = camDirection*moveamount;
                pullPos+=camoff;
                o.vertex=mul(UNITY_MATRIX_VP,float4(pullPos,1));


				// Subtract camera position from vertex position in world
				// to get a ray pointing from the camera to this vertex.
				o.worldDirection = mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos + camoff;

				// Save the clip space position so we can use it later.
				// (There are more efficient ways to do this in SM 3.0+, 
				// but here I'm aiming for the simplest version I can.
				// Optimized versions welcome in additional answers!)
				o.screenPosition = o.vertex;//UnityObjectToClipPos(v.vertex);

				// Done.
				return o;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				// Compute projective scaling factor...
				float perspectiveDivide = 1.0f / i.screenPosition.w;

				// Scale our view ray to unit depth.
				float3 direction = i.worldDirection * perspectiveDivide;

				// Calculate our UV within the screen (for reading depth buffer)
				float2 screenUV = (i.screenPosition.xy * perspectiveDivide) * 0.5f + 0.5f;

				if (_ProjectionParams.x < 0)
					screenUV.y = 1 - screenUV.y; 

				// VR stereo support
				screenUV = UnityStereoTransformScreenSpaceTex(screenUV);

				// Read depth, linearizing into worldspace units.    
				float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV)));

				// Discard 
				clip( depth >= 999 ? -1 : 1 );

				float WPthis  = direction * LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV + float2( 1./_ScreenParams.x, 0 ) )));
				float WPleft  = (direction - ddx_fine( direction ) ) * LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV + float2(-1./_ScreenParams.x, 0 ) )));
				float WPright = (direction + ddx_fine( direction ) ) * LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV + float2( 0, 0 ) )));
				float WPup    = (direction - ddy_fine( direction ) ) * LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV + float2( 0, 1./_ScreenParams.y ) )));
				float WPdown  = (direction + ddy_fine( direction ) )* LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV + float2( 0,-1./_ScreenParams.y ) )));
				
				float3 deltas = 0.;
				if( abs( WPthis - WPleft ) < abs( WPright - WPthis ) )
					deltas.x = WPthis - WPleft;
				else
					deltas.x = WPright - WPthis;

				if( abs( WPthis - WPup ) < abs( WPdown - WPthis ) )
					deltas.y = WPthis - WPup;
				else
					deltas.y = WPdown - WPthis;

				deltas.z = .01;
				
				//deltas = mul( UNITY_MATRIX_MV, deltas.xzy );

				deltas = normalize( deltas );

				// Draw a worldspace tartan pattern over the scene to demonstrate.
				return float4( abs(deltas), 1.0f);
			}

			ENDCG
		}
	}
}