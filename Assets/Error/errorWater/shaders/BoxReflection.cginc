// Copied from catlikecoding's rendering tutorial series



float3 BoxProjection (
	float3 direction, float3 position,
	float4 cubemapPosition, float3 boxMin, float3 boxMax
	) {
		if (cubemapPosition.w > 0) {
			float3 factors =
				((direction > 0 ? boxMax : boxMin) - position) / direction;
			float scalar = min(min(factors.x, factors.y), factors.z);
			direction = direction * scalar + (position - cubemapPosition);
		}
		return direction;
}

float4 getCubemapColor(float3 position, float3 direction, float smoothness)
{
					Unity_GlossyEnvironmentData envData;
					envData.roughness = 1.0 - smoothness;
					envData.reflUVW = BoxProjection(direction, position, 
													unity_SpecCube0_ProbePosition, 
													unity_SpecCube0_BoxMin, 
													unity_SpecCube0_BoxMax
													);
				
					half4 specColor;
					
					float3 probe0 = Unity_GlossyEnvironment(
						UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
						);
					#if UNITY_SPECCUBE_BLENDING
						UNITY_BRANCH
						if (unity_SpecCube0_BoxMin.w < 0.99999)
						{
							envData.reflUVW = BoxProjection(direction, position, 
													unity_SpecCube1_ProbePosition, 
													unity_SpecCube1_BoxMin, 
													unity_SpecCube1_BoxMax
													);
							float3 probe1 = Unity_GlossyEnvironment(
							UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0), unity_SpecCube0_HDR, envData);
							specColor.rgb = lerp(probe1,probe0,unity_SpecCube0_BoxMin.w);
						}
						else
						{
							specColor.rgb = probe0;
						}
					#else
						specColor.rgb = probe0;
					#endif
		
					return float4(specColor.rgb,1);
}

float4 getCubemapColorNoBox(float3 position, float3 direction, float smoothness)
{
	Unity_GlossyEnvironmentData envData;
	envData.roughness = 1.0 - smoothness;
	envData.reflUVW = direction;

	half4 specColor;

	float3 probe0 = Unity_GlossyEnvironment(
		UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
	);
#if UNITY_SPECCUBE_BLENDING
	UNITY_BRANCH
		if (unity_SpecCube0_BoxMin.w < 0.99999)
		{
			envData.reflUVW = direction;
			float3 probe1 = Unity_GlossyEnvironment(
				UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0), unity_SpecCube0_HDR, envData);
			specColor.rgb = lerp(probe1, probe0, unity_SpecCube0_BoxMin.w);
		}
		else
		{
			specColor.rgb = probe0;
		}
#else
	specColor.rgb = probe0;
#endif

	return float4(specColor.rgb, 1);
}