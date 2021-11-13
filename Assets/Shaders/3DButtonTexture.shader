Shader "Custom/3DButtonTexture"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _TextureDetail ("Detail", float)=1.0
        _TextureAnimation ("Animation Speed", float)=1.0
        _TANoiseTex ("TANoise", 2D) = "white" {}
        _NoisePow ("Noise Power", float ) = 1.8
        _RockAmbient ("Rock Ambient Boost", float ) = 0.1
		_EmissionMux( "Emission Mux", Color) = (.3, .3, .3, 1. )
		_SelMode( "Sel Mode", float ) = 1
		_UserEnable( "User Enable", float ) = 1
    }
    SubShader
    {
        // shadow caster rendering pass, implemented manually
        // using macros from UnityCG.cginc
        Pass
        {
            Tags {"LightMode"="ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma multi_compile_instancing
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct v2f { 
                V2F_SHADOW_CASTER;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }

        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        #pragma surface surf Standard fullforwardshadows
		#pragma multi_compile_instancing

        #pragma target 5.0

        #include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"

        sampler2D _MainTex;

        struct Input
        {
            float2 uv_MainTex;
            float3 worldPos;
			float4 screenPos;
        };

        half _Glossiness;
        half _TextureDetail;
        half _Metallic;
        half _TextureAnimation;
        half _NoisePow, _RockAmbient;
		half4 _EmissionMux;
        fixed4 _Color;
		float _SelMode;
		float _UserEnable;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)
        
        float4 densityat( float3 calcpos )
        {
            float tim = glsl_mod(_Time.y+_SelMode*10,100)*_TextureAnimation;

			float4 col_no_clamp = float4( abs( tanoise4_hq( float4( calcpos*10., tim ) ) - 0.5 ) * 10. ) * float4( 1., 1., 1., 1.);
            float4 col = glsl_mod(  col_no_clamp, 1. );
			col = pow(sin( col * 3.1415926 ), 1.2);

            return col;
        }

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Albedo comes from a texture tinted by color
            fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
            float3 calcpos = IN.worldPos.xyz * _TextureDetail;
            
            float4 col = densityat( calcpos );
			
			
			static const float4 SelColor[8] = {
				float4( 0.1, 0.1, 0.1, 1.0 ),
				float4( 1.0, 1.0, 1.0, 1.0 ),
				float4( 0.1, 1.0, 1.0, 1.0 ),
				float4( 1.0, 1.0, 0.1, 1.0 ),
				float4( 0.1, 0.1, 1.0, 1.0 ),
				float4( 1.0, 0.1, 0.1, 1.0 ),
				float4( 0.1, 1.0, 1.0, 1.0 ),
				float4( 1.0, 0.1, 1.0, 1.0 ) };
			
            c *= pow( col.xyzw, _NoisePow) + _RockAmbient;
			c *= SelColor[(uint)(_SelMode)];
            o.Normal = normalize( float3( col.x, col.y, 1.5 ) );
            
            o.Albedo = c.rgb;
			o.Emission = c * _EmissionMux;
            // Metallic and smoothness come from slider variables
            o.Metallic = _Metallic;
            o.Smoothness = _Glossiness;// * clamp( col.z*10.-7., 0, 1 );
            o.Alpha = c.a;

			if( !_UserEnable )
			{
				uint2 spos = IN.screenPos.xy/IN.screenPos.w * _ScreenParams.xy;
				clip( ((spos.x+spos.y)&1)?-1:1 );
			}
        }
        ENDCG
    }
    FallBack "Diffuse"
}