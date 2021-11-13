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
		_FrawnDensity( "Frawn Density", float) = 300
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"  "DisableBatching"="True" }
        LOD 200
		
		CGINCLUDE
		
		#include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"

		float _FrawnDensity;
        half _Glossiness;
        half _Metallic;
        fixed4 _ColorA, _ColorB;
		float4 _EmissionMux;
		float _TextureAnimation, _RockAmbient, _TextureDetail;
		float _NoisePow;

		float FragmentAlpha( float2 uv, float edginess )
		{
		
			if( uv.y < 0.49 )
			{
				return 1;
			}
			else
			{
				float fLeafOffset = (uv.y-.75)*4;
				float fLeafAlongLength = uv.x;
				float fLeafCenterDistance = abs( fLeafOffset );
				//float alpha = (( sin( fLeafAlongLength * _FrawnDensity ) + 1.2 )); //Sin-based frawning
				float alpha = 1.-abs( 0.5 - frac( fLeafAlongLength * _FrawnDensity / 6.2 ) )*2.;
				alpha += saturate( .5 - fLeafCenterDistance*2 )*3.; //center stem
				alpha *= saturate(1.5-fLeafCenterDistance*1.5);
				alpha *= saturate(1.7-fLeafAlongLength);
				return ( (alpha-.05)*9. - 0.5 ) * edginess + 0.5;
			}
		}
		


		float4 densityat( float3 calcpos )
		{
			float tim = _Time.y*_TextureAnimation;
			//calcpos.y += tim * _TextureAnimation;
			float col =
				tanoise4( float4( calcpos*float3(20.,20.,20.), tim ) ) * 3. +
				tanoise4( float4( calcpos.xyz*30.1, tim ) ) * 0.1;
			return col;
		}
		
		ENDCG
		
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


        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)


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
			float2 uv = IN.uv_MainTex;
			// Albedo comes from a texture tinted by color
			fixed4 c = 1.;
			float3 calcpos = IN.worldPos.xyz * _TextureDetail;

		
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;


			//if( uv.x < 0.5 || uv.y < 0.5 )
			if( true )
			{
				//float3x3 tbn;
				float2 extradetail = 0;
				if( uv.x < 0.5 )
				{
					//Poles
					extradetail = float2( 50., 0 );
				}
				else
				{
					extradetail = float2( 10, 0 );
				}
				
				o.Alpha = c.a;

				float2 woodgrain = uv*extradetail;//mul( tbn, calcpos * extradetail ).xy;
				float2 aloc = floor( woodgrain * 2. );
				float2 delta = (woodgrain*2. - aloc) - 0.5;
				
				float4 dat = densityat( calcpos * length(extradetail) );

				float amp = glsl_mod( ( length( delta )*8. + dat.x*.1 ), .5 ) * 2.0;
				float4 col = lerp( _ColorA, _ColorB, amp );
				c = c * col + _RockAmbient;
				
				
				// Compute a LoD to blur it out over distance.
				fixed2 derivX = ddx( uv.xy*extradetail );
				fixed2 derivY = ddy( uv.xy*extradetail );
				float delta_max_sqr = max(dot(derivX, derivX), dot(derivY, derivY));
				float invsq = 1./sqrt(delta_max_sqr);
				float2 ftsize = 8;
				invsq /= length( ftsize );

				//Don't aggressively show the pixels. (-.5)
				float LoD = invsq - 0.5;
				
				float closeness_to_edge = 1.-(abs( amp - 0.5 ))*2.;
				LoD = saturate( LoD*1. + closeness_to_edge*4. - 3. );
				c = lerp( _ColorA*.7+0.1, c, LoD );
				//c = LoD;
				o.Normal = normalize( float3( dat.xy-.35, amp + 20 ) );

				o.Albedo = c.rgb*2.;
				o.Emission = c * _EmissionMux;
			}
			else
			{
				float3 normpert;
				float4 col = 0.;
				//uv = >0.5,>0.5
				normpert.xy = 0.35;
				float fLeafOffset = (IN.uv_MainTex.y-.75)*4;
				float fLeafAlongLength = IN.uv_MainTex.x;
				float fLeafCenterDistance = abs( fLeafOffset );
				//col = densityat( calcpos );
				//col = saturate( pow( sin( IN.uv_MainTex.x*100. +IN.uv_MainTex.y*20. )* .2 + 1.0, 10. ) );
				c *= 8.;
				c *= pow( col.xxxx, _NoisePow) + _RockAmbient;
				//Brownness
				c += float4( .08, 0., .07, 0. ) * fLeafCenterDistance * ( tanoise4_1d( float4( float3( calcpos*30. ), _Time.y ) ).xxxx + .8 );
				normpert = tanoise4( float4( calcpos.xyz*10.2, _Time.y*_TextureAnimation ) ) * .1;

				o.Albedo = c.rgb;
				o.Normal = float3( 0., 1., 0. );
				o.Emission = 0;
				//o.Alpha = FragmentAlpha( ;
			}
			// Metallic and smoothness come from slider variables
		}
		
        ENDCG
    }
    FallBack "Diffuse"
}
