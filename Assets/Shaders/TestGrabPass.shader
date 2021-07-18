Shader "Unlit/TestGrabPass"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }

		Cull Front
        LOD 100

        GrabPass
        {
            "_GrabTexture"
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
				float4 grabposs : TEXCOORD1;
            };

            sampler2D _GrabTexture;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
				o.grabposs = ComputeGrabScreenPos(o.vertex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture

				float4 col = 0;
				float dx, dy;
				float muxsum = 0;
				for( dy = -6; dy <= 6; dy++ )
				for( dx = -6; dx <= 6; dx++ )
				{
					float mux = 1./(length(float2(dx,dy))+2)-.1;
					mux = max( mux, 0 );
					muxsum += mux;
					col += tex2Dproj(_GrabTexture, i.grabposs + float4( float2(dx,dy)/_ScreenParams.xy, 0, 0 ) ) * mux;
				}
				col /= muxsum;
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
