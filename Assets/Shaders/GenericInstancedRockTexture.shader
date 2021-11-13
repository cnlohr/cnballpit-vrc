Shader "Custom/GenericInstancedRockTexture"
{
	Properties
	{
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		_TANoiseTex ("TANoise", 2D) = "white" {}
		_EmissionMux( "Emission Mux", Color) = (.3, .3, .3, 1. )
		//_InstanceID ("Instance ID", Vector ) = ( 0, 0, 0 ,0 )
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		//"DisableBatching"="False"

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
			#pragma multi_compile_instancing

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



		CGPROGRAM
		// Physically based Standard lighting model, and enable shadows on all light types
		#pragma surface surf Standard fullforwardshadows vertex:vert

		#pragma multi_compile_instancing
		// Use shader model 3.0 target, to get nicer looking lighting
		#pragma target 4.0
		#include "/Assets/cnlohr/Shaders/tanoise/tanoise.cginc"

		sampler2D _MainTex;
		
		struct Input
		{
			float2 uv_MainTex;
			float3 worldPos;
			float3 objPos;
			float4 color;
			float4 extra;
		};

		struct appdata
		{
			float4 vertex    : POSITION;  // The vertex position in model space.
			float3 normal    : NORMAL;    // The vertex normal in model space.
			float4 texcoord  : TEXCOORD0; // The first UV coordinate.
			float4 texcoord1 : TEXCOORD1; // The second UV coordinate.
			float4 texcoord2 : TEXCOORD2; // The second UV coordinate.
			float4 tangent   : TANGENT;   // The tangent vector in Model Space (used for normal mapping).
			float4 color     : COLOR;     // Per-vertex color
			UNITY_VERTEX_INPUT_INSTANCE_ID
		};

		half4 _EmissionMux;

		// Add instancing support for this shader. You need to check 'Enable Instancing' on materials that use the shader.
		// See https://docs.unity3d.com/Manual/GPUInstancing.html for more information about instancing.
		// #pragma instancing_options assumeuniformscaling
		UNITY_INSTANCING_BUFFER_START(Props)
			UNITY_DEFINE_INSTANCED_PROP( float4, _InstanceID)
		UNITY_INSTANCING_BUFFER_END(Props)
		
		
			
		float densityat( float3 calcpos, float _TextureAnimation )
		{
			float tim = _Time.y*_TextureAnimation;
		   // calcpos.y += tim * _TextureAnimation;
			float4 col =
				tanoise4_1d( float4( float3( calcpos*10. ), tim ) ) * 0.5 +
				tanoise4_1d( float4( float3( calcpos.xyz*30.1 ), tim ) ) * 0.3 +
				tanoise4_1d( float4( float3( calcpos.xyz*90.2 ), tim ) ) * 0.2 +
				tanoise4_1d( float4( float3( calcpos.xyz*320.5 ), tim ) ) * 0.1 +
				tanoise4_1d( float4( float3( calcpos.xyz*641. ), tim ) ) * .08 +
				tanoise4_1d( float4( float3( calcpos.xyz*1282. ), tim ) ) * .05;
			return col;
		}


        void vert (inout appdata v, out Input o ) {
            UNITY_INITIALIZE_OUTPUT(Input,o);
			UNITY_SETUP_INSTANCE_ID(v);

			float3 worldScale = float3(
				length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)), // scale x axis
				length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)), // scale y axis
				length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z))  // scale z axis
				);
            o.objPos = v.vertex*worldScale;
#if defined(UNITY_INSTANCING_ENABLED) || defined(UNITY_PROCEDURAL_INSTANCING_ENABLED) || defined(UNITY_STEREO_INSTANCING_ENABLED)
			int instanceid = UNITY_ACCESS_INSTANCED_PROP(Props, _InstanceID).x;
			o.extra = float4( unity_InstanceID, instanceid, 0, 1 );
#else
			o.extra = float4( 0, _InstanceID.x, 0, 1 );
#endif

        }
 
		void surf (Input IN, inout SurfaceOutputStandard o)
		{
			uint mid = UNITY_ACCESS_INSTANCED_PROP(Props, _InstanceID).x;//((uint)IN.extra.y);
			mid = mid % 10;

			const float Glossies[10] = { 0.689, 0.205, 0.187, 0.109, 0.333, 0, 0.304, 0.219, 0.357, 0.1 };
			const float Details[10] =  { 1.170, 0.57, 0.49, 0.22, 0.83, 0.48, 1, 1, 1, 1.5 };
			const float Metallics[10] = { 0, 0.446, 0.119, 0, 0, 0, 0.332, 0, 0, 0 };
			const float NoisePows[10] = { 1.8, 1.8, 1.8, 1.8, 6.17, 1.8, 1.8, 1.8, 1.8, 4.0 };
			const float Ambients[10] = { .1, .26, .1, .1, .1, .1, .1, .1, .1, .15 };
			const float Animations[10] = { 0.3, 0.3, 0.3, 0.3, 0.1, 0.3, 0.3, 0.3, 0.3, 0.25 };

			// Albedo comes from a texture tinted by color
			const float4 Colors[10] = { 
				float4( 0.5660378, 0.5660378, 0.5420079, 1 ),
				float4( 0.6320754, 0.6320754, 0.5635012, 1 ),
				float4( 0.6415094, 0.6173339, 0.5719116, 1 ),
				float4( 0.9622641, 0.9622641, 0.9622641, 1 ),
				float4( 1, 1, 1, 1 ),
				float4( 0.9245283, 0.9245283, 0.9245283, 1 ),
				float4( 0.3867925, 0.3867925, 0.370372, 1 ),
				float4( 0.8490566, 0.8490566, 0.8490566, 1 ),
				float4( 0.7264151, 0.7253463, 0.6887237, 1 ),
				float4( .9,.9,.9, 1 ) };
				

			float _Glossiness = Glossies[mid];
			float _TextureDetail = Details[mid];
			float _Metallic = Metallics[mid];
			float _TextureAnimation = Animations[mid];
			float _NoisePow = NoisePows[mid];
			float _RockAmbient = Ambients[mid];
			float4 _Color = Colors[mid];
			const float4 _EmissionMux = float4( 0, 0, 0, 1 );

			//_Color = mid;

			fixed4 c = tex2D (_MainTex, IN.uv_MainTex) * _Color;
			float3 calcpos = IN.objPos.xyz * _TextureDetail;
			
			//Pretend different instances are different places in space.
			calcpos.y += IN.extra.y;
			float4 col = densityat( calcpos, _TextureAnimation );
			c *= pow( col.xxxx, _NoisePow) + _RockAmbient;
			
			float4 normpert = tanoise4( float4( calcpos.xyz*320.5, _Time.y*_TextureAnimation ) ) * .4 +
				tanoise4( float4( calcpos.xyz*90.2, _Time.y*_TextureAnimation ) ) * .3;
			
			o.Normal = normalize( float3( normpert.xy-.35, 1.5 ) );

			//c = frac( IN.extra.y*.25+.05 ).xxxx;
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