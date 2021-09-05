Shader "Kit/GamingBloomOutline"
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
        _ZGaussian ("Z Factor (Gaussian Blur)", Float) = 47.4
        _ZSobel ("Z Factor (Sobel)", Float) = 26.3
        _Power("SobelPower", Float) = 68.46   
		_Smoothing("Smoothing", Float) = 0.55
		_Center("Center", Float) = 0.005
		_Speed("Speed", Float) = 0.21
        _BorderRadius ("Border Radius", Float) = 11
        _LumWeight ("Lum Weight", Vector) = (5.0,0.69,0.44)
        _A2CEdge ("A2C Edges", Range(0,26.85)) = 0.4
        _AlphaWeight ("Alpha Weight", Float) = 0.4

    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent+100" "LightMode"="ForwardBase"}
  //      Pass
  //      {
   //         ZWrite On
    //        ColorMask 0
     //   }        
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
            #include "Assets/AudioLink/Shaders/AudioLink.cginc"

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
            };
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

            sampler2D _MainTex;
            float4 _MainTex_ST;
			float4 _Tint;
			float _Smoothing;
            float4 _CameraDepthTexture_TexelSize;
            float _ZGaussian;
            float _ZSobel;
            float _Power;
            float _Speed;
            float _Center;
            float _A2CEdge;
            float _AlphaWeight;

            float _BorderRadius;
            float3 _LumWeight;
            #define BORDERRADIUSf float(_BorderRadius)
            #define BORDERRADIUS22f float(_BorderRadius*_BorderRadius)

            // I'm sorry.
            static vo vop;

			// Dj Lukis.LT's oblique view frustum correction
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
      
            vo vert (vi v)
            {
                vo o;

				//Cursed mechansm to draw effect on top. https://forum.unity.com/threads/pull-to-camera-shader.459767/
                float3 pullPos = mul(unity_ObjectToWorld,v.vertex);
                // Determine cam direction (needs Normalize)
                float3 camDirection=_WorldSpaceCameraPos-pullPos; 
				float camdist = length(camDirection);
				camDirection = normalize( camDirection );
                // Pull in the direction of the camera by a fixed amount
				float dotdepth = camdist;
				float moveamount = 5;
                float near = _ProjectionParams.y*1.8; //Center of vision hits near, but extremes may exceed.
				if( moveamount > dotdepth-1 ) moveamount = dotdepth-1;
                float3 camoff = camDirection*moveamount;
                pullPos+=camoff;

                // Convert to clip space              
                o.vertex=mul(UNITY_MATRIX_VP,float4(pullPos,1));

                o.uv = v.uv;
                o.wpos = mul(unity_ObjectToWorld, v.vertex);
                o.dgpos = ComputeGrabScreenPos(o.vertex);
                o.rd.xyz = o.wpos.xyz - _WorldSpaceCameraPos.xyz + camoff;
                o.rd.w = dot(o.vertex, ObliqueFrustumCorrection);

//				//Push out Z so that this appears on top even though it's only drawing backfaces.
//				float z = o.vertex.z * o.vertex.w;
//				//z += 1.8;
//				//if( z < 3 ) z = 3;
//				float zadjust = 150;
//				z += zadjust / (1000-.3);
//				o.vertex.z = z / o.vertex.w;
                return o;
            }
            
            //shadertoy XdfGDH
            float normpdf(in float x, in float sigma)
            {
                return 0.39894*exp(-0.5*x*x/(sigma*sigma))/sigma;
            }      

            //bgolus
            float calcmiplevel(float2 texture_coord)
            {
                float2 dx = ddx(texture_coord);
                float2 dy = ddy(texture_coord);
                float delta_max_sqr = max(dot(dx, dx), dot(dy, dy));
                
                return 0.5 * log2(delta_max_sqr);
            }            

            //hsv and rgb functions
            
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

            float3 hsv2rgb_smooth(in float3 c)
            {
                float3 rgb = clamp(abs(glsl_mod(c.x*6.+float3(0., 4., 2.), 6.)-3.)-1., 0., 1.);
                return c.z*lerp(((float3)1.), rgb, c.y);
            }

            //kernel and sampling          

            float kerneledge(int a, int b)
            {
                return float(a)*exp(-float(a*a+b*b)/BORDERRADIUS22f)/BORDERRADIUSf;
            }

            float sampleDepth(float2 uv)
            {
                return sqrt((max(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv.xy),0.)));
            }

            float4 frag (vo __vo, out uint Coverage[1] : SV_Coverage) : SV_Target
            {
                vop = __vo;

                float w = 1.f / vop.vertex.w;
                float4 rd = vop.rd * w;
                float2 dgpos = vop.dgpos.xy * w;
                
                #ifdef UNITY_UV_STARTS_AT_TOP
                    dgpos.y = lerp(dgpos.y, 1 - dgpos.y, step(0, _ProjectionParams.x));
                #endif

                //Mostly adapted from d4rkplayer 
                float vdx = ddx_fine(vop.dgpos.x);   
                float vdy = ddy_fine(vop.dgpos.y);
                float aaAlpha = _A2CEdge ? vop.dgpos / length(float2(vdx,vdy)) * 0.5 : 1;
                clip(aaAlpha);
                aaAlpha = saturate(aaAlpha) * GetRenderTargetSampleCount() + 0.5;
                Coverage[0] = (1u << ((uint)(aaAlpha))) - 1u;
                
				if (IsInMirror) // Bail if in mirror.
					return float4(0.,0.,0.,0.);     

                //Compute a 13x13 gaussian blur kernel do convolution 
                const int mSize = 1;
                const int kSize = (mSize-1)/2;
                float kernel[mSize];
                const float sigma = 22;
                float rz = 0.;
                float fz = 0.;
				[unroll]
                for (int j = 0;j<=kSize; ++j)
                {
                    kernel[kSize+j] = kernel[kSize-j] = normpdf(float(j), sigma);
                }
				[unroll]
                for (int k = 0;k<mSize; ++k)
                {
                    rz += kernel[k];
                }

				[unroll]
                for (int i = -kSize;i<=kSize; ++i)
                {
					[unroll]
                    for (int j = -kSize;j<=kSize; ++j)
                    {
                        fz += kernel[kSize+j] * kernel[kSize+i] * SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, dgpos.xy + float2(float(i),float(j)) * fwidth(dgpos));
                    }
                }
                //Gaussian blurred Z
                float z = (fz/(rz*rz));

                //Compute a _BorderRadius*_BorderRadius sobel kernel do convolution 
                float colC;
                float colX = ((float3)0.);
                float colY = ((float3)0.);
                float coeffX, coeffY;
                for (i = -_BorderRadius;i<=_BorderRadius; i++)
                {
                    for (int j = -_BorderRadius;j<=_BorderRadius; j++)
                    {
                        coeffX = kerneledge(i, j);
                        coeffY = kerneledge(j, i);
                        colC = sampleDepth(dgpos.xy + float2(float(i),float(j)) * fwidth(dgpos));
                        colX += coeffX*colC;
                        colY += coeffY*colC;
                    }
                }

                //Get more precise screenspace uv derivatives. 
                float dx = ddx_fine(dgpos.x);
                float dy = ddy_fine(dgpos.y);

                //Sobel coloring      
                float derivative = sqrt(colX*colX+colY*colY)/(BORDERRADIUSf*BORDERRADIUSf);
                float angle = atan2(colY * _LumWeight, colX * _LumWeight)/(2.*UNITY_PI)+_Time.y*(1.-dx)/2.;                

				//Make it sensitive of screen resolution.
				derivative *= .0001*length( _ScreenParams.xy );

                //Setup audiolink
                float3 cw = float3(derivative, 1., 1.);
                float3 cwa = float3(angle, 1.,1.);

                //If we have audiolink, use autocorrelator for a simple hueshifting more effect.
                if(AudioLinkIsAvailable()) {
                    float cwal = AudioLinkLerp( ALPASS_AUTOCORRELATOR + float2( cw.r * AUDIOLINK_WIDTH, 0. ) )*.04;
                    cw.r += cwal;
                    cwa.r += cwal;
                }
                
                //Convert derviative and derivative with angle values to hue and alpha values.
                float3 dw = hsv2rgb_smooth(cw);
                float3 dwa = hsv2rgb_smooth(cwa);
                float dlum = pow(derivative*_LumWeight*3., 3.)*5.;
                float4 dw3 = float4(dw, dlum);
                float4 dwa3 = float4(dwa, dlum);

                // Linear depth
                float zd = z * _ZGaussian;
                float od1 = derivative * _ZSobel;

                //Compute worldspace position from depth.
                float depth = CorrectedLinearEyeDepth(zd, rd.w);
                float3 wpos = rd.xyz * depth + _WorldSpaceCameraPos.xyz;
                float3 wnorm = normalize(wpos);
                
                //First layer of color can be based off of world normal.
                float3 wcol = abs(wnorm) * 2.0 - 1.0;

                // praise bgolus
                // rescale alpha by mip level
                _Tint.a *= 1 + max(0, calcmiplevel(dgpos * _CameraDepthTexture_TexelSize.zw));
                // rescale alpha by partial derivative
                // _Tint.a = (_Tint.a) / max(fwidth(_Tint.a), 0.0001);
                
                float test = lerp(od1 - zd, _Center, _Smoothing);
                _Tint.a *= dlum * dlum;
                _Tint.a = clamp(_Tint.a, 0.0, 1.0);
                wcol = rgb2hsv(wcol);
                wcol.r += _Time.y * _Speed;
                wcol = hsv2rgb(wcol);

				wcol = clamp(wcol, 0.0, 1.0);
                test = clamp(test,0.,1.);

                test = lerp(test,sqrt(dw3.a),dx);
                test = lerp(test,sqrt(dwa3.a),dy);
                
                //Combined color.
                float4 dcol = lerp(dw3, float4(wcol.rgb, _Tint.a), dx);
                dcol = lerp(dwa3, float4(dcol.xyz,_Tint.a), dy);                
                dcol = clamp(dcol, 0.0, 1.0);             
                    
                //Compute final alpha as combination of z differences.    
                float fAlpha = lerp(dcol.a,test,od1-zd) * _AlphaWeight;
                return float4(dcol.rgb, fAlpha);
            }
            ENDCG
        }
    }
}