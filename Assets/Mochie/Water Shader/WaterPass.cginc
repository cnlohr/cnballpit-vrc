#ifndef WATER_PASS_INCLUDED
#define WATER_PASS_INCLUDED

v2f vert (appdata v) {
	v2f o = (v2f)0;

	o.pos = UnityObjectToClipPos(v.vertex);
	o.normal = UnityObjectToWorldNormal(v.normal);
	o.cNormal = UnityObjectToWorldNormal(v.normal);
	o.tangent = normalize(mul(unity_ObjectToWorld, float4(v.tangent.xyz, 0)).xyz);
	o.binormal = normalize(cross(o.normal, o.tangent) * v.tangent.w);
	o.worldPos = mul(unity_ObjectToWorld, v.vertex);
	o.uvGrab = ComputeGrabScreenPos(o.pos);
	o.localPos = v.vertex;
	o.uv = v.uv;
	return o;
}

float4 frag(v2f i, bool isFrontFace: SV_IsFrontFace) : SV_Target {

	float3 normalMap;
	float3 detailNormal;
	float2 uvNormal0 = ScaleUV(i.uv, _NormalMapScale0, _NormalMapScroll0);
	float2 uvNormal1 = ScaleUV(i.uv, _NormalMapScale1, _NormalMapScroll1);
	float2 baseUV0 = uvNormal0;
	float2 baseUV1 = uvNormal1;
	float3 uv00 = float3(baseUV0, 1);
	float3 uv10 = float3(baseUV1, 1);
	float2 uvFoam = ScaleUV(i.uv, _FoamTexScale, _FoamTexScroll * 0.1);
	float3 uvF0 = float3(uvFoam, 1);
	float3 uvF1 = uvF0;

	float2 uvFlow = ScaleUV(i.uv, _FlowMapScale, 0);
	float4 flowMap = tex2D(_FlowMap, uvFlow);
	float2 flow = (flowMap.rg * 2 - 1) * _FlowStrength * 0.1;
	float time = _Time.y * _FlowSpeed + flowMap.a;
	uv00 = FlowUV(baseUV0, flow, time, 0);
	float3 uv01 = FlowUV(baseUV0, flow, time, 0.5);
	uv10 = FlowUV(baseUV1, flow, time, 0);
	float3 uv11 = FlowUV(baseUV1, flow, time, 0.5);
	uvF0 = FlowUV(uvFoam, flow, time, 0);
	uvF1 = FlowUV(uvFoam, flow, time, 0.5);

	_NormalStr0 *= 1.25;
	_NormalStr1 *= 1.25;
	float3 normalMap0 = UnpackScaleNormal(tex2Dstoch(_NormalMap0, uv00.xy), _NormalStr0) * uv00.z;
	float3 normalMap1 = UnpackScaleNormal(tex2Dstoch(_NormalMap0, uv01.xy), _NormalStr0) * uv01.z;

	float3 detailNormal0 = UnpackScaleNormal(tex2Dstoch(_NormalMap1, uv10.xy), _NormalStr1) * uv10.z;
	float3 detailNormal1 = UnpackScaleNormal(tex2Dstoch(_NormalMap1, uv11.xy), _NormalStr1) * uv11.z;
	normalMap0 = normalize(normalMap0 + normalMap1);
	detailNormal0 = normalize(detailNormal0 + detailNormal1);
	normalMap = BlendNormals(normalMap0, detailNormal0);
	
	float4 uvgrab = i.uvGrab;

	float2 uvOffset = normalMap.xy * _DistortionStrength;
	float proj = (uvgrab.w + 0.00001);
	float2 screenUV = uvgrab.xy / proj;
	float2 uvFoamOffset = normalMap.xy * _FoamDistortionStrength * 0.1;
	
	float2 baseUV = uvgrab.xy/proj;
	float4 baseCol = _Color;
	float4 col = _Color;
	
#ifdef UNITY_UV_STARTS_AT_TOP
	if (_ProjectionParams.x >= 0)
	{
		screenUV.y = 1 - screenUV.y; 
		baseUV.y = 1 - baseUV.y; 
	}
#endif
	
	uvF0.xy += uvFoamOffset;
	uvF1.xy += uvFoamOffset;
	float depth = saturate(1-GetDepth(i, screenUV));
	float foamDepth = saturate(pow(depth,_FoamPower));

	float4 foamTex0 = tex2D(_FoamTex, uvF0.xy) * uvF0.z;
	float4 foamTex1 = tex2D(_FoamTex, uvF1.xy) * uvF1.z;
	float4 foamTex = (foamTex0 + foamTex1) * _FoamColor;

	float2 foamNoiseUV = ScaleUV(i.uv.xy, _FoamNoiseTexScale, _FoamNoiseTexScroll);
	float foamNoise = Average(tex2D(_FoamNoiseTex, foamNoiseUV).rgb);
	float foamTexNoise = lerp(1, foamNoise, _FoamNoiseTexStrength);
	float foamCrestNoise = lerp(1, foamNoise, _FoamNoiseTexCrestStrength);
	float foam = saturate(foamTex.a * foamDepth * _FoamOpacity * foamTexNoise * Average(foamTex.rgb));
	
	i.normal = normalize(dot(i.normal, i.normal) >= 1.01 ? i.cNormal : i.normal);
	float3 normalDir = normalize(normalMap.x * i.tangent + normalMap.y * i.binormal + normalMap.z * i.normal);
	float3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos);
	float NdotV = abs(dot(normalDir, viewDir));
	float roughSq = _Roughness * _Roughness;
	float roughBRDF = max(roughSq, 0.003);
	
	col.rgb *= NdotV;
	col.rgb = lerp(col.rgb, foamTex.rgb, foam);
	
	float omr = unity_ColorSpaceDielectricSpec.a - _Metallic * unity_ColorSpaceDielectricSpec.a;
	float3 specularTint = lerp(unity_ColorSpaceDielectricSpec.rgb, 1, _Metallic);
	float3 specCol = 0;
	float3 reflCol = 0;
	if (isFrontFace){
		float roughInterp = smoothstep(0.001, 0.003, roughSq);
		float3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
		float3 halfVector = normalize(lightDir + viewDir);
		float NdotL = dot(normalDir, lightDir);
		float NdotH = Safe_DotClamped(normalDir, halfVector);
		float LdotH = Safe_DotClamped(lightDir, halfVector);
		float3 fresnelTerm = FresnelTerm(specularTint, LdotH);
		float specularTerm = SpecularTerm(NdotL, NdotV, NdotH, roughBRDF);
		specCol = _LightColor0 * fresnelTerm * specularTerm;
		specCol = lerp(smootherstep(0, 0.9, specCol), specCol, roughInterp) * _SpecStrength;

		float3 reflDir = reflect(-viewDir, normalDir);
		float surfaceReduction = 1.0 / (roughBRDF*roughBRDF + 1.0);
		float grazingTerm = saturate((1-_Roughness) + (1-omr));
		float fresnel = FresnelLerp(specularTint, grazingTerm, NdotV);
		reflCol = GetWorldReflections(reflDir, i.worldPos, _Roughness);
		reflCol = reflCol * fresnel * surfaceReduction * _ReflStrength;
	}
	col.rgb += specCol;
	col.rgb += reflCol;

	float edgeFadeDepth = saturate(1-GetDepth(i, baseUV));
	edgeFadeDepth = (1-saturate(pow(edgeFadeDepth, _EdgeFadePower)));
	edgeFadeDepth = saturate(Remap(edgeFadeDepth, 0, 1, -_EdgeFadeOffset, 1));

	if (isFrontFace){
		#if DEPTHFOG_ENABLED
			float fogDepth = 0;
			fogDepth = depth;
			fogDepth = saturate(pow(fogDepth, _FogPower));
			col.rgb = lerp(col.rgb, lerp(_FogTint.rgb, col.rgb, fogDepth), _FogTint.a);
		#endif
	}

	col = lerp(0, col, edgeFadeDepth);	
	return col;
}

#endif // WATER_PASS_INCLUDED