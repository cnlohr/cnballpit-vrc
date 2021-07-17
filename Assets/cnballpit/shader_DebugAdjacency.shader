Shader "cnballpit/DebugAdjacency"
{
    Properties
    {
        _Adjacency0 ("Adjacency0", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

	
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
			#include "cnballpit.cginc"

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
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                uint4 data = _Adjacency0[uint2(_Adjacency0_TexelSize.zw*i.uv)];

				float4 col = float4( 0., 0., 0., 1. );
				
				if( data.a >= 2 )
				{
					col.x = data.a - 4;
				}
				if( data.x >= 2 )
				{
					col.y = data.x - 4;
				}
				
				col.xy/=32767;

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
