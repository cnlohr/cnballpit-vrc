Shader "Custom/PixelatedVideoScreen"
{
	Properties
	{
		_MainTex("Emissive (RGB)", 2D) = "white" {} //Unused
		_EmissionMap ("Texture", 2D) = "white" {}
		_ShilouetteTex ("Shilouette", 2D) = "white" {}
		_ResolutionDecimation ("Pretend Resolution Divisor", float ) = 1.0
		
		// fudge factor because of reduction in brightness fill from shilouette. This will need to be changed as a function of shilouette.
		_FillMux( "Shilouette Inverse Fill", float ) = 1.6

		_FadeInOver( "Number of LODs to fade in on", float ) = 2.0
		_IsAVProInput( "Is AV Pro Input", Int ) = 0.0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
		
		Cull Off

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


		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float2 uvorig : TEXCOORD1;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _EmissionMap;
			sampler2D _ShilouetteTex;
			float4 _EmissionMap_ST;
			float4 _EmissionMap_TexelSize;
			float _ResolutionDecimation;
			float _FillMux;
			float _FadeInOver;
			int _IsAVProInput;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uvorig = o.uv = TRANSFORM_TEX(v.uv, _EmissionMap);
				if( _IsAVProInput )
				{
					o.uv.y = 1.-o.uv.y;
				}
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}
			
			
				SamplerState samNonlinear
				{
					Filter = MIN_MAG_MIP_POINT;
					AddressU = Clamp;
					AddressV = Clamp;
				};
				
				SamplerState samLinear
				{
					Filter = MIN_MAG_MIP_LINEAR;
					AddressU = Clamp;
					AddressV = Clamp;
				};


			fixed4 frag (v2f i) : SV_Target
			{
				// sample the texture
				fixed4 col = tex2D( _EmissionMap, i.uv );

				fixed2 derivX = ddx( i.uv.xy );
				fixed2 derivY = ddy( i.uv.xy );
				float delta_max_sqr = max(dot(derivX, derivX), dot(derivY, derivY));
				float invsq = 1./sqrt(delta_max_sqr);
				float2 ftsize = _EmissionMap_TexelSize.zw / _ResolutionDecimation;
				invsq /= length( ftsize );

				//Don't aggressively show the pixels. (-.5)
				float LoD = invsq;

				if( LoD > 0.0 )
				{
					float2 pixel = i.uvorig * ftsize + 0.5;
					float2 ipixel = floor( pixel );
					float2 rloc, gloc, bloc;
					
					float3 xofs = frac(
						floor(
							float3( 
								pixel.x + 0,
								pixel.x + .25,
								pixel.x - .25 ) ) / 2. ) * 4. - 1.;

					rloc = ( pixel + float2( 0., -.2 * xofs.x ) );
					gloc = ( pixel + float2( 0.25, .25 * xofs.y ) );
					bloc = ( pixel + float2( -.25, .25 * xofs.z ) );
					
					float2 rlocfrac = frac( rloc );
					float2 glocfrac = frac( gloc );
					float2 blocfrac = frac( bloc );

					float4 colo = float4( 
						tex2D( _ShilouetteTex, rloc ).r * tex2D( _EmissionMap, i.uv - rlocfrac / ftsize ).r,
						tex2D( _ShilouetteTex, gloc ).r * tex2D( _EmissionMap, i.uv - glocfrac / ftsize ).g,
						tex2D( _ShilouetteTex, bloc ).r * tex2D( _EmissionMap, i.uv - blocfrac / ftsize ).b,
						1. ) * _FillMux; 

					float3 xs = float3( length(ddx( rloc )),length(ddx( gloc )),length(ddx( bloc )) );
					float3 ys = float3( length(ddy( rloc )),length(ddy( gloc )),length(ddy( bloc )) );
					float3 mutes = max( xs, ys );
					mutes = step( 4./LoD, mutes);
					
					colo.rgb *= 1.-mutes;

					//Lerp fade two LODs.
					col = lerp( col, colo,  min( 2., LoD )/2. );
					
				}

				if( _IsAVProInput )
				{
					col = pow( col, 2.2 );
				}

				UNITY_APPLY_FOG(i.fogCoord, col);
				return col;
			}
			ENDCG
		}
	}
}
