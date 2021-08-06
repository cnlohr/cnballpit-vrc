Shader "SuperPalm/ballpit_palmtree"
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
		_BarkColor( "Bark Color", Color ) = (1., 1., 1. ,1. )
		
		_FrawnDensity( "Frawn Density", float) = 300
	}
    SubShader
    {
		
		CGINCLUDE
		
		float _FrawnDensity;
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
		ENDCG

		// shadow caster rendering pass, implemented manually
		// using macros from UnityCG.cginc
		Pass
		{
			Tags {"LightMode"="ShadowCaster"}
			Cull Off
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma multi_compile_instancing
			#include "UnityCG.cginc"

			struct v2f { 
				V2F_SHADOW_CASTER;
				float4 uv : TEXCOORD0;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
				o.uv = v.texcoord;
				return o;
			}

			float4 frag(v2f i) : SV_Target
			{
				float edginess = 1.;
				float alpha = FragmentAlpha( i.uv, edginess );
				clip( alpha-0.5 );
				SHADOW_CASTER_FRAGMENT(i)
			}
			ENDCG
		}


		Tags{ "RenderType" = "TransparentCutout"  "Queue" = "AlphaTest+0" "IsEmissive" = "true"  }
		AlphaToMask On
		Cull Off
		ZWrite On		AlphaToMask On

        CGPROGRAM
        // Physically based Standard lighting model, and enable shadows on all light types
        //#pragma surface surf keepalpha Standard fullforwardshadows vertex:vert
		#pragma surface surf Standard keepalpha addshadow fullforwardshadows vertex:vert 
		#pragma multi_compile_instancing


        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 4.0
		#include "/Assets/Shaders/tanoise/tanoise.cginc"

        sampler2D _MainTex;

   
		struct Input
		{
			float2 uv_MainTex;
			float2 uv2_MainTex;
			float3 worldPos;
			float3 objPos;
			float3 color;
		};

		half _TextureDetail;
		half _TextureAnimation;
		half _NoisePow, _RockAmbient;
		half4 _EmissionMux;
		half4 _BarkColor;
        half _Glossiness;
        half _Metallic;
        fixed4 _Color;

        // Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
        // See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
        // #pragma instancing_options assumeuniformscaling
        UNITY_INSTANCING_BUFFER_START(Props)
            // put more per-instance properties here
        UNITY_INSTANCING_BUFFER_END(Props)



        void vert (inout appdata_full v, out Input o) {
            UNITY_INITIALIZE_OUTPUT(Input,o);
		    float3 worldScale = float3(
				length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)), // scale x axis
				length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)), // scale y axis
				length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z))  // scale z axis
				);
            o.objPos = v.vertex*worldScale;
			o.color = v.color;
        }

		float densityat( float3 calcpos )
		{
			float tim = _Time.y*_TextureAnimation;
		   // calcpos.y += tim * _TextureAnimation;
			float4 col =
				tanoise4_1d( float4( float3( calcpos*10. ), tim ) ) * 0.5 +
				tanoise4_1d( float4( float3( calcpos.xyz*30.1 ), tim ) ) * 0.3 +
				tanoise4_1d( float4( float3( calcpos.xyz*90.2 ), tim ) ) * 0.2 +
				tanoise4_1d( float4( float3( calcpos.xyz*320.5 ), tim ) ) * 0.1 +
				tanoise4_1d( float4( float3( calcpos.xyz*641. ), tim ) ) * .08 +
				0;
			return col;
		}
		
		#define SIGMOID(x) ( 1./(1.+exp(-(x))))


        void surf (Input IN, inout SurfaceOutputStandard o)
        {
			// Albedo comes from a texture tinted by color
			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;

			float3 calcpos = IN.objPos.xyz * _TextureDetail;
			float4 col = 0.;
			float2 normpert;
			
			if( IN.uv_MainTex.y <= 0.00 )
			{
				// Bark
				float2 uvoffset = .36;
				float segmentuv = glsl_mod( IN.uv_MainTex.y*8+uvoffset, 1. );
				float segmentno = floor( IN.uv_MainTex.y*8+uvoffset );
				
				float3 compos = float3( IN.uv_MainTex.x*1.5, SIGMOID( segmentuv*10.-5 )*.101 + segmentno*.1, 0 );
				
				float4 nrv = tanoise4( float4( compos.xyz*90.2, _Time.y*_TextureAnimation ) ) * .3;
				nrv = smoothstep( 0, 1, nrv );
				c = _BarkColor;
				c = c * ( pow( floor( (nrv.x + .9)*12 )/9,2 ) + nrv.y*.2);
				c = c * pow( abs( segmentuv.x - 0.5 ) + 0.1, .45); //ribs
				//Add some noise to the normal.
				normpert = tanoise4( float4( compos.xyz*200.5, _Time.y*_TextureAnimation ) ) * .4 +
					tanoise4( float4( compos.xyz*90.2, _Time.y*_TextureAnimation ) ) * .3;
				
			}
			else if( IN.uv_MainTex.y < 0.5 )
			{
				//Brown nub.
				//c = _BarkColor;
				normpert.xy = 0.35;
			}
			else
			{
				// Leaf
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
				
			}
			o.Occlusion = IN.color * lerp( normalize( c ), 1..xxx, .2 )*2;

			float edginess = 0.022/length( ddx( IN.objPos.xyz ) ) + length( ddy( IN.objPos.xyz ) );
			c.a = FragmentAlpha( IN.uv_MainTex, edginess );
			

			o.Normal = normalize( float3( normpert.xy-.35, 1.5 ) );
			o.Albedo = c.rgb * 1.2;
			o.Emission = c * _EmissionMux;
			// Metallic and smoothness come from slider variables
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;// * clamp( col.z*10.-7., 0, 1 );
			o.Alpha = c.a;
        }
        ENDCG
    }
    FallBack "Diffuse"
}
