Shader "Kit/GamingBloomTest"
{
    Properties
    {
		[Header(Image Settings)]
		_MainTex("Texture",2D) = "white"{}
		[Header(General settings)]
		_Tint("Tint (Alpha is transparency)", Color) = (1.0, 1.0, 1.0, 1.0)
        _ZBias ("ZBias", Float) = 0.0
        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull", Float) = 2
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Float) = 4
        [Enum(UnityEngine.Rendering.BlendMode)] _SourceBlend ("Source Blend", Float) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DestinationBlend ("Destination Blend", Float) = 10
        [Enum(Off, 0, On, 1)] _ZWrite ("ZWrite", Int) = 1       
        _Cutoff ("Alpha cutoff", Range(0,2.85)) = 0.4
        _MipScale ("Mip Level Alpha Scale", Range(0,1)) = 0.25 
        _Power("Power", Range(1, 100)) = 1.    
		_Brightness("Color Scaling", Range(0, 100)) = 0.0
		_Speed("Speed", Range(0, 3)) = 1.0

    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent+100" "LightMode"="ForwardBase"}
        Pass
        {
            ZWrite On
            ColorMask 0
        }        
        Pass
        {
            AlphaToMask On
            ZWrite [_ZWrite]
            Cull [_Cull]
            Blend [_SourceBlend] [_DestinationBlend]
            ZTest [_ZTest]    
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"

            //User beware, this file is very much WIP and comments & attributions still need to be added in.

            #define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))

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
            float4 _CameraDepthTexture_TexelSize;
            fixed _Cutoff;
            half _MipScale;
            float _Power;
            float _Speed;

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

            float3 rgb2hsv(float3 c) {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
                float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

                float d = q.x - min(q.w, q.y);
                float e = 1.0e-10;
                return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            }

            float3 hsv2rgb(float3 hsv){
                float4 t = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 p = abs(frac(hsv.xxx + t.xyz) * 6.0 - t.www);
                return hsv.z * lerp(t.xxx, clamp(p - t.xxx, 0.0, 1.0), hsv.y);
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
                o.mpos = mul(UNITY_MATRIX_M, float4(0,0,0,1));
                return o;
            }
            float CalcMipLevel(float2 texture_coord)
            {
                float2 dx = ddx(texture_coord);
                float2 dy = ddy(texture_coord);
                float delta_max_sqr = max(dot(dx, dx), dot(dy, dy));
                
                return 0.5 * log2(delta_max_sqr);
            }            

            float4 frag (vo __vo) : SV_Target
            {
                vop = __vo;
                float w = 1.f / vop.vertex.w;
                float4 rd = vop.rd * w;
                float2 dgpos = vop.dgpos.xy * w;
                #ifdef UNITY_UV_STARTS_AT_TOP
                    dgpos.y = lerp(dgpos.y, 1 - dgpos.y, step(0, _ProjectionParams.x));
                #endif
                //Gaussian Blur
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



                //Sobel
                float3x3 hCoef =
                {
                    1,  0, -1,
                    2,  0, -2,
                    1,  0, -1
                };
                float3x3 vCoef =
                {
                     1,  2,  1,
                     0,  0,  0,
                    -1, -2, -1
                };

                float4 offset[9];
                float s = z * abs(float2( ddx(dgpos.x), ddy(dgpos.y))) + fwidth(dgpos);
                offset[0] = float4(-s, -s, 0, 0);
                offset[1] = float4( 0, -s, 0, 0);
                offset[2] = float4( s, -s, 0, 0);
                offset[3] = float4(-s,  0, 0, 0);
                offset[4] = float4( 0,  0, 0, 0);
                offset[5] = float4( s,  0, 0, 0);
                offset[6] = float4(-s,  s, 0, 0);
                offset[7] = float4( 0,  s, 0, 0);
                offset[8] = float4( s,  s, 0, 0);


                float hcol = 0.0; // Horizon Color
                float vcol = 0.0; // Vertical Color
                float ocol = 0.0; // Output Color
                hcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[0])) * hCoef[0].x *_Power;
                hcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[1])) * hCoef[0].y *_Power;
                hcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[2])) * hCoef[0].z *_Power;
                hcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[3])) * hCoef[1].x *_Power;
                hcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[4])) * hCoef[1].y *_Power;
                hcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[5])) * hCoef[1].z *_Power;
                hcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[6])) * hCoef[2].x *_Power;
                hcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[7])) * hCoef[2].y *_Power;
                hcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[8])) * hCoef[2].z *_Power;
                vcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[0])) * vCoef[0].x *_Power;
                vcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[1])) * vCoef[0].y *_Power;
                vcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[2])) * vCoef[0].z *_Power;
                vcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[3])) * vCoef[1].x *_Power;
                vcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[4])) * vCoef[1].y *_Power;
                vcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[5])) * vCoef[1].z *_Power;
                vcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[6])) * vCoef[2].x *_Power;
                vcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[7])) * vCoef[2].y *_Power;
                vcol += SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (dgpos + offset[8])) * vCoef[2].z *_Power;

                ocol = sqrt(hcol * hcol + vcol * vcol);


                float depth = CorrectedLinearEyeDepth(z * ocol, rd.w);
                float depth2 = 1.0 - CorrectedLinearEyeDepth(ocol, rd.w);
                float3 wpos = rd.xyz * depth + _WorldSpaceCameraPos.xyz;
                float3 opos = mul(unity_WorldToObject, float4(wpos, 1.0));
                float3 wnorm = normalize(wpos);
                float3 onorm = normalize(opos);
                float3 col = abs(onorm) * 2.0 - 1.0;

                float3 wcol = abs(wnorm) * 2.0 - 1.0;
                float3 nor = reflect(rd,onorm);
                float dotNV = max(0,dot(nor,rd));
                float fre = pow(0.5 + clamp(dot(nor,rd),0.0,1.0),2.0) * (1.0);



                // rescale alpha by mip level
                _Tint.a *= 1 + max(0, CalcMipLevel(dgpos * _CameraDepthTexture_TexelSize.zw)) * _MipScale;
                // rescale alpha by partial derivative
                _Tint.a = (_Tint.a - _Cutoff) / max(fwidth(_Tint.a), 0.0001) + _Cutoff;
                _Tint.a = clamp(_Tint.a, 0.0, 1.0);

                col = rgb2hsv(col);
                wcol = rgb2hsv(wcol);

                col.r += _Time.y * _Speed;
                wcol.r += _Time.y * _Speed;
                col = hsv2rgb(col);
                wcol = hsv2rgb(wcol);
   
				col = clamp(col, 0.0, 1.0);
				wcol = clamp(wcol, 0.0, 1.0);
				#if UNITY_REVERSED_Z
				if (z == 0.f) {
				#else
				if (z == 1.f) {
				#endif
					// skybox
					return float4(wcol, 0.0 );
					//return float4(wcol, _Tint.a  * fre * depth2 );
                    
				}                          
                return float4(col, _Tint.a * depth2);
            }
            ENDCG
        }
    }
}