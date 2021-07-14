Shader "cnballpit/DebugAdjacency"
{
    Properties
    {
        _Adjacency0 ("Adjacency0", 2D) = "white" {}
        _Adjacency1 ("Adjacency1", 2D) = "white" {}
        _Adjacency2 ("Adjacency2", 2D) = "black" {}
        _Adjacency3 ("Adjacency3", 2D) = "black" {}
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
					_Adjacency1[uint2(_Adjacency1_TexelSize.zw*i.uv)].x, 0, 0 );
				float4 col = float4( data.xyz/32768., 1. )/2;
				
				if( _Adjacency1[uint2(_Adjacency1_TexelSize.zw*i.uv)].w > 2 )
					col = float4( 2., 2., 2., 1. );

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
