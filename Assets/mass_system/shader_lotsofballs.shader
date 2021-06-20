Shader "mass_system/shader_lotsofballs"
{
    Properties
    {
		_BallRadius( "Ball Radius", float ) = 0.1
        _DepthMapAbove ("Above Depth", 2D) = "white" {}
        _DepthMapBelow ("Below Depth", 2D) = "white" {}
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
			texture2D<float4>   _SelfTexture2D;
			float4   _SelfTexture2D_TexelSize;
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
				//XXX CNL - Fix this Z component.
				OUT.localTexcoord = float3(texCoords[vertexID], CustomRenderTexture3DTexcoordW ); //+ 0.5/_CustomRenderTextureInfo.z);
				OUT.globalTexcoord = float3(pos.xy * 0.5 + 0.5, CustomRenderTexture3DTexcoordW ); //+ 0.5/_CustomRenderTextureInfo.z);
			#if UNITY_UV_STARTS_AT_TOP
				OUT.globalTexcoord.y = 1.0 - OUT.globalTexcoord.y;
			#endif
				//OUT.direction = CustomRenderTextureComputeCubeDirection(OUT.globalTexcoord.xy);

				return OUT;
			}
			
			
			static const int3 balldims = uint3( 32, 32, 32 );

			float4 GetBD( uint3 coord, uint dataid )
			{
				return _SelfTexture2D[uint2(coord.x+coord.y*balldims.x,coord.z*2+dataid)];
			}
			
			texture2D<float> _DepthMapAbove;
			float4 _DepthMapAbove_TexelSize;
			texture2D<float> _DepthMapBelow;
			float4 _DepthMapBelow_TexelSize;

			ENDCG

			Name "Initialize"
			
            CGPROGRAM
			

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint2 coord = IN.globalTexcoord.xy * _SelfTexture2D_TexelSize.zw;
				uint3 ball = uint3( coord.x % balldims.x, coord.x / balldims.x, coord.y / 2 );
				int ballid = ball.x + ( ball.y + ball.z * balldims.y ) * balldims.x;
				
				bool is_position = 0 == ( coord.y & 1 );

				if( is_position )
				{
					return float4( hash33( ball ) * 10., _BallRadius );
				}
				else
				{
					return float4( 0., 0., 0., ballid );
				}
            }
            ENDCG
        }

		
		Pass
		{
			Name "InitializeIfNotInitialized"
			
			CGPROGRAM

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint2 coord = IN.globalTexcoord.xy * _SelfTexture2D_TexelSize.zw;
				float4 st = _SelfTexture2D[coord];
				if( st.x == 0 && st.y == 0 && st.z == 0 && st.w == 0 )
				{
					
					uint2 coord = IN.globalTexcoord.xy * _SelfTexture2D_TexelSize.zw;
					uint3 ball = uint3( coord.x % balldims.x, coord.x / balldims.x, coord.y / 2 );
					int ballid = ball.x + ( ball.y + ball.z * balldims.y ) * balldims.x;
					
					bool is_position = 0 == ( coord.y & 1 );

					if( is_position )
					{
						return float4( hash33( ball ) * 10., _BallRadius );
					}
					else
					{
						return float4( 0., 0., 0., ballid );
					}
				}
				return _SelfTexture2D[coord];


            }
			ENDCG
		}
		Pass
		{
			Name "SortX0"
			
			CGPROGRAM

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint2 coord = IN.globalTexcoord.xy * _SelfTexture2D_TexelSize.zw;
				uint3 ball = uint3( coord.x % balldims.x, coord.x / balldims.x, coord.y / 2 );
	
				bool is_position = !(coord.y & 1);

				float4 Ap, Av, Bp, Bv, Tp, Tv;
				bool secondpixel;
				
				// Sorting X
				secondpixel = (ball.x & 1);
				
				ball.x &= ~1;
				Ap = GetBD( ball + uint3( 0, 0, 0 ), 0 );
				Av = GetBD( ball + uint3( 0, 0, 0 ), 1 );
				Bp = GetBD( ball + uint3( 1, 0, 0 ), 0 );
				Bv = GetBD( ball + uint3( 1, 0, 0 ), 1 );
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
				uint2 coord = IN.globalTexcoord.xy * _SelfTexture2D_TexelSize.zw;
				uint3 ball = uint3( coord.x % balldims.x, coord.x / balldims.x, coord.y / 2 );
	
				if( ball.x < 1 || ball.x > balldims.x-2 ) return _SelfTexture2D[coord];
	
				bool is_position = !(coord.y & 1);

				float4 Ap, Av, Bp, Bv, Tp, Tv;
				bool secondpixel;
				
				// Sorting X
				secondpixel = !(ball.x & 1);
				
				ball.x = ( ( ball.x + 1 ) & ~1 ) - 1;
				Ap = GetBD( ball + uint3( 0, 0, 0 ), 0 );
				Av = GetBD( ball + uint3( 0, 0, 0 ), 1 );
				Bp = GetBD( ball + uint3( 1, 0, 0 ), 0 );
				Bv = GetBD( ball + uint3( 1, 0, 0 ), 1 );
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
			Name "SortY0"
			
			CGPROGRAM

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint2 coord = IN.globalTexcoord.xy * _SelfTexture2D_TexelSize.zw;
				uint3 ball = uint3( coord.x % balldims.x, coord.x / balldims.x, coord.y / 2 );
	
				bool is_position = !(coord.y & 1);

				float4 Ap, Av, Bp, Bv, Tp, Tv;
				bool secondpixel;
				
				// Sorting Y
				secondpixel = (ball.y & 1);
				
				ball.y &= ~1;
				Ap = GetBD( ball + uint3( 0, 0, 0 ), 0 );
				Av = GetBD( ball + uint3( 0, 0, 0 ), 1 );
				Bp = GetBD( ball + uint3( 0, 1, 0 ), 0 );
				Bv = GetBD( ball + uint3( 0, 1, 0 ), 1 );
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
				uint2 coord = IN.globalTexcoord.xy * _SelfTexture2D_TexelSize.zw;
				uint3 ball = uint3( coord.x % balldims.x, coord.x / balldims.x, coord.y / 2 );
	
				if( ball.y < 1 || ball.y > balldims.y-2 ) return _SelfTexture2D[coord];
	
				bool is_position = !(coord.y & 1);

				float4 Ap, Av, Bp, Bv, Tp, Tv;
				bool secondpixel;
				
				// Sorting Y
				secondpixel = !(ball.y & 1);
				
				ball.y = ( ( ball.y + 1 ) & ~1 ) - 1;
				Ap = GetBD( ball + uint3( 0, 0, 0 ), 0 );
				Av = GetBD( ball + uint3( 0, 0, 0 ), 1 );
				Bp = GetBD( ball + uint3( 0, 1, 0 ), 0 );
				Bv = GetBD( ball + uint3( 0, 1, 0 ), 1 );
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
			Name "SortZ0"
			
			CGPROGRAM

            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint2 coord = IN.globalTexcoord.xy * _SelfTexture2D_TexelSize.zw;
				uint3 ball = uint3( coord.x % balldims.x, coord.x / balldims.x, coord.y / 2 );
	
				bool is_position = !(coord.y & 1);

				float4 Ap, Av, Bp, Bv, Tp, Tv;
				bool secondpixel;
				
				// Sorting Z
				secondpixel = (ball.z & 1);
				
				ball.z &= ~1;
				Ap = GetBD( ball + uint3( 0, 0, 0 ), 0 );
				Av = GetBD( ball + uint3( 0, 0, 0 ), 1 );
				Bp = GetBD( ball + uint3( 0, 0, 1 ), 0 );
				Bv = GetBD( ball + uint3( 0, 0, 1 ), 1 );
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
				uint2 coord = IN.globalTexcoord.xy * _SelfTexture2D_TexelSize.zw;
				uint3 ball = uint3( coord.x % balldims.x, coord.x / balldims.x, coord.y / 2 );
	
				if( ball.z < 1 || ball.z > balldims.z-2 ) return _SelfTexture2D[coord];
	
				bool is_position = !(coord.y & 1);

				float4 Ap, Av, Bp, Bv, Tp, Tv;
				bool secondpixel;
				
				// Sorting Z
				secondpixel = !(ball.z & 1);
				
				ball.z = ( ( ball.z + 1 ) & ~1 ) - 1;
				Ap = GetBD( ball + uint3( 0, 0, 0 ), 0 );
				Av = GetBD( ball + uint3( 0, 0, 0 ), 1 );
				Bp = GetBD( ball + uint3( 0, 0, 1 ), 0 );
				Bv = GetBD( ball + uint3( 0, 0, 1 ), 1 );
				if( (Ap.z > Bp.z ) )
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
			
			
			inline float DebufferizeDepth( float z )
			{
				const float near = 1;
				const float far = 20;
				//const float4 zbp = float4( 1-far/near, far/near, (1-far/near)/far, (far/near)/far );
				//return 1.0 / (zbp.z * z + zbp.w);
				//return 1.0 / ( z + 1 );
				return z * 20;
			}


            float4 frag (v2f_customrendertexture IN) : SV_Target
            {
				uint2 coord = IN.globalTexcoord.xy * _SelfTexture2D_TexelSize.zw;
				uint3 ball = uint3( coord.x % balldims.x, coord.x / balldims.x, coord.y / 2 );
	
				bool is_position = !(coord.y & 1);

				float4 Position = GetBD( ball, 0 );
				float4 Velocity = GetBD( ball, 1 );

				const float cfmVelocity = 4.8;
				const float cfmPosition = .01;

				// Step 1 find collisions.
				const int3 neighborhood = int3( 7, 15, 7 );
				int3 ballneighbor;
				for( ballneighbor.x = -neighborhood.x; ballneighbor.x <= neighborhood.x; ballneighbor.x++ )
				for( ballneighbor.y = -neighborhood.y; ballneighbor.y <= neighborhood.y; ballneighbor.y++ )
				for( ballneighbor.z = -neighborhood.z; ballneighbor.z <= neighborhood.z; ballneighbor.z++ )
				{
					int3 ab = ballneighbor + ball;
					bool3 okvec = ab >= 0 && ab < balldims;
					if( okvec.x && okvec.y && okvec.z )
					{
						float4 otherball = GetBD( ab, 0 );
						float len = length( Position.xyz - otherball.xyz );
						
						//Do we collide AND are we NOT the other ball?
						if( len < otherball.w + Position.w && len > 0.01 )
						{
							// Collision! (Todo, smarter)
							// We only edit us, not the other ball.
							float penetration = ( otherball.w + Position.w ) - len;
							float3 vectortome = normalize(Position.xyz - otherball.xyz);
							Velocity.xyz += penetration * vectortome * cfmVelocity;
							Position.xyz += penetration * vectortome * cfmPosition;
							Velocity.xyz *= 1;
						}
					}
				}
				
				//Collide with edges.
				
				static const float edgecfm = 1.5;
				static const float edgecfmv = 3.5;
				
				// A bowl (not in use right now)
				if( 0 )
				{
					//Bowl Collision.
					float3 bowlcenter = float3( 0., 31., 0. );
					float bowlradius = 30;				
					float exitlength = length( Position.xyz - bowlcenter ) - bowlradius;
					if( exitlength > 0 )
					{
						float3 enterdir = Position.xyz - bowlcenter;
						Velocity.xyz -= (normalize( enterdir ) * exitlength) * edgecfmv;
						Position.xyz -= (normalize( enterdir ) * exitlength)*edgecfm;
					}
				}

				const float2 WorldSize = float2( 10, 10 );
				const float2 HalfWorldSize = WorldSize/2;
				
				// World Edges
				if( 1 )
				{
					float protrudelen;
					protrudelen = Position.x - HalfWorldSize.x + Position.w;
					if( protrudelen > 0 )
					{
						Velocity.xyz -= float3( 1, 0, 0 ) * protrudelen * edgecfmv;
						Position.xyz -= float3( 1, 0, 0 ) * protrudelen * edgecfm;
					}

					protrudelen = -HalfWorldSize.x-Position.x + Position.w;
					if( protrudelen > 0 )
					{
						Velocity.xyz -= float3( -1, 0, 0 ) * protrudelen * edgecfmv;
						Position.xyz -= float3( -1, 0, 0 ) * protrudelen * edgecfm;
					}

					protrudelen = -Position.y + Position.w;
					if( protrudelen > 0 )
					{
						Velocity.xyz -= float3( 0, -1, 0 ) * protrudelen * edgecfmv;
						Position.xyz -= float3( 0, -1, 0 ) * protrudelen * edgecfm;
					}
					protrudelen = Position.z - HalfWorldSize.y + Position.w;
					if( protrudelen > 0 )
					{
						Velocity.xyz -= float3( 0, 0, 1 ) * protrudelen;
						Position.xyz -= float3( 0, 0, 1 ) * protrudelen * edgecfm;
					}

					protrudelen = -HalfWorldSize.y-Position.z + Position.w;
					if( protrudelen > 0 )
					{
						Velocity.xyz -= float3( 0, 0, -1 ) * protrudelen;
						Position.xyz -= float3( 0, 0, -1 ) * protrudelen * edgecfm;
					}
				}

				{
					float heightcfm = 1.8;
					float heightcfmv = 100.;
					float4 StorePos = Position;
					float4 StoreVel = Velocity;
					//Collision with depth map.
					int2 DepthMapCoord = ( (Position.xz) / WorldSize + 0.5 ) * _DepthMapAbove_TexelSize.zw;
					float2 DepthMapDeltaMeters = WorldSize * _DepthMapAbove_TexelSize.xy;
					int2 neighborhood = ceil( Position.w / DepthMapDeltaMeters );
					int2 ln;
					for( ln.x = -neighborhood.x; ln.x < neighborhood.x; ln.x++ )
					for( ln.y = -neighborhood.y; ln.y < neighborhood.y; ln.y++ )
					{
						int2 coord = ln + DepthMapCoord;

						if( coord.x < 0 || coord.y < 0 || coord.x >= _DepthMapAbove_TexelSize.z || coord.y >= _DepthMapAbove_TexelSize.w )
							continue;

							
						float topY = (_DepthMapAbove[coord])*20;
						int2 bottomcoord = int2( coord.x, coord.y );
						float bottomY = ((_DepthMapAbove[bottomcoord])*20);

						float2 xzWorldPos = ((coord * _DepthMapAbove_TexelSize.xy) - 0.5 ) * WorldSize;
						float3 CollisionPosition = float3( xzWorldPos.x, topY, xzWorldPos.y );
						
						//Tricky: If we are above the bottom part and below the top, we are "inside" so zero the Y.
						if( StorePos.y < topY && StorePos.y > bottomY )
						{
							CollisionPosition.y = StorePos.y;
						}


						float3 deltap = StorePos.xyz - CollisionPosition;

						float penetration = StorePos.w - length(deltap);
						if( penetration > 0 )
						{
							float neighborderate = neighborhood.x *neighborhood.y;
							deltap = normalize( deltap );
							Velocity.xyz += deltap * penetration * heightcfmv / neighborderate;
							Position.xyz += deltap * penetration * heightcfm / neighborderate;
						}
					}
				}
				
				//Fountain
				if( 1 )
				{
					if( Position.x < -4 && Position.z < -4 && Position.y < 3 )
					{
						Velocity.xyz += float3( .01, .3, .01 );
					}
				}
				
				//Velocity.w = 0.5;

	//			texture2D<float> _DepthMapAbove;
	//			float4 _DepthMapAbove_TexelSize;
	//			texture2D<float> _DepthMapBelow;
	//			float4 _DepthMapBelow_TexelSize;



				// Step 2: Actually perform physics.
				float dt = 0.01;//unity_DeltaTime.x;
				Velocity.y -= 9.8*dt;
				
				Position.xyz = Position.xyz + Velocity.xyz * dt;
				
				Velocity.xyz = Velocity.xyz * .995;

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
				uint2 coord = IN.globalTexcoord.xy * _SelfTexture2D_TexelSize.zw;
				return _SelfTexture2D[coord];
			}
			ENDCG
		}


    }
}
