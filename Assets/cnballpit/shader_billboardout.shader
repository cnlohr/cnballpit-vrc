// UNITY_SHADER_NO_UPGRADE

Shader "mass_system/billboardout" 
{
	Properties 
	{
		_PositionsIn ("Positions", 2D) = "" {}
		_VelocitiesIn ("Velocities", 2D) = "" {}
		_Mode ("Mode", float) = 0
	}

	SubShader 
	{
	
        // shadow caster rendering pass, implemented manually
        // using macros from UnityCG.cginc
        Pass
        {
            Tags {"LightMode"="ShadowCaster"}

			CGINCLUDE
			
			#include "/Assets/hashwithoutsine/hashwithoutsine.cginc"
			#include "/Assets/AudioLink/Shaders/AudioLink.cginc"
            #pragma vertex vert
            #pragma geometry geo
            #pragma multi_compile_shadowcaster
			#pragma target 5.0
            #include "UnityCG.cginc"
			#include "cnballpit.cginc"

			struct v2g
			{
				float4	pos		: POSITION;
				float3	normal	: NORMAL;
				float2  uv	: TEXCOORD0;
				float4  opos    : TEXCOORD1;
			};

			struct g2f
			{
				float4	pos		: POSITION;
				float2  uv	: TEXCOORD0;
				float4  ballcenter : TEXCOORD1;
				float3  hitworld : TEXCOORD2;
				float4  props : TEXCOORD3;
				float4  colorDiffuse : TEXCOORD4;
				float4  colorAmbient : TEXCOORD5;
				float4  colorSpecular : TEXCOORD6;
			};

			float4x4 _VP;
			
			float _Mode;
			texture2D<float4> _RVData;
			float4 _RVData_TexelSize;
			fixed4 _LightColor0;
			
			v2g vert(appdata_base v)
			{
				v2g output = (v2g)0;

				output.pos =  mul(unity_ObjectToWorld, v.vertex);
				output.normal = v.normal;
				output.uv = float2(0, 0);
				output.opos = v.vertex;

				return output;
			}

			[maxvertexcount(32)]
			void geo(point v2g p[1], inout TriangleStream<g2f> triStream, uint id : SV_PrimitiveID)
			{
				int transadd;
				for( transadd = 0; transadd < 8; transadd++ )
				{
					//based on https://github.com/MarekKowalski/LiveScan3D-Hololens/blob/master/HololensReceiver/Assets/GS%20Billboard.shader

					float3 worldoffset = p[0].pos;	// World pos of center of system.
					//int3  oposid = p[0].opos * float3( -1, 1, 1 ) + float3( 0., 0., 0. );
					
					//oposid += transadd * 16;
					
					// Set based on data
					//int ballid = oposid.x + oposid.y * 32 + oposid.z * 1024;
					int ballid = id * 8 + transadd;
					
					float4 DataPos = GetPosition(ballid);
					float3 PositionRelativeToCenterOfBallpit = DataPos;
					float4 DataVel = GetVelocity(ballid);
					DataPos.xyz += worldoffset ;
					
					float3 rvpos = DataPos;

					float3 up, look, right;

					up = float3(0, 1, 0);
 
					if ((UNITY_MATRIX_P[3].x == 0.0) && (UNITY_MATRIX_P[3].y == 0.0) && (UNITY_MATRIX_P[3].z == 0.0)){
						//look = UNITY_MATRIX_V[2].xyz;
						look = normalize(_WorldSpaceLightPos0.xyz - rvpos * _WorldSpaceLightPos0.w);
					}
					else
					{
						look = _WorldSpaceCameraPos - rvpos;
						//look.y = 0; //uncomment to force horizontal billboard.
					}
 


					look = normalize(look);
					right = cross(up, look);
					
					//Make actually face directly.
					up = normalize(cross( look, right ));
					right = normalize(right);

					float size = DataPos.w*2+.1; //DataPos.w is radius. (Add a little to not clip edges.)
					float halfS = 0.5f * size;
					
					//Pushthe view plane away a tiny bit, to prevent nastiness when doing the SV_DepthLessEqual for perf.
					rvpos += look*halfS;
							
					float4 v[4];
					v[0] = float4(rvpos + halfS * right - halfS * up, 1.0f);
					v[1] = float4(rvpos + halfS * right + halfS * up, 1.0f);
					v[2] = float4(rvpos - halfS * right - halfS * up, 1.0f);
					v[3] = float4(rvpos - halfS * right + halfS * up, 1.0f);

					float4x4 vp = mul( UNITY_MATRIX_MVP, unity_WorldToObject);


					float4 colorDiffuse = float4( hash33((DataVel.www*10.+10.1)), 1. ) - .1;
					
					float3 SmoothHue = AudioLinkHSVtoRGB( float3(  frac(ballid/1024. + AudioLinkDecodeDataAsSeconds(ALPASS_GENERALVU_NETWORK_TIME)*.05), 1, .8 ) );
					float4 colorAmbient = 0.;

					if( _Mode == 0 )
					{
						colorAmbient   += colorDiffuse * .1;
					}
					if( _Mode == 1 )
					{
						colorDiffuse = abs(float4( 1.-abs(glsl_mod(PositionRelativeToCenterOfBallpit.xyz,2)), 1 )) * .8;
						colorAmbient   += colorDiffuse * .1;
					}
					else if( _Mode == 2 )
					{
						colorDiffuse.xyz = SmoothHue;
						colorAmbient   += colorDiffuse * .1;

					}
					else if( _Mode == 3 )
					{
						float dfc = length( PositionRelativeToCenterOfBallpit.xz ) / 15;
						float intensity = saturate( AudioLinkData( ALPASS_AUDIOLINK + uint2( dfc * 128, (ballid / 128)%4 ) ) * 6 + .05 );
						colorDiffuse.xyz = SmoothHue;
						//colorDiffuse *= intensity; 
						colorAmbient += colorDiffuse * intensity * .3;
						colorDiffuse = colorDiffuse * .5 + .04;
					}
					else if( _Mode == 4 )
					{
						//float intensity = saturate( AudioLinkData( ALPASS_FILTEREDAUDIOLINK + uint2( 4, ( ballid / 128 ) % 4 ) ) * 6 + .1);

						int selccnote = 0;
						int balldiv = ballid % 7;
						if( balldiv < 3 ) selccnote = 0;
						else if( balldiv < 5 ) selccnote = 1;
						else if( balldiv < 6 ) selccnote = 2;
						else selccnote = 3;
						float4 rnote =  AudioLinkData( ALPASS_CCINTERNAL + uint2( selccnote % 4, 0 ) );
						float rgbcol;
						if( rnote.x >= 0 )
							colorDiffuse.xyz = AudioLinkCCtoRGB( rnote.x, rnote.z * 0.1 + 0.1, 0 );
						else
							colorDiffuse.xyz = SmoothHue * 0.1;

						colorAmbient   += colorDiffuse * .1;
					}
					float4 colorSpecular = .2*_LightColor0;

					g2f pIn;
					pIn.pos = mul(vp, v[0]);
					pIn.uv = float2(1.0f, 0.0f);
					pIn.ballcenter = DataPos.xyzw;
					pIn.hitworld = v[0];
					pIn.props = float4( DataVel.w, 0, 0, 1 );
					pIn.colorDiffuse = colorDiffuse;
					pIn.colorSpecular = colorSpecular;
					pIn.colorAmbient = colorAmbient;
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[1]);
					pIn.uv = float2(1.0f, 1.0f);
					pIn.hitworld = v[1];
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[2]);
					pIn.uv = float2(0.0f, 0.0f);
					pIn.hitworld = v[2];
					triStream.Append(pIn);

					pIn.pos =  mul(vp, v[3]);
					pIn.uv = float2(0.0f, 1.0f);
					pIn.hitworld = v[3];
					triStream.Append(pIn);
					triStream.RestartStrip();
				}
			}

			ENDCG

            CGPROGRAM

            #pragma fragment frag

			float4 frag(g2f input, out float outDepth : SV_DepthLessEqual) : COLOR
			{
				float4 props = input.props;
				float3 s0 = input.ballcenter;
				float sr = input.ballcenter.w;
				float3 hitworld = input.hitworld;
				float3 ro = _WorldSpaceCameraPos;
				float3 rd = normalize(hitworld-_WorldSpaceCameraPos);

				if ((UNITY_MATRIX_P[3].x == 0.0) && (UNITY_MATRIX_P[3].y == 0.0) && (UNITY_MATRIX_P[3].z == 0.0))
				{
					float3 dist = 100.;
					float4 clipPos = mul(UNITY_MATRIX_VP, float4(hitworld, 1.0));
					if( length( input.uv-0.5) < 0.26 )
						outDepth = clipPos.z / clipPos.w;
					else
						outDepth = 0;
					return 0.;
				}
 
			    float a = dot(rd, rd);
				float3 s0_r0 = ro - s0;
				float b = 2.0 * dot(rd, s0_r0);
				float c = dot(s0_r0, s0_r0) - (sr * sr);
				
				float disc = b * b - 4.0 * a* c;

				if (disc < 0.0)
					discard;
				float2 answers = float2(-b - sqrt(disc), -b + sqrt(disc)) / (2.0 * a);
				float minr = min( answers.x, answers.y );
	
	
				float3 worldhit = ro + rd * minr;
				float3 hitnorm = worldhit-s0;
				
				float3 dist = worldhit.xyz - _LightPositionRange.xyz;

				float4 clipPos = mul(UNITY_MATRIX_VP, float4(worldhit, 1.0));
				outDepth = clipPos.z / clipPos.w;

				return UnityEncodeCubeShadowDepth(length(dist) * _LightPositionRange.w);;
			}

            ENDCG
        }

		Pass
		{
			Tags { "RenderType"="Opaque" "LightModel"="ForwardBase"}
			LOD 200
		
			CGPROGRAM
			#pragma fragment FS_Main

			float4 FS_Main(g2f input, out float outDepth : SV_DepthLessEqual) : COLOR
			{
				float4 props = input.props;
				float3 s0 = input.ballcenter;
				float sr = input.ballcenter.w;
				float3 hitworld = input.hitworld;
				float3 ro = _WorldSpaceCameraPos;
				float3 rd = normalize(hitworld-_WorldSpaceCameraPos);
				
			    float a = dot(rd, rd);
				float3 s0_r0 = ro - s0;
				float b = 2.0 * dot(rd, s0_r0);
				float c = dot(s0_r0, s0_r0) - (sr * sr);
				
				float disc = b * b - 4.0 * a* c;

				if (disc < 0.0)
					discard;
				float2 answers = float2(-b - sqrt(disc), -b + sqrt(disc)) / (2.0 * a);
				float minr = min( answers.x, answers.y );
	
	
				float3 worldhit = ro + rd * minr;
				float3 hitnorm = worldhit-s0;
				
				float4 albcolor = dot( _WorldSpaceLightPos0.xyz, hitnorm );
				
				
				const float shininessVal = 8;
				const float Kd = 1;
				const float Ks = 1;
				
				float3 N = normalize(hitnorm);
				float3 L = normalize(_WorldSpaceLightPos0);
				// Lambert's cosine law
				float lambertian = max(dot(N, L), 0.0);
				float specular = 0.0;
				if(lambertian > 0.0) {
					float3 R = reflect(-L, N);      // Reflected light vector
					float3 V = normalize(-rd); // Vector to viewer
					// Compute the specular term
					float specAngle = max(dot(R, V), 0.0);
					specular = pow(specAngle, shininessVal);
				}
				albcolor = float4( input.colorAmbient.xyz +
					   Kd * lambertian * input.colorDiffuse +
					   Ks * specular * input.colorSpecular, 1.0);
			   

                UNITY_APPLY_FOG(i.fogCoord, col);
				float4 clipPos = mul(UNITY_MATRIX_VP, float4(worldhit, 1.0));
				outDepth = clipPos.z / clipPos.w;
				
				
				return albcolor;
			}

			ENDCG
		}
	} 
}
