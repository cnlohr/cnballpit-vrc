Shader "cnballpit/DebugAdjacency"
{
    Properties
    {
        _Adjacency0 ("Adjacency0", 2D) = "white" {}
        _Adjacency1 ("Adjacency1", 2D) = "white" {}
        _Adjacency2 ("Adjacency2", 2D) = "white" {}
        _Adjacency3 ("Adjacency3", 2D) = "white" {}
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
                uint4 data = uint4(
					_Adjacency0[uint2(_Adjacency0_TexelSize.zw*i.uv)].x,
					_Adjacency1[uint2(_Adjacency1_TexelSize.zw*i.uv)].x,
					_Adjacency2[uint2(_Adjacency2_TexelSize.zw*i.uv)].x,
					_Adjacency3[uint2(_Adjacency3_TexelSize.zw*i.uv)].x );
				float4 col = float4( data.xyz/32768., 1. )/2;
				
				if( data.w != 0 )
					col = float4( 0., 1., 1., 1. );
					
				if( data.b && !data.g )
					col = float4( 1., 0., 1., 1. );

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
