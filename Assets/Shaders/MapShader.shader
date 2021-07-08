// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

Shader "Custom/MapShader"
{
    Properties
    {
        _ColorA ("ColorA", Color) = (1,1,1,1)
        _ColorB ("ColorB", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _TANoiseTex ("TANoise", 2D) = "white" {}
        _TextureAnimation ("Animation Speed", float)=1.0
		_EmissionMux( "Emission Mux", Color) = (.3, .3, .3, 1. )
        _TextureDetail ("Detail", float)=1.0
		_NoisePow ("Noise Power", float ) = 1.8
		_RockAmbient ("Rock Ambient Boost", float ) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"  "DisableBatching"="True" }
        LOD 200
		
        // shadow caster rendering pass, implemented manually
        // using macros from UnityCG.cginc
        Pass
        {
            Tags {"LightMode"="ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct v2f { 
                V2F_SHADOW_CASTER;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }


        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows vertex:vert

        #pragma target 5.0

		#include "tanoise/tanoise.cginc"

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
			float3 worldPos;
			float3 worldNormal;
			float3 tangent_input;
			float3 binormal_input;
			float3 normal_input;
        };

        half _Glossiness;
        half _Metallic;
        fixed4 _ColorA, _ColorB;
		float4 _EmissionMux;
		float _TextureAnimation, _RockAmbient, _TextureDetail;
		float _NoisePow;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)


		float4 densityat( float3 calcpos )
		{
			float tim = _Time.y*_TextureAnimation;
			//calcpos.y += tim * _TextureAnimation;
			float col =
				tanoise4( float4( calcpos*float3(20.,20.,20.), tim ) ) * 3. +
				tanoise4( float4( calcpos.xyz*30.1, tim ) ) * 0.1;
			return col;
		}

		void vert(inout appdata_full i, out Input o)
		{      
			UNITY_INITIALIZE_OUTPUT(Input, o);
		 
			half3 p_normal = i.normal;
			half3 p_tangent = i.tangent.xyz;
												   
			half3 normal_input = (p_normal.xyz);
			half3 tangent_input = (p_tangent.xyz);
			half3 binormal_input = cross(p_normal.xyz,tangent_input.xyz);
					   
			o.tangent_input = tangent_input;
			o.binormal_input = binormal_input ;
			o.normal_input = p_normal;
		}


		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex);
			float3 calcpos = IN.worldPos.xyz * _TextureDetail;

			float3x3 tbn = { IN.tangent_input, IN.binormal_input, IN.normal_input };
//			o.Emission = IN.tangent_input;
//			return;
			
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;// * clamp( col.z*10.-7., 0, 1 );
			o.Alpha = c.a;

			float2 woodgrain = mul( tbn, calcpos ).xy;
			
			float2 aloc = floor( woodgrain * 2. );
			float2 delta = (woodgrain*2. - aloc) - 0.5;
			
			//calcpos *= abs( axis )*.8+ .2;
			//calcpos *= float3( 1., .1, 1. );
			float4 dat = densityat( calcpos );
			

			float amp = glsl_mod( ( length( delta )*8. + dat.x*.1 ), .5 ) * 2.0;
			float4 col = lerp( _ColorA, _ColorB, amp );
			c = c * col + _RockAmbient;
		
            o.Normal = normalize( float3( dat.xy-.35, amp + 10 ) );

			//o.Normal = float3( 0., 0., 1.0 );
			//c.xyz = glsl_mod( calcpos, 1 );
			o.Albedo = c.rgb*2.;
			o.Emission = c * _EmissionMux;
			// Metallic and smoothness come from slider variables
		}
		
        ENDCG
    }
    FallBack "Diffuse"
}
