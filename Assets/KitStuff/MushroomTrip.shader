Shader "Unlit/Testing"
{
    Properties
    {
		[Header(General settings)]
		_Tint("Tint (Alpha is transparency)", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent+100"}
        Pass
        {
            ZWrite Off
            Cull Off
            Blend SrcAlpha OneMinusSrcAlpha            
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "SDFMaster.cginc"

            struct vi
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct vo
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 wpos : TEXCOORD1;
                float4 dgpos : TEXCOORD2;
                float4 rd : TEXCOORD3;
                float4 mpos : TEXCOORD4; 
            };
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

            sampler2D _MainTex;
            float4 _MainTex_ST;
			float4 _Tint;
			float _Brightness;
			float _Gamma;
			float _GradualAlpha;
            // Global access to data
            static vo vop;            

			// Dj Lukis.LT's oblique view frustum correction (VRChat mirrors use such view frustum)
			// https://github.com/lukis101/VRCUnityStuffs/blob/master/Shaders/DJL/Overlays/WorldPosOblique.shader
			#define UMP UNITY_MATRIX_P
			inline float4 CalculateObliqueFrustumCorrection()
			{
				float x1 = -UMP._31 / (UMP._11 * UMP._34);
				float x2 = -UMP._32 / (UMP._22 * UMP._34);
				return float4(x1, x2, 0, UMP._33 / UMP._34 + x1 * UMP._13 + x2 * UMP._23);
			}
			static float4 ObliqueFrustumCorrection = CalculateObliqueFrustumCorrection();
			inline float CorrectedLinearEyeDepth(float z, float correctionFactor)
			{
				return 1.f / (z / UMP._34 + correctionFactor);
			}
			// Merlin's mirror detection
			inline bool CalculateIsInMirror()
			{
				return UMP._31 != 0.f || UMP._32 != 0.f;
			}
			static bool IsInMirror = CalculateIsInMirror();
			#undef UMP
            float normpdf(in float x, in float sigma)
            {
                return 0.39894*exp(-0.5*x*x/(sigma*sigma))/sigma;
            }            
            vo vert (vi v)
            {
                vo o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.wpos = mul(unity_ObjectToWorld, v.vertex);
                o.dgpos = ComputeGrabScreenPos(o.vertex);
                o.rd.xyz = o.wpos.xyz - _WorldSpaceCameraPos.xyz;
                o.rd.w = dot(o.vertex, ObliqueFrustumCorrection);
                o.mpos = mul(unity_ObjectToWorld, float4(0,0,0,1));
                return o;
            }

            float4 frag (vo __vo) : SV_Target
            {
                vop = __vo;
                float w = 1.f / vop.vertex.w;
                float4 rd = vop.rd * w;
                float2 dgpos = vop.dgpos.xy * w;

                const int mSize = 11;
                const int kSize = (mSize-1)/2;
                float kernel[mSize];
                float sigma = 7.;
                float rz = 0.;
                float fz = 0.;
                for (int j = 0;j<=kSize; ++j)
                {
                    kernel[kSize+j] = kernel[kSize-j] = normpdf(float(j), sigma);
                }
                for (int k = 0;k<mSize; ++k)
                {
                    rz += kernel[k];
                }

                for (int i = -kSize;i<=kSize; ++i)
                {
                    for (int j = -kSize;j<=kSize; ++j)
                    {
                        fz += kernel[kSize+j] * kernel[kSize+i] * SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, dgpos.xy + float2(float(i),float(j)) * fwidth(dgpos));
                    }
                }

                float z = (fz/(rz*rz));
				// #if UNITY_REVERSED_Z
				// if (z == 0.f) {
				// #else
				// if (z == 1.f) {
				// #endif
				// 	// skybox
				// 	return float4(0.f, 0.f, 0.f, 1.f);
				// }
                float depth = CorrectedLinearEyeDepth(z, rd.w);
                float3 wpos = rd.xyz * depth + _WorldSpaceCameraPos.xyz;
                float4 opos = mul(unity_WorldToObject, float4(wpos, 1.0));
                float dist = distance(wpos, vop.vertex);
                opos.xyz /= opos.w;
                float fade = max(0,0.5 - opos.z);
                float3 wnorm = normalize(wpos);
                float3 col = abs(wnorm);
                col = rgb2hsv(col);
                col.r += _Time.y;
                col = hsv2rgb(col);
				col = clamp(col, 0.0, 1.0);             
				#if UNITY_REVERSED_Z
				if (z == 0.f) {
				#else
				if (z == 1.f) {
				#endif
					// skybox
					return float4(col, 1.0);
				}
                col = snoise_grad(abs(wpos));
                col = rgb2hsv(col);
                col.r += _Time.y;
                col = hsv2rgb(col);
				col = clamp(col, 0.0, 1.0);                     
                // col = spectrum03(fCircle(wpos, depth));
                // col = rgb2hsv(col);
                // col.r += _Time.y;
                // col = hsv2rgb(col);
				// col = clamp(col, 0.0, 1.0);                       
                return float4(col, 1.0);
            }
            ENDCG
        }
    }
}