//Aurora originally by nimitz (see below) later modified by SCRN.
//CNLohr modded for a few perf tweaks.
Shader "Unlit/BlackSkybox"
{
	Properties
	{
		_MainTex ("MainTex", 2D) = "black" {}
		_MatCap ("MatCap", 2D) = "black" {}
		_Position ("Position", Vector) = (0.0,0.05,0.0)
		_TANoiseTex ("TANoise", 2D) = "white" {}
	}
	Subshader
	{
        // shadow caster rendering pass, implemented manually
        // using macros from UnityCG.cginc

		Tags { "RenderType"="Background" "PreviewType"="Skybox" "Queue"="Background"  }
	//	Cull Back
		Lighting Off
	//	SeparateSpecular Off
	    Cull Off ZWrite Off
		Fog { Mode Off }
		Pass
		{
			CGPROGRAM
			#pragma vertex vertex_shader
			#pragma fragment pixel_shader
			#pragma target 5.0
			#pragma fragmentoption ARB_precision_hint_fastest

			fixed3 _Position;
			sampler2D _TexOut;
			fixed2 varInput;

            float4 _NoiseTex_ST;

			struct custom_type
			{
				fixed4 screen_vertex : SV_POSITION;
				//fixed2 uv : TEXCOORD0;
				fixed3 world_vertex : TEXCOORD1;
				fixed3 pixel_input : TEXCOORD3;
				fixed3 sNormal : TEXCOORD2;
			};

			custom_type vertex_shader (fixed4 vertex : POSITION, fixed2 uv:TEXCOORD0, fixed3 normal : NORMAL)
			{
				custom_type vs;
				vs.screen_vertex = UnityObjectToClipPos (vertex);
				//vs.uv = uv - 0.5;
				vs.world_vertex = mul(unity_ObjectToWorld, vertex);
				return vs;
			}

			fixed4 pixel_shader (custom_type ps) : SV_TARGET
			{
				return 0.;
			}
			ENDCG
		}
	}
	Fallback "Diffuse"
}