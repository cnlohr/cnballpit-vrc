Shader "mass_system/shader_lotsofballs"
{
    Properties
    {
		_BallRadius( "Ball Radius", float ) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

		ZWrite Off

        Pass
        {
		
            CGINCLUDE
			
			#include "/Assets/hashwithoutsine/hashwithoutsine.cginc"

			
            #pragma vertex MyCustomRenderTextureVertexShader
            #pragma fragment frag
			#pragma target 4.0
            #include "UnityCG.cginc"


			float _BallRadius;

			//Mostly from:
            //#include "UnityCustomRenderTexture.cginc"
			#define kCustomTextureBatchSize 16			
			texture3D<float4>   _SelfTexture3D;
			struct appdata_customrendertexture
			{
				uint    vertexID    : SV_VertexID;
			};

			// User facing vertex to fragment shader structure
			struct v2f_customrendertexture
			{
				float4 vertex           : SV_POSITION;
				float3 localTexcoord    : TEXCOORD0;    // Texcoord local to the update zone (== globalTexcoord if no partial update zone is specified)
				float3 globalTexcoord   : TEXCOORD1;    // Texcoord relative to the complete custom texture
				uint primitiveID        : TEXCOORD2;    // Index of the update zone (correspond to the index in the updateZones of the Custom Texture)
				uint primitiveIDRaw     : TEXCOORD3; 
				//float3 direction        : TEXCOORD3;    // For cube textures, direction of the pixel being rendered in the cubemap
			};

			float4      CustomRenderTextureCenters[kCustomTextureBatchSize];
			float4      CustomRenderTextureSizesAndRotations[kCustomTextureBatchSize];
			float       CustomRenderTexturePrimitiveIDs[kCustomTextureBatchSize];

			float4      CustomRenderTextureParameters;
			#define     CustomRenderTextureUpdateSpace  CustomRenderTextureParameters.x // Normalized(0)/PixelSpace(1)
			#define     CustomRenderTexture3DTexcoordW  CustomRenderTextureParameters.y
			#define     CustomRenderTextureIs3D         CustomRenderTextureParameters.z

			// User facing uniform variables
			float4      _CustomRenderTextureInfo; // x = width, y = height, z = depth, w = face/3DSlice

			// Helpers
			#define _CustomRenderTextureWidth   _CustomRenderTextureInfo.x
			#define _CustomRenderTextureHeight  _CustomRenderTextureInfo.y
			#define _CustomRenderTextureDepth   _CustomRenderTextureInfo.z

			// Those two are mutually exclusive so we can use the same slot
			#define _CustomRenderTextureCubeFace    _CustomRenderTextureInfo.w
			#define _CustomRenderTexture3DSlice     _CustomRenderTextureInfo.w


			// standard custom texture vertex shader that should always be used
			v2f_customrendertexture MyCustomRenderTextureVertexShader(appdata_customrendertexture IN)
			{
				v2f_customrendertexture OUT;

			#if UNITY_UV_STARTS_AT_TOP
				const float2 vertexPositions[6] =
				{
					{ -1.0f,  1.0f },
					{ -1.0f, -1.0f },
					{  1.0f, -1.0f },
					{  1.0f,  1.0f },
					{ -1.0f,  1.0f },
					{  1.0f, -1.0f }
				};

				const float2 texCoords[6] =
				{
					{ 0.0f, 0.0f },
					{ 0.0f, 1.0f },
					{ 1.0f, 1.0f },
					{ 1.0f, 0.0f },
					{ 0.0f, 0.0f },
					{ 1.0f, 1.0f }
				};
			#else
				const float2 vertexPositions[6] =
				{
					{  1.0f,  1.0f },
					{ -1.0f, -1.0f },
					{ -1.0f,  1.0f },
					{ -1.0f, -1.0f },
					{  1.0f,  1.0f },
					{  1.0f, -1.0f }
				};

				const float2 texCoords[6] =
				{
					{ 1.0f, 1.0f },
					{ 0.0f, 0.0f },
					{ 0.0f, 1.0f },
					{ 0.0f, 0.0f },
					{ 1.0f, 1.0f },
					{ 1.0f, 0.0f }
				};
			#endif

				uint primitiveID = IN.vertexID / 6;
				uint vertexID = IN.vertexID % 6;
				float3 updateZoneCenter = CustomRenderTextureCenters[primitiveID].xyz;
				float3 updateZoneSize = CustomRenderTextureSizesAndRotations[primitiveID].xyz;
				float rotation = CustomRenderTextureSizesAndRotations[primitiveID].w * UNITY_PI / 180.0f;

			#if !UNITY_UV_STARTS_AT_TOP
				rotation = -rotation;
			#endif

				// Normalize rect if needed
				if (CustomRenderTextureUpdateSpace > 0.0) // Pixel space
				{
					// Normalize xy because we need it in clip space.
					updateZoneCenter.xy /= _CustomRenderTextureInfo.xy;
					updateZoneSize.xy /= _CustomRenderTextureInfo.xy;
				}
				else // normalized space
				{
					// Un-normalize depth because we need actual slice index for culling
					updateZoneCenter.z *= _CustomRenderTextureInfo.z;
					updateZoneSize.z *= _CustomRenderTextureInfo.z;
				}

				// Compute rotation
				float2 clipSpaceCenter = updateZoneCenter.xy * 2.0 - 1.0;
				float2 pos = vertexPositions[vertexID] * updateZoneSize.xy;

				pos.x += clipSpaceCenter.x;
			#if UNITY_UV_STARTS_AT_TOP
				pos.y += clipSpaceCenter.y;
			#else
				pos.y -= clipSpaceCenter.y;
			#endif

				// For 3D texture, cull quads outside of the update zone
				// This is neeeded in additional to the preliminary minSlice/maxSlice done on the CPU because update zones can be disjointed.
				// ie: slices [1..5] and [10..15] for two differents zones so we need to cull out slices 0 and [6..9]
				if (CustomRenderTextureIs3D > 0.0)
				{
					int minSlice = (int)(updateZoneCenter.z - updateZoneSize.z * 0.5);
					int maxSlice = minSlice + (int)updateZoneSize.z;
					if (_CustomRenderTexture3DSlice < minSlice || _CustomRenderTexture3DSlice >= maxSlice)
					{
						pos.xy = float2(1000.0, 1000.0); // Vertex outside of ncs
					}
				}

				OUT.vertex = float4(pos, 0.0, 1.0);
				OUT.primitiveID = asuint(CustomRenderTexturePrimitiveIDs[primitiveID]);
				OUT.primitiveIDRaw = primitiveID;
				OUT.localTexcoord = float3(texCoords[vertexID], CustomRenderTexture3DTexcoordW);
				OUT.globalTexcoord = float3(pos.xy * 0.5 + 0.5, CustomRenderTexture3DTexcoordW);
			#if UNITY_UV_STARTS_AT_TOP
				OUT.globalTexcoord.y = 1.0 - OUT.globalTexcoord.y;
			#endif
				//OUT.direction = CustomRenderTextureComputeCubeDirection(OUT.globalTexcoord.xy);

				return OUT;
			}
			


			ENDCG

			Name "Initialize"
			
            CGPROGRAM
			

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint3 coord = IN.globalTexcoord.xyz * _CustomRenderTextureInfo.xyz;
				uint3 ball = floor( coord * float3( 1, 1, 0.5 ) );
				int ballid = ball.x + ball.y *_CustomRenderTextureInfo.x + ball.z * (_CustomRenderTextureInfo.y * _CustomRenderTextureInfo.y);
				
				bool is_position = 0 == ( coord.z & 1 );

				if( is_position )
				{
					return float4( hash33( IN.globalTexcoord.xyz * 10. ) * 10., ballid );
				}
				else
				{
					return float4( 0., 0., 0., _BallRadius );
				}
            }
            ENDCG
        }

		
		Pass
		{
			Name "SortX0"
			
			CGPROGRAM

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint3 coord = IN.globalTexcoord.xyz * _CustomRenderTextureInfo.xyz;
				bool is_position = !( coord.z & 1 );
				uint3 ball = coord / uint3( 1, 1, 2 );
				float4 Ap, Av, Bp, Bv, Tp, Tv;
				bool secondpixel;
				
				// Sorting X
				secondpixel = (ball.x & 1);
				ball.x &= ~1;
				
				uint3 basecoord = (ball) * uint3( 1, 1, 2 );
				Ap = _SelfTexture3D[basecoord + uint3( 0, 0, 0 )];
				Av = _SelfTexture3D[basecoord + uint3( 0, 0, 1 )];
				Bp = _SelfTexture3D[basecoord + uint3( 1, 0, 0 )];
				Bv = _SelfTexture3D[basecoord + uint3( 1, 0, 1 )];
				if( (Ap.x > Bp.x) )
				{
					Tp = Ap; Tv = Av;
					Ap = Bp; Av = Bv;
					Bp = Tp; Bv = Tv;
				}
				

				if( !secondpixel )
					return is_position?Ap:Av;
				else
					return is_position?Bp:Bv;
            }
			ENDCG
		}
		Pass
		{
			Name "SortX1"
			
			CGPROGRAM

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint3 coord = IN.globalTexcoord.xyz * _CustomRenderTextureInfo.xyz;
				bool is_position = !( coord.z & 1 );
				uint3 ball = coord / uint3( 1, 1, 2 );
				float4 Ap, Av, Bp, Bv, Tp, Tv;
				
				// Sorting X
				bool secondpixel = (ball.x & 1);
				ball.x += (ball.x&1)?1:-1;
				ball.x = ((ball.x+1) & ~1);

				uint3 basecoord = (ball) * uint3( 1, 1, 2 );
				Ap = _SelfTexture3D[basecoord + uint3( 0, 0, 0 )];
				Av = _SelfTexture3D[basecoord + uint3( 0, 0, 1 )];
				Bp = _SelfTexture3D[basecoord + int3( -1, 0, 0 )];
				Bv = _SelfTexture3D[basecoord + int3( -1, 0, 1 )];
				if( (Ap.x < Bp.x) )
				{
					Tp = Ap; Tv = Av;
					Ap = Bp; Av = Bv;
					Bp = Tp; Bv = Tv;
				}
				

				if( !secondpixel )
					return is_position?Ap:Av;
				else
					return is_position?Bp:Bv;
            }
			ENDCG
		}

		
		Pass
		{
			Name "SortY0"
			
			CGPROGRAM

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint3 coord = IN.globalTexcoord.xyz * _CustomRenderTextureInfo.xyz;
				bool is_position = !( coord.z & 1 );
				uint3 ball = coord / uint3( 1, 1, 2 );
				float4 Ap, Av, Bp, Bv, Tp, Tv;
				bool secondpixel;
				
				// Sorting Y
				secondpixel = (ball.y & 1);
				ball.y &= ~1;
				
				uint3 basecoord = (ball) * uint3( 1, 1, 2 );
				Ap = _SelfTexture3D[basecoord + uint3( 0, 0, 0 )];
				Av = _SelfTexture3D[basecoord + uint3( 0, 0, 1 )];
				Bp = _SelfTexture3D[basecoord + uint3( 0, 1, 0 )];
				Bv = _SelfTexture3D[basecoord + uint3( 0, 1, 1 )];
				if( (Ap.y > Bp.y) )
				{
					Tp = Ap; Tv = Av;
					Ap = Bp; Av = Bv;
					Bp = Tp; Bv = Tv;
				}
				if( !secondpixel )
					return is_position?Ap:Av;
				else
					return is_position?Bp:Bv;
            }
			ENDCG
		}
		Pass
		{
			Name "SortY1"
			
			CGPROGRAM

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint3 coord = IN.globalTexcoord.xyz * _CustomRenderTextureInfo.xyz;
				bool is_position = !( coord.z & 1 );
				uint3 ball = coord / uint3( 1, 1, 2 );
				float4 Ap, Av, Bp, Bv, Tp, Tv;
				
				// Sorting Y
				bool secondpixel = (ball.y & 1);
				ball.y += (ball.y&1)?1:-1;
				ball.y = ((ball.y+1) & ~1);

				uint3 basecoord = (ball) * uint3( 1, 1, 2 );
				Ap = _SelfTexture3D[basecoord + uint3( 0, 0, 0 )];
				Av = _SelfTexture3D[basecoord + uint3( 0, 0, 1 )];
				Bp = _SelfTexture3D[basecoord + int3( 0, -1, 0 )];
				Bv = _SelfTexture3D[basecoord + int3( 0, -1, 1 )];
				if( (Ap.y < Bp.y) )
				{
					Tp = Ap; Tv = Av;
					Ap = Bp; Av = Bv;
					Bp = Tp; Bv = Tv;
				}

				if( !secondpixel )
					return is_position?Ap:Av;
				else
					return is_position?Bp:Bv;
            }
			ENDCG
		}



		
		Pass
		{
			Name "SortZ0"
			
			CGPROGRAM

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint3 coord = IN.globalTexcoord.xyz * float3( 32, 32, 64 );

				bool is_position = !( coord.z & 1 );
				uint3 ball = coord / uint3( 1, 1, 2 );
				float4 Ap, Av, Bp, Bv, Tp, Tv;
				bool secondpixel;
				
				// Sorting Z
				secondpixel = (ball.z & 1);
				ball.z &= ~1;
				
				uint3 basecoord = (ball) * uint3( 1, 1, 2 );
				Ap = _SelfTexture3D[basecoord + uint3( 0, 0, 0 )];
				Av = _SelfTexture3D[basecoord + uint3( 0, 0, 1 )];
				Bp = _SelfTexture3D[basecoord + uint3( 0, 0, 2 )];
				Bv = _SelfTexture3D[basecoord + uint3( 0, 0, 3 )];
				if( (Ap.z > Bp.z) )
				{
					Tp = Ap; Tv = Av;
					Ap = Bp; Av = Bv;
					Bp = Tp; Bv = Tv;
				}

				if( !secondpixel )
					return is_position?Ap:Av;
				else
					return is_position?Bp:Bv;
            }
			ENDCG
		}
		Pass
		{
			Name "SortZ1"
			
			CGPROGRAM

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint3 coord = IN.globalTexcoord.xyz * float3( 32, 32, 64 );
				bool is_position = !( coord.z & 1 );
				uint3 ball = coord / uint3( 1, 1, 2 );
				float4 Ap, Av, Bp, Bv, Tp, Tv;
				
				// Sorting Z
				bool secondpixel = (ball.z & 1);
				ball.z += (ball.z&1)?1:-1;
				ball.z = ((ball.z+1) & ~1);

				uint3 basecoord = (ball) * uint3( 1, 1, 2 );
				Ap = _SelfTexture3D[basecoord + uint3( 0, 0, 0 )];
				Av = _SelfTexture3D[basecoord + uint3( 0, 0, 1 )];
				Bp = _SelfTexture3D[basecoord + int3( 0, 0, -2 )];
				Bv = _SelfTexture3D[basecoord + int3( 0, 0, -1 )];
				if( (Ap.z < Bp.z) )
				{
					Tp = Ap; Tv = Av;
					Ap = Bp; Av = Bv;
					Bp = Tp; Bv = Tv;
				}

				if( !secondpixel )
					return is_position?Ap:Av;
				else
					return is_position?Bp:Bv;
            }
			ENDCG
		}



		
		Pass
		{
			Name "Run Step Physics"
			
			CGPROGRAM
			
            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint3 coord = IN.globalTexcoord.xyz * _CustomRenderTextureInfo.xyz;
				uint3 ball = floor( coord * float3( 1, 1, 0.5 ) );
				
				bool is_position = 0 == ( coord.z & 1 );
				coord.z &= ~1;
				
				float4 Position = _SelfTexture3D[coord];
				float4 Velocity = _SelfTexture3D[coord + int3( 0, 0, 1 )];

				Velocity.y -= 9.8*unity_DeltaTime.x;
				
				Position.xyz = Position.xyz + Velocity.xyz * unity_DeltaTime.x;
				
				if( Position.y < 0 )
				{
					Position.y = -Position.y;
					Velocity.y = -Velocity.y * .999;
				}

				if( is_position )
				{
					return Position;
				}
				else
				{
					return Velocity;
				}
            }
			ENDCG
		}

		
		Pass
		{
			Name "NOOP"
			
			CGPROGRAM
			
            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint3 coord = IN.globalTexcoord.xyz * _CustomRenderTextureInfo.xyz;
				uint3 ball = floor( coord * float3( 1, 1, 0.5 ) );
				
				bool is_position = 0 == ( coord.z & 1 );
				coord.z &= ~1;
				
				float4 Position = _SelfTexture3D[coord];
				float4 Velocity = _SelfTexture3D[coord + int3( 0, 0, 1 )];

				if( is_position )
				{
					return Position;
				}
				else
				{
					return Velocity;
				}
            }
			ENDCG
		}


    }
}
