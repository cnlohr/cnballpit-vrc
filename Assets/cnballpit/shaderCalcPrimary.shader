//XXX TODO: Remember to credit d4kpl4y3r with the bucketing tech.
//XXX TODO: ACTUALLY_DO_COMPLEX_HASH_FUNCTION and try it.
//
// Camera Comparison
//   All on UI Layer: 7.1ms ish
//   Cameras on Default, looking at other layer: 7.6ms? ish
//   All cameras on and looking at PlayerLocal: 7.1ms-7.6ms
//   All cameras on and looking at PickupNoLocal: 6.4-6.9ms???


Shader "cnballpit/shaderCalcPrimary"
{
	Properties
	{
		_BallRadius( "Default Ball Radius", float ) = 0.1
		_PositionsIn ("Positions", 2D) = "white" {}
		_VelocitiesIn ("Velocities", 2D) = "white" {}
		_Adjacency0 ("Adjacencies0", 2D) = "white" {}
		_Adjacency1 ("Adjacencies1", 2D) = "white" {}
		_Adjacency2 ("Adjacencies2", 2D) = "white" {}
		_Adjacency3 ("Adjacencies3", 2D) = "white" {}
        _DepthMapComposite ("Composite Depth", 2D) = "white" {}
		_Friction( "Friction", float ) = .008
		_DebugFloat("Debug", float) = 0
		[ToggleUI] _ResetBalls("Reset", float) = 0
		_GravityValue( "Gravity", float ) = 9.8
		_TargetFPS ("Target FPS", float ) = 120
		[ToggleUI] _DontPerformStep( "Don't Perform Step", float ) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "/Assets/hashwithoutsine/hashwithoutsine.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};
			
			struct f2a
			{
				float4 Pos : COLOR0;
				float4 Vel : COLOR1;
			};

			#include "cnballpit.cginc"
			float _BallRadius, _DebugFloat, _ResetBalls, _GravityValue, _Friction, _DontPerformStep;
			texture2D<float2> _DepthMapComposite;
			float4 _DepthMapComposite_TexelSize;
			float _TargetFPS;


			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			f2a frag ( v2f i )
			{
				f2a ret;
				int2 screenCoord = i.vertex.xy;
				uint ballid = screenCoord.y * 1024 + screenCoord.x;

				float dt;
				
				dt = 1./_TargetFPS;
				//dt = clamp( unity_DeltaTime.x/2., 0, .006 );
				
				float4 Position = GetPosition( ballid );
				float4 Velocity = GetVelocity( ballid );
				if( _Time.y < 3 || Position.w == 0 || _ResetBalls > 0 )
				{
					ret.Pos = float4( hash33( ballid.xxx ) * 10. + float3( -5, 0, -5 ), _BallRadius );
					ret.Vel = float4( 0., 0., 0., ballid );
					return ret;
				}
				
				//Potentially skip step.
				if( _DontPerformStep > 0.5 )
				{
					ret.Pos = Position;
					ret.Vel = Velocity;
					return ret;
				}
				
				Position.w = _BallRadius;
				int did_find_self = 0;
				
				//Collide with other balls - this section of code is about 350us per pass.
				if( 1 )
				{
					const float cfmVelocity = 15.0;
					const float cfmPosition = .008;
					
					// Step 1 find collisions.
					
					int3 ballneighbor;
					bool foundself = false;
					for( ballneighbor.x = -SearchExtents; ballneighbor.x <= SearchExtents; ballneighbor.x++ )
					for( ballneighbor.y = -SearchExtents; ballneighbor.y <= SearchExtents; ballneighbor.y++ )
					for( ballneighbor.z = -SearchExtents; ballneighbor.z <= SearchExtents; ballneighbor.z++ )
					{
						int j;
						
						//Determined experimentally - we do not need to check the cells at the far diagonals.
						if( length( ballneighbor ) > SeachExtentsRange ) continue;
						
						uint2 hashed = Hash3ForAdjacency(ballneighbor/HashCellRange+Position.xyz);
						
						for( j = 0; j < 4; j++ )
						{
							uint obid;
							if( j == 0 )      obid = _Adjacency0[hashed];
							else if( j == 0 ) obid = _Adjacency1[hashed];
							else if( j == 0 ) obid = _Adjacency2[hashed];
							else              obid = _Adjacency3[hashed];

							obid--;
							//See if we hit ourselves.
							if( obid == ballid )
							{
								foundself = true;
								continue;
							}
							
							float4 otherball = GetPosition( obid );
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
					if( !foundself )
					{
						//Velocity.w = 1;
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

				const float2 WorldSize = float2( 16, 16 );
				const float2 HighXZ = float2( 5, 5 );
				const float2 LowXZ = float2( -5, -5 );
				
				// World Edges
				if( 1 )
				{
					float protrudelen;

					// Floot
					protrudelen = -Position.y + Position.w;
					if( protrudelen > 0 )
					{
						Velocity.xyz -= float3( 0, -1, 0 ) * protrudelen * edgecfmv;
						Position.xyz -= float3( 0, -1, 0 ) * protrudelen * edgecfm;
					}
					
					//Outer floor
					if( length( Position.xz ) + Position.w > 8. )
					{
						protrudelen = -Position.y + Position.w + .7;
						if( protrudelen > 0 )
						{
							Velocity.xyz -= float3( 0, -1, 0 ) * protrudelen * edgecfmv;
							Position.xyz -= float3( 0, -1, 0 ) * protrudelen * edgecfm;
						}						
					}


					float adv = 0.001;

					// Diameter of pit, cylindrically.
					protrudelen = length( Position.xz ) + Position.w - 5.95;
					if( protrudelen > 0 )
					{
						float3 norm = float3( normalize( Position.xz ).x, 0, normalize( Position.xz ).y );
						Velocity.xyz -= norm * protrudelen * edgecfmv * adv;
						Position.xyz -= norm * protrudelen * edgecfm * adv;
					}

					//Island
					float3 diff = Position.xyz - float3( 0, -1.25, 0 );
					protrudelen = -length( diff ) + 2 + Position.w;
					if( protrudelen > 0 )
					{
						diff = normalize( diff  ) * protrudelen;
						Velocity.xyz += diff * edgecfmv;
						Position.xyz += diff * edgecfm;
					}
				}

				//Use depth cameras (Totals around 150us per camera on a 2070 laptop)
				if( 1 ) 
				{
					//Tested at 1.8/100 on 6/22/2021 AM early.  Changed to 200 to make it snappier and more throwable.
					float heightcfm = 1.8;
					float heightcfmv = 200. * 1; //Should have been *4 because we /4'd our texture?
					float4 StorePos = Position;
					float4 StoreVel = Velocity;
					//Collision with depth map.
					int2 DepthMapCoord = ( (Position.xz) / WorldSize + 0.5 ) * _DepthMapComposite_TexelSize.zw ;
					float2 DepthMapDeltaMeters = WorldSize * _DepthMapComposite_TexelSize.xy;


					int2 neighborhood = 7;//ceil( Position.w / DepthMapDeltaMeters );
					int2 ln;
					for( ln.x = -neighborhood.x; ln.x < neighborhood.x; ln.x++ )
					[unroll]
					for( ln.y = -neighborhood.y; ln.y < neighborhood.y; ln.y++ )
					{
						int2 coord = ln + DepthMapCoord;

						// Note: Out-of-bounds checking seems unncessary. 
							
						float2 Y = _DepthMapComposite[coord];
						
						// No top pixels - early out!
						if( Y.x <= 0 ) continue;
						
						Y *= 20;

						if( Y.y == 0 ) Y.y = 19.5;
						Y.y = 19.5-((Y.y));

						//coord + 0.5 because we went from 2048 to 1024 here.
						float2 xzWorldPos = (((coord + 0.5)* _DepthMapComposite_TexelSize.xy) - 0.5 ) * WorldSize;
						
						//Figure out which side we're coming from.
						float CenterY = (Y.y + Y.x) / 2;
						float3 CollisionPosition = float3( xzWorldPos.x, (StorePos.y > CenterY )?Y.x:Y.y, xzWorldPos.y );
						
						//Tricky: If we are above the bottom part and below the top, we are "inside" so zero the Y.
						if( StorePos.y < Y.x && StorePos.y > Y.y )
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
					if( Position.x < -5.4 && Position.x > -6.4 && Position.z < .5 && Position.z > 0 && Position.y < 3 )
					{
						Velocity.xyz += float3( -.01, .13, 0 );
					}
				}
				
				//Velocity.w = 0.5;

	//			texture2D<float> _DepthMapAbove;
	//			float4 _DepthMapAbove_TexelSize;
	//			texture2D<float> _DepthMapBelow;
	//			float4 _DepthMapBelow_TexelSize;



				// Step 2: Actually perform physics.
				Velocity.y -= _GravityValue*dt;
				
				Position.xyz = Position.xyz + Velocity.xyz * dt;
				
				Velocity.xyz = Velocity.xyz * (1 - _Friction );

				ret.Pos = Position;
				ret.Vel = Velocity;

				return ret;
			}
			ENDCG
		}
	}
}
