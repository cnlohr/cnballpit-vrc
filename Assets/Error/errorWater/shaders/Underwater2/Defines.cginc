sampler2D _MainTex; float4 _MainTex_ST;
sampler2D _MetallicGlossMap;
sampler2D _BumpMap;
float4 _Color;
float _Metallic;
float _Glossiness;
float _BumpScale;

float _SpecularLMOcclusion;
float _SpecLMOcclusionAdjust;
float _TriplanarFalloff;
float _LMStrength;
float _RTLMStrength;
int _TextureSampleMode;
int _LightProbeMethod;

sampler2D _CausticsTex;
float4 _CausticsTex_ST;
float _framerate;
float _xtiles;
float _ytiles;
float4 _CausticsColor;
float _CausticsPercent;