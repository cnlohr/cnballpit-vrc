// Helper library with various utilities.
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
#ifndef SDF_MASTER_
#define SDF_MASTER_
#define PI 3.14159265 //TODO: Change to UNITY_PI
#define HF_PI PI / 2. //TODO: Change to UNITY_PI
#define HF_PI2 HF_PI / 2. //TODO: Change to UNITY_PI
#define TAU 6.28318530718
#define PHI (1.618033988749895)
     // PHI (sqrt(5)*0.5 + 0.5)
#define sqrt_2 1.41421356237
#define sqrt_half 0.70710678118
#define TAW 6.28318530718 * 2. / 3.


// GLSL conversion note: mul(a,b) is mul(b,a) in HLSL and vice-versa.
#define iTime _Time.y
#define iResolution _ScreenParams
#define vec2 float2
#define vec3 float3
#define vec4 float4
#define mix lerp
#define texture tex2D
#define fract frac
#define mat4 float4x4
#define mat3 float3x3
//#define textureLod(a, b, c) tex2Dlod(a, float3(b, 0, c))
#define textureLod(ch, uv, lod) tex2Dlod(ch, float4(uv, 0, lod))
//#define textureLod(a, b, c) tex2Dlod(a, float4(b, 0, c))
#define atan(x, y) atan2(y, x)
#define mod(x, y) (x - y * floor(x / y)) // glsl mod
#define uvec2 uint2
#define uvec3 uint3
#define uvec4 uint4
#define texelFetch(ch, uv, lod) tex2Dlod(ch, float4((uv).xy * ch##_TexelSize.xy + ch##_TexelSize.xy * 0.5, 0, lod))
//#define texelFetch(a,b,c) tex2Dlod(a,float4((float2(b)+.5)/float2(textureSize(a,0)),0,c))
#define dFdx(x) ddx(x)
#define dFdy(x) ddy(x)
#define textureLod2 tex2Dlod
#define DECLARE_TEX(x) sampler2D x;
#define textureSize(a,b) a##_TexelSize.zw

//TODO: Something more cursed...
float4 vec4i(float x) { return float4(x,x,x,x); }
float4 vec4i(float x, float3 v) { return float4(x,v.x,v.y,v.z); }
float4 vec4i(float3 v, float x) { return float4(v.x,v.y,v.z,x); }
float4 vec4i(float2 v1, float2 v2) { return float4(v1.x,v1.y,v2.x,v2.y); }
float3 vec3i(float x) { return float3(x,x,x); }
float3 vec3i(float2 v, float x) { return float3(v.x,v.y,x); }
float3 vec3i(float x, float2 v) { return float3(x,v.x,v.y); }
float2 vec2i(float x) { return float2(x,x); }

#include "UnityCG.cginc"


////////////////////////////////////////////////////////////////
//
//             Unorganized functions
//
////////////////////////////////////////////////////////////////

/*
	Return a 'stable' camera position.
	In VR this is between your two eyes. In desktop it's your camera.
*/


inline float4 GetCameraPositionStable() {
	return float4(
		#if UNITY_SINGLE_PASS_STEREO
			(unity_StereoWorldSpaceCameraPos[0] +
			unity_StereoWorldSpaceCameraPos[1]) / 2
		#else
			_WorldSpaceCameraPos
		#endif
	,1);
}

inline float3 GetCameraPosition() { return UNITY_MATRIX_I_V._m03_m13_m23; }
inline float3 GetCameraPosition2()    { return _WorldSpaceCameraPos;      }
inline float3 GetCameraForward()     { return -UNITY_MATRIX_V[2].xyz;    }
inline float3 GetCameraUp()          { return UNITY_MATRIX_V[1].xyz;     }
inline float3 GetCameraRight()       { return UNITY_MATRIX_V[0].xyz;     }
inline float  GetCameraFocalLength() { return abs(UNITY_MATRIX_P[1][1]); }
inline float  GetCameraNearClip()    { return _ProjectionParams.y;       }
inline float  GetCameraFarClip()     { return _ProjectionParams.z;       }
inline bool   IsCameraPerspective()  { return any(UNITY_MATRIX_P[3].xyz); }
inline bool   IsCameraOrtho()        { return !IsCameraPerspective(); }

inline float3 _GetCameraDirection(float2 sp)
{
    float3 camDir      = GetCameraForward();
    float3 camUp       = GetCameraUp();
    float3 camSide     = GetCameraRight();
    float  focalLen    = GetCameraFocalLength();
    return normalize((camSide * sp.x) + (camUp * sp.y) + (camDir * focalLen));
}

inline float3 GetCameraDirection(float4 projPos)
{
    projPos.xy /= projPos.w;
    projPos.xy = (projPos.xy - 0.5) * 2.0;
    projPos.x *= _ScreenParams.x / _ScreenParams.y;
    return _GetCameraDirection(projPos.xy);
}

inline float GetDistanceFromCameraToNearClipPlane(float4 projPos)
{
    projPos.xy /= projPos.w;
    projPos.xy = (projPos.xy - 0.5) * 2.0;
    projPos.x *= _ScreenParams.x / _ScreenParams.y;
    float3 norm = normalize(float3(projPos.xy, GetCameraFocalLength()));
    return GetCameraNearClip() / norm.z;
}

inline float3 GetScale()
{
    return float3(
        length(float3(unity_ObjectToWorld[0].x, unity_ObjectToWorld[1].x, unity_ObjectToWorld[2].x)),
        length(float3(unity_ObjectToWorld[0].y, unity_ObjectToWorld[1].y, unity_ObjectToWorld[2].y)),
        length(float3(unity_ObjectToWorld[0].z, unity_ObjectToWorld[1].z, unity_ObjectToWorld[2].z)));
}

inline float3 ToLocal(float3 pos)
{
    return mul(unity_WorldToObject, float4(pos, 1.0)).xyz;
}

inline float3 ToWorld(float3 pos)
{
    return mul(unity_ObjectToWorld, float4(pos, 1.0)).xyz;
}

inline float EncodeDepth(float4 pos)
{
    float z = pos.z / pos.w;
#if defined(SHADER_API_GLCORE) || \
    defined(SHADER_API_OPENGL) || \
    defined(SHADER_API_GLES) || \
    defined(SHADER_API_GLES3)
    return z * 0.5 + 0.5;
#else 
    return z;
#endif 
}

inline float EncodeDepth(float3 pos)
{
    float4 vpPos = mul(UNITY_MATRIX_VP, float4(pos, 1.0));
    return EncodeDepth(vpPos);
}

inline float3 EncodeNormal(float3 normal)
{
    return normal * 0.5 + 0.5;
}

inline float3 DecodeNormal(float3 normal)
{
    return 2.0 * normal - 1.0;
}

inline bool IsInnerCube(float3 pos, float3 scale)
{
    return all(max(scale * 0.5 - abs(pos), 0.0));
}

inline bool IsInnerSphere(float3 pos, float3 scale)
{
    return length(pos) < length(scale) * 0.28867513459 * 0.1;
}

inline bool IsInnerObject(float3 pos) {
    return length(pos) - 1 < 0;
}

// Smooth 3D texture interpolation

//i.e.: time = iTime + texelFetch(iChannel1, ivec2(fragCoord * 2.) & 1023, 0).r * .025;
//      time = iTime + smoothSample(_Noise, asfloat( asuint(int2(uv * 2.0)) & 1023).xyx, 0).r * .025;
float4 smoothSample(Texture3D tex, float3 p, int level)
{
    //vec3 sz = vec3(textureSize(tex, 0));
    float3 sz = float3(32, 32, 32);

    int3 ip = int3(floor(p * sz));

    float4 position0 = float4((ip + int3(0, 0, 0)) & int3(sz - 1.), level);
    float4 position1 = float4((ip + int3(1, 0, 0)) & int3(sz - 1.), level);
    float4 position2 = float4((ip + int3(0, 1, 0)) & int3(sz - 1.), level);
    float4 position3 = float4((ip + int3(1, 1, 0)) & int3(sz - 1.), level);
    float4 position4 = float4((ip + int3(0, 0, 1)) & int3(sz - 1.), level);
    float4 position5 = float4((ip + int3(1, 0, 1)) & int3(sz - 1.), level);
    float4 position6 = float4((ip + int3(0, 1, 1)) & int3(sz - 1.), level);
    float4 position7 = float4((ip + int3(1, 1, 1)) & int3(sz - 1.), level);

    float4 s0 = tex.Load(position0);
    float4 s1 = tex.Load(position1);
    float4 s2 = tex.Load(position2);
    float4 s3 = tex.Load(position3);
    float4 s4 = tex.Load(position4);
    float4 s5 = tex.Load(position5);
    float4 s6 = tex.Load(position6);
    float4 s7 = tex.Load(position7);

    float3 f = smoothstep(0., 1., frac(p * sz));
    
    //return s0;
    return lerp(
        lerp(lerp(s0, s1, f.x),
            lerp(s2, s3, f.x), f.y),
        lerp(lerp(s4, s5, f.x),
            lerp(s6, s7, f.x), f.y),
        f.z) * abs(cos(_Time.y * -0.25));
}   

const float3 stripedcolors[6] = {
  vec3(245./255.,  23./255.,  22./255.),
  vec3(248./255., 210./255.,  26./255.),
  vec3( 47./255., 243./255., 224./255.),
  vec3( 96./255., 192./255.,  83./255.),
  vec3(250./255.,  38./255., 160./255.),
  vec3(174./255., 129./255., 255./255.)
};
// A single iteration of Bob Jenkins' One-At-A-Time hashing algorithm.
uint shuffle(uint x) {
    x &= 255u;
    x += ( x << 10u );
    x ^= ( x >>  6u );
    x += ( x <<  3u );
    x ^= ( x >> 11u );
    x += ( x << 15u );
    x &= 255u;
    return x;
}
vec3 stripes(float n) {
  int m = int(floor(n) - 6.0 * floor(n / 6.0));
  return mix(
    stripedcolors[m % 6],
    stripedcolors[(m + 1) % 6],
    smoothstep(0.9, 1.0, fract(n))
  );
}
// corner vector
vec2 cvec(vec2 uv, float time) {
  float n = TAU * float(shuffle(uint(uv.x) + shuffle(uint(uv.y)))) / 256. + time;
  return vec2(cos(n), sin(n));
}

float posmod(float x, float y) {
  return x - y * (floor(x / y));
}

// fade function defined by ken perlin
float fade01(float t) {
    return (t * t * t * (t * (t * 6. - 15.) + 10.));
}


// perlin generator
float perlin(vec2 uv, float offset) {
  vec2 i = floor(uv);
  vec2 f = fract(uv);

  vec2 u = fade01(f);

  return
  mix(
    mix(
      dot( cvec(i + vec2(0.0,0.0), offset ), f - vec2(0.0,0.0) ),
      dot( cvec(i + vec2(1.0,0.0), offset ), f - vec2(1.0,0.0) ),
    u.x),
    mix(
      dot( cvec(i + vec2(0.0,1.0), offset ), f - vec2(0.0,1.0) ),
      dot( cvec(i + vec2(1.0,1.0), offset ), f - vec2(1.0,1.0) ),
    u.x),
  u.y);
}
float valNoise(float x) {
  uint xi = uint(floor(posmod(x, 256.)));
  float valL = float(shuffle(xi));
  float valR = float(shuffle(xi + 1u));
  return mix(valL, valR, fade01(fract(x))) / 255. - 0.5;
}
float gradNoise(float x) {
  uint xi = uint(floor(posmod(x, 256.)));
  float xf = fract(x);
  float gradL = float(shuffle(xi)) / 255. - 0.5;
  float gradR = float(shuffle(xi + 1u)) / 255. - 0.5;
  return mix(gradL * xf, gradR * (xf - 1.), fade01(xf));
}
vec2 shiftCenter(vec2 uv, float t, float strength) {
  vec2 d = vec2(
    valNoise(uv.x + t * 1.41421356) + gradNoise(uv.x - t),
    valNoise(uv.y - t) + gradNoise(uv.y + t * 1.7320508)
  );
  return uv + d * strength;
}


float3 BlendLight (float3 base, float3 blend) // soft light
{
    return (blend < 0.5) ? (2.0 * base * blend + base * base * (1.0 - 2.0 * blend)) : (sqrt(base) * (2.0 * blend - 1.0) + 2.0 * base * (1.0 - blend));
}

float3 BlendOverlay (float3 base, float3 blend) // overlay
{
    return base < 0.5 ? (2.0 * base * blend) : (1.0 - 2.0 * (1.0 - base) * (1.0 - blend));
}

float smootherstep(float edge0, float edge1, float x) {
  // Scale, and clamp x to 0..1 range
  x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
  // Evaluate polynomial
  return x * x * x * (x * (x * 6. - 15.) + 10.);
}

float softsquare(float x) {
    float x2 = abs(2. * fract(x) - 1.);
    return smoothstep(0.1, 0.9, x2);
}

// xor-ish behavior for floats
//#define flXor(x, y)  x + y - 2. * (x * y)        // xor-ish behavior for floats
float flXor(float x, float y) {
    return x + y - 2. * (x * y);
}

// folds 0>1>2>3>4... to 0>1<0>1<0...
// #define fold(x)      abs(1. - mod(x, 2.))        // folds 0>1>2>3>4... to 0>1<0>1<0...
float fold1(float x) {
    return abs(1. - mod(x, 2.));
}
// #define S(a,b,r)    smoothstep( -blur, blur, fold( (lenSq + lenAdd) * (a) + angle * b - t ) - r )
float fold2(float x) {
    return abs(mod(x, 2.0) - 1.0);
}

float foldPlus(float x) {
    return log(0.5 + fold2(x));
}

float smoothThres(float x, float strength) {
    return smoothstep(0.5 - strength, 0.5 + strength, x);
}

float smoothFold(float x, float strength) {
    return smoothThres(fold2(x), strength);
}

vec3 colMap(float x, vec3 a, vec3 b) {
    return a * (1.0 - x) + b * x;
}
vec3 gradient(float x, float y) {
    const float _2PI3 = 2.094395102393193;
    float g1 = softsquare(x);
    float g2 = softsquare(x - 0.3);
    vec3 blend = (vec3(sin(y), sin(y + _2PI3), sin(y - _2PI3)) + 1.) * 0.5;
    return blend * g2 + (1. - blend) * g1;
}

float spikes(float x) {
    x = 1. - abs(sin(x));
    return x * x;
}

float trapezoid(float x) {
    x = fract(x);
    if (x < 0.25) {
        return 4.0 * x;
    } else if (x < 0.5) {
        return 1.;
    } else if (x < 0.75) {
        return -4.0 * x + 3.0;
    } else {
        return 0.;
    }
}

vec3 gradient(float y) {
    vec3 x = trapezoid(y) * vec3(1.0, 0.0, 0.0)
           + trapezoid(y - 0.25) * vec3(0.0, 1.0, 1.0);
    return x;
}
vec3 whiteOutBlend(vec3 n1, vec3 n2) {
	return normalize(vec3(n1.xy + n2.xy, n1.z*n2.z));   
}
float ftick(float t){
    const float ticksPerRot = 24.0;
    const float tickLength = 0.125;
    const float tickPeriod = 1.;
    t += 0.5 * tickLength + 0.5 * tickPeriod;
    return (
        floor(t / tickPeriod) + smoothstep(0., 1., (mod(t / tickPeriod, 1.) - 0.5) / tickLength)
 		) / ticksPerRot
    ;
}

float fspiral02(float x)
{
    float n = frac(x / 3.14159265);
    return clamp((n - 0.5) * 2.5, 0., 1.);
}

float fremap(float x, float lowIn, float rangeIn, bool inver)
{
    float o = clamp(clamp(x - lowIn, 0., rangeIn) / rangeIn, 0., 1.);
    if (inver) {
        return 1. - o;
    }
    return o;
}
float fspiral03nyan(float theta)
{
	const float HEART_FACTOR = 0.85; //TODO: parameterize
    float a_theta = abs(theta);
    float hp_shift_theta = HF_PI2 - abs(a_theta);
    float p_shift_theta = PI - abs(a_theta);

    float heart = 2.0 - (1.0 + HF_PI2 * HEART_FACTOR) * max(cos(sin(hp_shift_theta)), 0.0);
    return heart;
}

float fspiral04(float x)
{
    return max(0.0, (sin(x) + 0.3) * 0.8);
}
vec3 fblend(vec3 x1, vec3 x2, float factor)
{
    return x2 * factor + x1 * (1. - factor);
}

float fzigzag(float x)
{
    return abs(1. - mod(x, 2.0));
}
  
float feyeAccent(float x) {
  if (x > 1.0) {
    return 0.;
  }
  return 1.0 - x * x;
}
  
float ftimeBounce(float x)
{
    return -3. * sin(PI * x) + x;
}
float fspiral05(float x, float y)
{
    float n = -0.5 * abs(x) + y;
    return log(x * x + 1.5 * n * n);
}

float fspiral06(float x, float multi, float offset)
{
    return max(0.0, min(1.0, (sin(x * 3.14159265) + offset) * multi));
}

vec4 fgetCornerColors(vec2 coord)
{
    vec2 halfRes = iResolution.xy * 0.5;
    float totalArea = iResolution.x * iResolution.y;
    
    vec3 cornerColors[4];
	
    cornerColors[0] = vec3(1.0, 0.0, 0.0);
    cornerColors[1] = vec3(0.0, 0.0, 1.0);
    cornerColors[2] = vec3(0.0, 1.0, 0.0);
    cornerColors[3] = vec3(1.0, 1.0, 0.0);
        
    vec2 cornerCoords[4];
    
    cornerCoords[0] = (float2)(-1.) * halfRes;
    cornerCoords[1] = vec2(1., -1.) * halfRes;
    cornerCoords[2] = (float2)(1.) * halfRes;
    cornerCoords[3] = vec2(-1., 1.) * halfRes;
    
	vec3 result = (float3)(0.0);
        
	for(int i = 0; i < 4; i++)
	{
		vec2 cCoord = cornerCoords[i] * iResolution.xy;

		vec2 d = cornerCoords[i] - coord;
        
        float a = abs(d.x * d.y);

		float w = a / totalArea;

		result += w * cornerColors[i];
    }
    
	return vec4(result, 1.0);
}

vec4 fspiral07(vec2 coord, 
				float alpha, // default: 0.
				float beta	 // default: 10.
			  )
{	
	float alpha_t = alpha - iTime * 50.0;

	float x = coord.x;
	float y = coord.y;

	float r = sqrt(dot(coord, coord));

	float phi = atan(y, x);

	float phi_r = (r - alpha_t) / beta;

	float r_phi = alpha_t + (beta * phi);

	float remainder = abs(cos(phi) - cos(phi_r));

	if (remainder < 0.5)
	{
		return vec4((float3)(0), 1.0);
	}
	else
	{
		return vec4((float3)(remainder), 1.0);
	}
}

vec4 fspiral08(vec2 coord 
				,float alpha // default: 0.
				,float beta	 // default: 10.
				,float num_branches //default: 4.
			  )
{	
	float alpha_t = alpha - iTime * 50.;

	float x = coord.x;
	float y = coord.y;

	float r = sqrt(x * x + y * y);

	float phi = atan(y, x) * num_branches;

	float phi_r = (r - alpha_t) / beta;

	float r_phi = alpha_t + (beta * phi);

	float remainder = abs(sin(phi) - sin(phi_r));

	remainder += abs(cos(phi) - cos(phi_r));

	if (remainder < 1.0)
	{
		vec4 c1 = vec4(1, 0, 0, 1);
		vec4 c2 = vec4(0, 0, 1, 1);

		float t = (phi / (2. * PI)) + 0.5;

		return mix(c1, c2, remainder);
	}
	else
	{
        vec4 c1 = vec4(1, 0, 0, 1);
		vec4 c2 = vec4(0, 0, 1, 1);
        return mix(c1, c2, remainder);
	}
}

vec4 fspiral09(vec2 coord 
				,float alpha // default: 0.
				,float beta	 // default: 10.
				,float num_branches //default: 4.
			  )
{
	float alpha_t = alpha - iTime * 50.;

	float x = coord.x;
	float y = coord.y;

	float r = sqrt(x * x + y * y);

	float phi = atan(y, x) * -num_branches;

	float phi_r = (r - alpha_t) / beta;

	float r_phi = alpha_t + (beta * phi);

	float remainder = abs(sin(phi) - sin(phi_r));

	remainder += abs(cos(phi) - cos(phi_r));

	if (remainder < 1.0)
	{
		vec4 c1 = vec4(1, 0, 0, 1);
		vec4 c2 = vec4(0, 0, 1, 1);

		float t = (phi / (2. * PI)) + 0.5;

		return mix(c1, c2, remainder);
	}
	else
	{
        vec4 c1 = vec4(1, 0, 0, 1);
		vec4 c2 = vec4(0, 0, 1, 1);
        return mix(c1, c2, remainder);
	}
}

vec2 ftwist01(vec2 coord 
				,float twist_period // default: 5.
			  )
{
	vec2 diff = coord;

	float l = length(diff);

	float twistRadius = length(iResolution.xy * 0.5);
    
	if (l < twistRadius)
	{
		float adjustedCurrTime = iTime;

		float k = floor(adjustedCurrTime / twist_period);
        
        float dt = mod(iTime, twist_period) / twist_period;

		float rad = PI * 0.1;
        
        //rad = rad * (sin(l / 20. + iTime));
        
        rad *= sin(l / 20.) + (l / length(iResolution.xy) * 0.5);// * sin(iTime);
        
        
		vec2 unitDiff = normalize(diff);

		float diffRad = atan(unitDiff.y, unitDiff.x);

		float newRad = diffRad + rad;
        
		vec2 newDiff = vec2(cos(newRad), sin(newRad)) * l;

		vec2 newCoord = newDiff;

		return newCoord;
	}
	else
	{
		return coord;
	}
}

vec2 fpulse01(vec2 coord 
				,float pulse_period // default: 2.5
				,float amplitude	 // default: 10.
			  )
{
	// this indicates how many periods have passed
	float k = floor(iTime / pulse_period);

	// currTime - (k * period) basically gives us the remainder of the above division, so if we divide
	// that by the period we have a representation of time passed relative to the period,  parameterized
	// to be between 0 and 1
	float dt = (iTime - (k * pulse_period)) / pulse_period;

	dt = iTime / pulse_period;
	
	vec2 diff = coord;

	// Length of diff comes in handy for a few things
	float l = length(diff);

	// Same trick as the above. Use amplitude as indicator of how many periods away we are and flip the offset direction based on evenness
	int i = int(floor(l / amplitude));

	//bool isEven = mod(i, 2) == 0.;
    bool isEven = true;

	//float sign = isEven ? 1.0 : -1.0;

	float sign = sin(l / 20.);
	
	float offset =  amplitude * sin(dt * PI * 2.0);

	float newL = l + (sign * offset);
	//float newL = l + offset;

	vec2 normDiff = normalize(diff);
	vec2 newDiff = normDiff * newL;

	return newDiff;
}

float ftime01(float x) {
    return cos(smoothstep(0.92, 1.0, fract(x)) * 3.14159265);
}

float ftime02(float x) {
    return smootherstep(0.92, 0.93, fract(x));
        //* (1.0 - smootherstep(0.99, 1.0, fract(x)))
}
float fpixel(float x, float y, float thres)
{
    float r_sq = x +  y /2.;
    return 1.0 - (r_sq - thres) * 1.0;
}


float fspiralpiece (vec2 uv, float rotate) { 
    
    // take polar coords 
	float a = length(uv - vec2(0.0,0.0));
    vec2 polar = vec2(a,atan(uv.y, uv.x) + rotate*UNITY_PI);
    
    // log spiral is e^(2*pi*theta), thanks wikipedia
    // this makes a spiral boundrary, abs and subtract from 1 for spiral line pieces
    // with MAGIC constants for nicer 'colors'. ok nicer greyscale, whatever. 
    return 1.0 - clamp(abs(mod(polar.y, UNITY_PI*2.0) - (3.0 * log(polar.x))), 0.0, 1.1);
}

// stack spiralpieces line segments 4 times over.
// TODO: spirals not perfect, can see boundraries between pieces
// MAGIC: why 8.1? because it looks better than 8.0 >_< 
// probably 'should be' some multiple of pi or something else stupid like that
vec4 fspiral10 (vec2 uv, float rotate, vec3 color) {
	return clamp((vec4)(fspiralpiece(uv*1.000, rotate) 
                    + fspiralpiece(uv*8.12, rotate) 
                    + fspiralpiece(uv*66.0, rotate)
                    + fspiralpiece(uv*536.0, rotate)), 0.0, 1.0) 
					* vec4(color, 0.0);
}

// rings... distance to center, take mod to repeat, subtract and abs to make symmetrical. 
// then pow for less blur / thinner pieces, and weirder silvery overlaps. 
float ffring02 (vec2 p, float offset) {
    // MAGIC WITH EXTRA MAGIC ON TOP HOLY SHIT
    // color   v1    |    ringsize (*will* break it)    v2, 1/2*v1 v3 | color v4
    return pow(2.42*abs(mod(offset-length((vec2)(0.0)-p), 0.75) -0.375) + 0.1, 5.2);
}


float fsdp(vec2 p, float r, float d){
    p = abs(p);
    float b = sqrt(r*r-d*d);
    return ((p.y-b)*d>p.x*b)?length(p-(vec2)(0.0,b)) : length(p-(vec2)(-d,0.0))-r;
}

float fspiral11(vec2 m) {
	float r = length(m), a = atan(m.y, m.x);
	return sin(75.*(sqrt(r) - .04 * a - .05 * iTime * 2.));
}

float fspiral12heart(float theta)
{
	const float HEART_FACTOR = 0.85; //TODO: parameterize
    float a_theta = abs(theta);
    float hp_shift_theta = HF_PI2 - abs(a_theta);
    float p_shift_theta = PI - abs(a_theta);
    float heart = 2.0 
        - (1.0 + HF_PI2 * HEART_FACTOR) * max(cos(sin(hp_shift_theta)), 0.0);
    return heart;
}


vec2 cart_logpolar(vec2 p) {
	return vec2(atan((p).y, (p).x), log(length(p)));
}
vec3 fHSVToRGB01(vec3 hsv) {
	return (mix(vec3(1.0, 1.0, 1.0), clamp((abs((mod((((hsv).x) / 60.0) + (vec3(0.0, 4.0, 2.0)), 6.0)) - 3.0)) - 1.0, 0.0, 1.0), (hsv).y)) * ((hsv).z);
}
vec2 polar_norm(vec2 p) {
	return vec2(mod(((p).x) + 6.28318, 6.28318), (p).y);
}
vec2 logpolar_cart(vec2 p) {
	return (vec2(cos((p).x), sin((p).x))) * (pow(2.71828, (p).y));
}
vec4 distance_field(vec2 p) {
	float a = ((p).y) * ((sin(((iTime) / 10.0) + (((p).y) + (iTime)))) * 2.0);
	vec2 xp = logpolar_cart(((p) + (vec2(a, 0.0))) - ((mod(polar_norm(((p) - (iTime)) + (vec2(a, 0.0))), 0.314159)) - 0.1570795));
	vec2 t = (abs((mod(polar_norm(((p) - (iTime)) + (vec2(a, 0.0))), 0.314159)) - 0.1570795)) - 0.1570795;
	return vec4(mix((min(max((t).x, (t).y), 0.0)) + (length(max(t, 0.0))), (length((mod(polar_norm(((p) - (iTime)) + (vec2(a, 0.0))), 0.314159)) - 0.1570795)) - 0.1570795, abs(sin(((xp).y) * 10.0))), fHSVToRGB01(vec3(abs((sin((((xp).y) + ((xp).x)) * 10.0)) * 360.0), abs(sin(((xp).x) * 17.0)), abs(sin(((xp).y) * 13.0)))));
}

// A single iteration of Bob Jenkins' One-At-A-Time hashing algorithm.
uint fHash01(uint x) {
    x += ( x << 10u );
    x ^= ( x >>  6u );
    x += ( x <<  3u );
    x ^= ( x >> 11u );
    x += ( x << 15u );
    return x;
}

// Generate random 4bit RGB color
vec3 rcol01(uint seed) {
    uint x = fHash01(seed);
    return vec3(x & 15u, x>>4u & 15u, x>>8u & 15u) / 15.;
}

vec3 fcol01(float x) {
    uint seed = uint(int(x));
    return  rcol01(seed)      * smoothstep(0.34, 0.02, frac(x))
          + rcol01(seed + 1u) * smoothstep(0.00, 0.32, frac(x));
}

// gives pure saturated color from input [0, 6) for phase
vec3 hue01(float x) {
    x = mod(x, 6.);
    return clamp(vec3(
        abs(x - 3.) - 1.,
        -abs(x - 2.) + 2.,
        -abs(x - 4.) + 2.
    ), 0., 1.);
}
vec3 hue02(float t) {
    return smoothstep(0.0, 1.0, vec3(sin(t * TAU), sin(t * TAU + TAW), sin(t * TAU - TAW)) + 1. / 2.);
}

vec3 hue03(float x) {
    return (vec3(
    	sin(x),
        sin(x + 2. * PI / 3.),
        sin(x + 4. * PI / 3.)
    ) + 1.0) * 0.6;
}

float star1(float angle, float d, float roundness) {
    return foldPlus(angle * 10.) + d * roundness;
}

// does pseudo overexposure filter
vec3 deepfry(vec3 rgb, float x) {
    rgb *= x;
    return rgb + vec3(
      max(0., rgb.g - 1.) + max(0., rgb.b - 1.),
      max(0., rgb.b - 1.) + max(0., rgb.r - 1.),
      max(0., rgb.r - 1.) + max(0., rgb.g - 1.)
    );
}
// switches between 2 modes by comparing between the first 2 args
float swch(float val, float thres, float a, float b) {
    return step(val, thres) * a + step(thres, val) * b;
}
float rcol02(uint seed) {
    return asfloat(asuint(0x007FFFFFu & fHash01(seed) | 0x3F800000u)) - 1.;
}

float logStripe(vec2 uv, float offset, float angleAdd) {
    return frac(offset + 2. * log(abs(dot(
        uv, vec2(cos(angleAdd), sin(angleAdd))
    ))+0.03));
}

vec3 pal( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}

// polynomial smooth min (k = 0.1);
// from iq: https://www.iquilezles.org/www/articles/smin/smin.htm
float smin( float a, float b, float k )
{
    float h = clamp( 0.5+0.5*(b-a)/k, 0.0, 1.0 );
    return mix( b, a, h ) - k*h*(1.0-h);
}

//float smin(float a,float b,float k){ return -log2(exp2(-k*a)+exp2(-k*b))/k;}//from iq
float smax(float a,float b,float k){ return -smin(-a,-b,k);}

float sineInOut(float t) {
  return -0.5 * (cos(UNITY_PI * t) - 1.0);
}
//https://www.shadertoy.com/view/ll2GD3
vec3 spectrum03(float n) {
    return pal( n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67) );
}
vec3 spectrum04(float n) {
    return pal( n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.10,0.20) );
}
vec3 spectrum05(float n) {
    return pal( n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.3,0.20,0.20) );
}
vec3 spectrum06(float n) {
    return pal( n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,0.5),vec3(0.8,0.90,0.30) );
}
vec3 spectrum07(float n) {
    return pal( n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,0.7,0.4),vec3(0.0,0.15,0.20) );
}
vec3 spectrum08(float n) {
    return pal( n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(2.0,1.0,0.0),vec3(0.5,0.20,0.25) );
}
vec3 spectrum09(float n) {
    return pal( n, vec3(0.8,0.5,0.4),vec3(0.2,0.4,0.2),vec3(2.0,1.0,1.0),vec3(0.0,0.25,0.25) );
}
vec3 spectrum10(float n, float3 c1) {
    return pal( n, c1,c1,vec3(1.0,1.0,1.0),vec3(0.0,0.25,0.25) );
}
vec3 spectrum11(float n) {
    return pal( n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67) );
}
vec3 spectrum(float n, float3 c1, float3 c2, float3 c3, float3 c4) {
    return pal( n, c1,c2,c3,c4);
}

vec3 spectrum02(float n) {
    return pal( n, vec3(0.5,0.5,0.5),vec3(0.5,0.5,0.5),vec3(1.0,1.0,1.0),vec3(0.0,0.33,0.67) );
}

//spectrum01 has discontinuities 
vec3 spectrum01(float x) {
    x = mod(x, 3.);
    return mix(
       mix(vec3(1, 1, 0), vec3(0, 1, 1), x),
       mix(vec3(1, 0, 1), vec3(1, 1, 0), x-2.),
       x-1.
    );
}

float isOdd(int x) {
    return float(x & 1) * 2. - 1.;
}

// should generate 4 1-bit RGB colors, where
// colors 0 and 2, and colors 1 and 3, can't be the same
float4x3 randCol(uint x) {
    uvec3 col0 = uvec3(
         x        & 1u,
        (x >> 1u) & 1u,
        (x >> 2u) & 1u
    );
    uvec3 col1 = uvec3(
        (x >> 3u) & 1u,
        (x >> 4u) & 1u,
        (x >> 5u) & 1u
    );
    uint y = x ^ ((x >> 6u) % 6u + 1u);
    uvec3 col2 = uvec3(
         y        & 1u,
        (y >> 1u) & 1u,
        (y >> 2u) & 1u
    );
    y = (x >> 3u) ^ ((x >> 9u) % 6u + 1u);
    uvec3 col3 = uvec3(
         y        & 1u,
        (y >> 1u) & 1u,
        (y >> 2u) & 1u
    );
    return float4x3(col0, col1, col2, col3);
}

float2x3 randCol2(uint x) {
    uvec3 col0 = uvec3(
         x        & 1u,
        (x >> 1u) & 1u,
        (x >> 2u) & 1u
    );
    uint y = x ^ ((x >> 3u) % 6u + 1u);
    uvec3 col2 = uvec3(
         y        & 1u,
        (y >> 1u) & 1u,
        (y >> 2u) & 1u
    );
    return float2x3(col0, col2);
}

uint roll0(uint2 xy, uint t) {
    const uint a = 1664525u;
    const uint m = 1013904223u;

    uint seed = 65538u * xy.x + 782651u * xy.y + 1979u * t;
    
    uint x0 = (seed * a) % m;
    uint x = (x0 * a) % m;
    
    return x & 65535u;
}
vec3 roll1(uint2 xy, uint t) {
    const uint a = 1664525u;
    const uint m = 1013904223u;

    uint seed = 1818420u * xy.x + 78265178u * xy.y + 237698117u * t;
    
    uint x0 = (seed * a) % m;
    uint x = (x0 * a) % m;
    
    vec3 xvec = vec3(x & 3u, (x >> 4u) & 3u, (x >> 8u) & 3u);
    return xvec / 3.;
}
vec3 roll2(uint2 xy, uint t) {
    const uint a = 1664525u;
    const uint m = 1013904223u;

    uint seed = 1818420u * xy.x + 78265178u * xy.y + 237698117u * t;
    
    uint x0 = (seed * a) % m;
    uint x = (x0 * a) % m;
    
    vec3 xvec = vec3(x & 3u, (x >> 4u) & 3u, (x >> 8u) & 3u);
    return xvec / 3.;
}
vec3 roll3(uint2 xy, uint t) {
    const uint a = 1664525u;
    const uint m = 1013904223u;

    uint seed = 1818420u * xy.x + 78265178u * xy.y + 237698117u * t;
    
    uint x0 = (seed * a) % m;
    uint x = (x0 * a) % m;
    
    vec3 xvec = vec3(x & 3u, (x >> 4u) & 3u, (x >> 8u) & 3u);
    return xvec / 3.;
}

////////////////////////////////////////////////////////////////
//
//             PRESETS
//
////////////////////////////////////////////////////////////////

//deepfry
vec3 fn01(vec2 rt) {
    return deepfry(hue01(rt.x * 3. + iTime), 1. + 0.5 * sin(rt.x * 6. + rt.y * 3. + iTime * 4.));
}
//spectrum
vec3 fn02(vec2 uv) {
    float distSq = uv.x*uv.x+uv.y*uv.y;
    float angle = atan(uv.x, uv.y);
    int ring = int(iTime + log(distSq) * 0.6);
    float rand = rcol02(uint(ring)) - 0.5;
    float angleAdd = (iTime * rand);
    
    return spectrum01(
        angleAdd + angle / TAU * 3. 
    );
}

//circles 
vec3 fn03(vec2 uv) {
    float rotLen = 10.;
    float distLen = 0.4;
    float loopLen = 60. * rotLen * distLen;
    
    float T = mod(iTime, loopLen);
    float distSq = uv.x*uv.x+uv.y*uv.y;
    float angle = atan(uv.x, uv.y);
    float angleAdd = fract(T / rotLen);
    float distAdd = fract(T / distLen);
    
    float which = (step(fract(angleAdd * 2. + angle * 2. / TAU + distSq * 0.21), .5));
    
    float progress = mod(which * 4. + distSq * 3. + T, loopLen);
    
    uint colID = fHash01(uint(int(progress)));
    float2x3 colors = randCol2(colID);
    vec3 colA = mix(colors[0], colors[1],
      logStripe(uv, distAdd, angleAdd * TAU)
    );
    vec3 colB = mix(colors[0], colors[1],
      logStripe(uv, distAdd, angleAdd * TAU + TAU / 4.)
    );
    
    vec3 col = mix(colA, colB, which) * 0.8 + fract(progress) * 0.2;    
    return col;
}

vec3 fn04(vec2 rt) {
    return deepfry(
        hue01(rt.x * 3. + iTime),
        1. + 0.5 * sin(rt.x * 6. + rt.y * 3. + iTime * 4.)
    );
}
//rainbowglitch
vec3 fn05(vec2 uv) {
    float Time = fract(iTime / 4.);
    uint time = uint(iTime * 20.);
    float linDis = distance(uv, (vec2)0);
    float lolDis = 14. * log(linDis) - 6. * linDis;
    
    vec2 rt = vec2(
        256. + lolDis +
        0.5 * sin(0.4 * lolDis + Time * 2. * TAU)
    ,
        256. + mod(atan(uv.x, uv.y) / TAU * 64. +
        0.3 * sin((0.2 * lolDis + 2.0 * Time) * TAU), 32.)
    );
    float x = smoothstep(0.4,0.6,float(roll0(uvec2(rt), time)) / 65536.);
    return vec3(
      (x)      * hue02(4.0 * Time + 0.4 * linDis) +
      (1. - x) * hue02(4.0 * Time + 0.6 * linDis)
    );
}

//undula [mild spaz?
vec3 fn06(vec2 uv) {
    float Time = fract(iTime / 4.);
    uint time = uint(floor(iTime * 5.));
    float linDis = distance(uv, (float2)0);
    float lolDis = 7. * log(linDis) - 3. * linDis;
    float angle = atan(uv.x, uv.y) / 3.14159265358979 / 2.;
    
    vec3 x = (float3)0;
    if (linDis < 0.15) {
        x = (float3)abs(1. - 2. * fract(-angle + 0.1 * lolDis + 4. * Time));
    } else {
        vec2 rt = vec2(256. + Time + lolDis + 0.5 * sin(0.4 * lolDis + Time * 2. * 3.14159265358979), 
                        256. + mod(angle * 32.0 + 0.3 * sin((0.2 * lolDis+Time * 2.0) * 3.14159265358979 * 2.),
                        32.));
        if (distance(fract(rt), (float2)0.5) < 0.5) {
            x = roll1(uint2(rt), time);
        }
    }
    return x;
}

//blep [spaz]
vec3 fn07(vec2 uv) {
    float Time = fract(iTime / 4.);
    uint time = uint(floor(iTime * 5.));
    float linDis = distance(uv, (float2)0);
    vec3 x;
    float angle = atan(uv.x, uv.y) / 3.14159265358979 / 2.;
    if (linDis < 0.15) {
        x = (float3)abs(1. - 2. * fract(- angle + 16. * linDis + Time));
    } else {
        float lolDis = 14. * log(linDis) - 6. * linDis;
    
        vec2 rt = vec2(256. + lolDis * 0.7 + 0.6 * sin(0.3 * lolDis + Time * 2. * 3.14159265358979), 256. + angle * 32.0);
    
        x = roll3(uint2(rt), time);
    }
    return x;
}

vec3 fn08(vec2 uv) {
    float time = fract(iTime / 12.);
    float hue = time * 2. * PI;

    float dist = log(uv.x*uv.x+uv.y*uv.y + 0.10) * 1.25;
    float angle = atan(uv.y, uv.x);
    const float spokes = float(17) / 2.;
    const float spokes2 = float(55) / 2.;
    
    float s1 = spikes(angle * spokes - time * 2. * PI);
    float s2 = spikes(angle * spokes2 + time * 2. * PI);
    float und = sin(angle + time * 2. * PI + 0.5 * dist);
    
    vec3 color = gradient(
        dist
        + (0.3 + 0.1 * sin(2. * time * PI)) * s1
        + (0.025 * (2. + sin(2. * time * PI + angle))) * s2
        + 0.15 * und
    );
    return color;
}

vec3 fn09(vec2 uv) { // star
    float t = fract(iTime / 8.);
    // Normalized pixel coordinates
    float dist = log(uv.x*uv.x+uv.y*uv.y); // not real distance, but useful for log spirals
    float angle = atan(uv.x, uv.y) / PI / 2.;
    float angleLayer = t / 5.;
    float offsetLayer = t * 3.;
    float spaceLayer = 0.5;
    vec3 colA = vec3(1.0, 0.3, 0.8);
    vec3 colB = vec3(0.3, 0.7, 1.0);
    vec3 colC = hue03(t * 2. * PI);
    vec3 col = (vec3)fold2(t * 16.);
    
    if (dist >= -8.) {
        for (float iRing = 0.; iRing < 25.; iRing += 1.) {
            if (star1(angle - (iRing * angleLayer), dist, 1.1) < spaceLayer * (iRing - offsetLayer) - 7.){
                switch (int(iRing) % 3) {
                    case 0:
                        col = colA;
                        break;
                    case 1:
                        col = colB;
                        break;
                    case 2:
                        col = colC;
                        break;
                }
            }
        }
    }
    return col;
}

float distCustom(float x, float y)
{
    float n = -0.5 * abs(x) + y;
    return log(
        x * x + 1.5 * n * n
    );
}
float spiralHeart(float x, float multi, float offset)
{
    return max(0.0, min(1.0, (sin(x * 3.14159265) + offset) * multi));
}


vec3 fn10(vec2 uv) { 
    const float PI_3 = PI / 3.;
    const float speed = 5.;
    const float density = 3.;
    const float period = 15.;
    const vec3 color1 = vec3(1.2, 0.5, 0.8);
    const vec3 color2 = vec3(0.3, 0.8, 1.0);
    
    float hue = iTime * 2. * PI / 5.;
    vec3 color3 = (vec3(sin(hue), sin(hue + 2. * PI_3), sin(hue - 2. * PI_3)) + 1.0) * .5;
    
    float dist = log(uv.x*uv.x+uv.y*uv.y) / 2.;
    float distH = distCustom(uv.x, uv.y);
    float angle = atan(uv.y, uv.x);
    
    float timeH = 32.0 * cos(smoothstep(0.0, 1.0, fract(iTime / 15.)) * PI);
    
    // Time varying pixel color
    float c1 = spiralHeart((distH + timeH) * density + 0.0, 1.8, -0.2);
    float c2 = spiralHeart((distH + timeH) * density + 0.8, 4., -0.7);
    float c3 = spiralHeart(dist * 4.0 + angle / PI + iTime * speed + PI, 3.0, -0.8);
    // Output to screen
    return vec3(
		c1 * color1 + c2 * color2 + c3 * color3
    );
    
}
vec3 rainbow(float x) {
    vec3 xyz = abs(mod(x + vec3(0.5,1.5,2.5), 3.) - 1.5);
    return 1.0 - pow(
        max((vec3)0.0, xyz * 2. - 1.)
    , (vec3)2.);
}

vec3 fn11 (vec2 uv) {
    // Time varying pixel color
    float dist = log(dot(uv, uv));
    float angle = atan(uv.y, uv.x) / 6.28318530718;
    vec3 col = rainbow(dist * 0.2 + angle * 3.0 + sin(iTime * 2.0 + dist * 2.0) * 0.2 + sin(1.4 + -iTime + dist * 0.7) * -0.2);    
}

//---------------------------------------------------------------------------------------------------------
// Math Functions
//---------------------------------------------------------------------------------------------------------
float3 interpolationC2(float3 x){ return x*x*x*(x*(x*6.0 - 15.0) + 10.0);}

float setRange(float value, float low, float high){ return saturate((value-low)/(high-low)); }

float3 setRangesSigned(float3 values, float low, float high){ return (values-low)/(high-low);}

float dilatePerlinWorley(float p, float w, float x){
	float curve = 0.75;
	if(x < 0.5){
		x /= 0.5;
		float n = p + w * x;
		return n * lerp(1, 0.5, pow(x,curve));
	}
	else{
		x = (x-0.5)/0.5;
		float n = w + p *(1.0 - x);
		return n * lerp(0.5, 1.0, pow(x, 1.0/curve));
	}
}


//to 1d functions


float rand4dTo1d(float4 value, float4 dotDir = float4(12.9898, 78.233, 37.719, 17.4265)){
	float4 smallValue = sin(value);
	float random = dot(smallValue, dotDir);
	random = frac(sin(random) * 143758.5453);
	return random;
}

//get a scalar random value from a 3d value
float rand3dTo1d(float3 value, float3 dotDir = float3(12.9898, 78.233, 37.719)){
	//make value smaller to avoid artefacts
	float3 smallValue = sin(value);
	//get scalar value from 3d vector
	float random = dot(smallValue, dotDir);
	//make value more random by making it bigger and then taking the factional part
	random = frac(sin(random) * 143758.5453);
	return random;
}

float rand2dTo1d(float2 value, float2 dotDir = float2(12.9898, 78.233)){
	float2 smallValue = sin(value);
	float random = dot(smallValue, dotDir);
	random = frac(sin(random) * 143758.5453);
	return random;
}

float rand1dTo1d(float3 value, float mutator = 0.546){
	float random = frac(sin(value + mutator) * 143758.5453);
	return random;
}

//to 2d functions

float2 rand3dTo2d(float3 value){
	return float2(
		rand3dTo1d(value, float3(12.989, 78.233, 37.719)),
		rand3dTo1d(value, float3(39.346, 11.135, 83.155))
	);
}

float2 rand2dTo2d(float2 value){
	return float2(
		rand2dTo1d(value, float2(12.989, 78.233)),
		rand2dTo1d(value, float2(39.346, 11.135))
	);
}

float2 rand1dTo2d(float value){
	return float2(
		rand2dTo1d(value, 3.9812),
		rand2dTo1d(value, 7.1536)
	);
}

//to 3d functions

float3 rand3dTo3d(float3 value){
	return float3(
		rand3dTo1d(value, float3(12.989, 78.233, 37.719)),
		rand3dTo1d(value, float3(39.346, 11.135, 83.155)),
		rand3dTo1d(value, float3(73.156, 52.235, 09.151))
	);
}

float3 rand2dTo3d(float2 value){
	return float3(
		rand2dTo1d(value, float2(12.989, 78.233)),
		rand2dTo1d(value, float2(39.346, 11.135)),
		rand2dTo1d(value, float2(73.156, 52.235))
	);
}

float3 rand1dTo3d(float value){
	return float3(
		rand1dTo1d(value, 3.9812),
		rand1dTo1d(value, 7.1536),
		rand1dTo1d(value, 5.7241)
	);
}

// to 4d // TEMP
float4 rand4dTo4d(float4 value){
	return float4(
		rand4dTo1d(value, float4(12.989, 78.233, 37.719, -12.15)),
		rand4dTo1d(value, float4(39.346, 11.135, 83.155, -11.44)),
		rand4dTo1d(value, float4(73.156, 52.235, 09.151, 62.463)),
		rand4dTo1d(value, float4(-12.15, 12.235, 41.151, -1.135))
	);
}

float rand2to1(float2 co) 
{
    return frac(sin(dot(co.xy, float2(12.9898, 78.233))) * 43758.5453);
}

//---------------------------------------------------------------------------------------------------------
// Perlin Noise
//---------------------------------------------------------------------------------------------------------
void perlinHash(float3 gridcell, float s, bool tile,
				out float4 lowzHash0, out float4 lowzHash1, out float4 lowzHash2,
				out float4 highzHash0, out float4 highzHash1, out float4 highzHash2 )
{
	const float2 OFFSET = float2( 50.0, 161.0 );
	const float DOMAIN = 69.0;
	const float3 SOMELARGEFLOATS = float3(635.298681, 682.357502, 668.926525);
	const float3 ZINC = float3(48.500388, 65.294118, 63.934599);

	gridcell.xyz =  gridcell.xyz - floor(gridcell.xyz * (1.0 / DOMAIN)) * DOMAIN;
	float d = DOMAIN - 1.5;
	float3 gridcellInc1 = step(gridcell, float3(d,d,d)) * (gridcell + 1.0);

	gridcellInc1 = tile ? gridcellInc1 % s : gridcellInc1;

	float4 p = float4(gridcell.xy, gridcellInc1.xy) + OFFSET.xyxy;
	p *= p;
	p = p.xzxz * p.yyww;
	float3 lowzMod = float3(1.0 / (SOMELARGEFLOATS.xyz + gridcell.zzz * ZINC.xyz));
	float3 highzMod = float3(1.0 / (SOMELARGEFLOATS.xyz + gridcellInc1.zzz * ZINC.xyz));
	lowzHash0 = frac(p*lowzMod.xxxx);
	highzHash0 = frac(p*highzMod.xxxx);
	lowzHash1 = frac(p*lowzMod.yyyy);
	highzHash1 = frac(p*highzMod.yyyy);
	lowzHash2 = frac(p*lowzMod.zzzz);
	highzHash2 = frac(p*highzMod.zzzz);
}

float perlin(float3 p, float s, bool tile){
	p *= s;

	float3 pI = floor(p);
	float3 pI2 = floor(p);
	float3 pF = p - pI;
	float3 pFMin1 = pF - 1.0;

	float4 hashx0, hashy0, hashz0, hashx1, hashy1, hashz1;
	perlinHash(pI2, s, tile, hashx0, hashy0, hashz0, hashx1, hashy1, hashz1);

	float4 gradx0 = hashx0 - 0.49999;
	float4 grady0 = hashy0 - 0.49999;
	float4 gradz0 = hashz0 - 0.49999;
	float4 gradx1 = hashx1 - 0.49999;
	float4 grady1 = hashy1 - 0.49999;
	float4 gradz1 = hashz1 - 0.49999;
	float4 gradResults0 = rsqrt(gradx0 * gradx0 + grady0 * grady0 + gradz0 * gradz0) * (float2(pF.x, pFMin1.x).xyxy * gradx0 + float2(pF.y, pFMin1.y).xxyy * grady0 + pF.zzzz * gradz0);
	float4 gradResults1 = rsqrt(gradx1 * gradx1 + grady1 * grady1 + gradz1 * gradz1) * (float2(pF.x, pFMin1.x).xyxy * gradx1 + float2(pF.y, pFMin1.y).xxyy * grady1 + pFMin1.zzzz * gradz1);

	float3 blend = interpolationC2(pF);
	float4 res0 = lerp(gradResults0, gradResults1, blend.z);
	float4 blend2 = float4(blend.xy, float2(1.0 - blend.xy));
	float final = dot(res0, blend2.zxzx * blend2.wwyy);
	final *= 1.0/sqrt(0.75);
	return ((final * 1.5) + 1.0) * 0.5;
}

float perlin(float3 p){
	return perlin(p, 1, false);
}

float perlin5(float3 p, bool tile){
	float3 xyz = p;
	float amplitudeFactor = 0.5;
	float frequencyFactor = 2.0;

	float a = 1.0;
	float val = 0.0;
	val += a * perlin(xyz).r; a *= amplitudeFactor; xyz *= (frequencyFactor + 0.02);
	val += a * perlin(xyz).r; a *= amplitudeFactor; xyz *= (frequencyFactor + 0.03);
	val += a * perlin(xyz).r; a *= amplitudeFactor; xyz *= (frequencyFactor + 0.01);
	val += a * perlin(xyz).r; a *= amplitudeFactor; xyz *= (frequencyFactor + 0.01);
	val += a * perlin(xyz).r;

	return val;
}

float perlin7(float3 p, float s){
	float3 xyz = p;
	float f = 1.0;
	float a = 1.0;

	float val = 0.0;
	val += a * perlin(xyz, s*f, true).r; a *= 0.5; f*= 2.0;
	val += a * perlin(xyz, s*f, true).r; a *= 0.5; f*= 2.0;
	val += a * perlin(xyz, s*f, true).r; a *= 0.5; f*= 2.0;
	val += a * perlin(xyz, s*f, true).r; a *= 0.5; f*= 2.0;
	val += a * perlin(xyz, s*f, true).r; a *= 0.5; f*= 2.0;
	val += a * perlin(xyz, s*f, true).r; a *= 0.5; f*= 2.0;
	val += a * perlin(xyz, s*f, true).r; a *= 0.5; f*= 2.0;

	return val;
}


//---------------------------------------------------------------------------------------------------------
// Curl Noise
//---------------------------------------------------------------------------------------------------------
float3 encodeCurl(float3 c){
	return (c + 1.0) * 0.5;
}

float3 curlNoise(float3 p){
	float e = 0.05;
	float n1, n2, a, b;
	float3 c;

	n1 = perlin5(p.xyz + float3(0,e,0), true);
	n2 = perlin5(p.xyz + float3(0,-e,0), true);
	a = (n1-n2)/(2*e);
	n1 = perlin5(p.xyz + float3(0,0,e), true);
	n2 = perlin5(p.xyz + float3(0,0,-e), true);
	b = (n1-n2)/(2*e);

	c.x = a - b;

	n1 = perlin5(p.xyz + float3(0,0,e), true);
	n2 = perlin5(p.xyz + float3(0,0,-e), true);
	a = (n1-n2)/(2*e);
	n1 = perlin5(p.xyz + float3(e,0,0), true);
	n2 = perlin5(p.xyz + float3(-e,0,0), true);
	b = (n1-n2)/(2*e);

	c.y = a - b;

	n1 = perlin5(p.xyz + float3(e,0,0), true);
	n2 = perlin5(p.xyz + float3(-e,0,0), true);
	a = (n1-n2)/(2*e);
	n1 = perlin5(p.xyz + float3(0,e,0), true);
	n2 = perlin5(p.xyz + float3(0,-e,0), true);
	b = (n1-n2)/(2*e);

	c.z = a - b;

	return c;
}

//---------------------------------------------------------------------------------------------------------
// Cellular Noise
//---------------------------------------------------------------------------------------------------------
float3 voronoi_hash(float3 x, float s){
	x = x % s;
	x = float3(dot(x, float3(127.1, 311.7, 74.7)),
				dot(x, float3(269.5,183.3,246.1)),
				dot(x, float3(113.5,271.9,124.6)));
	return frac(sin(x) * 43758.5453123);
}

float3 voronoi( in float3 x, float s, bool inverted){
	x *= s;
	x += 0.5;
	float3 p = floor(x);
	float3 f = frac(x);

	float id = 0.0;
	float2 res = float2(1.0, 1.0);
	for(int k = -1; k <= 1; k++){
		for(int j = -1; j <= 1; j++){
			for(int i = -1; i <= 1; i++){
				float3 b = float3(i,j,k);
				float3 r = float3(b) - f + voronoi_hash(p+b, s);
				float d = dot(r,r);

				if(d < res.x){
					id = dot(p+b, float3(1.0, 57.0, 113.0));
					res = float2(d, res.x);
				}
				else if(d < res.y){
					res.y = d;
				}
			}
		}
	}
	float2 result = res;
	id = abs(id);
	if(inverted)
		return float3(1.0 - result, id);
	else
		return float3(result, id);
}

float worley3(float3 p, float s){
	float3 xyz = p;

	float val1 = voronoi(xyz, 1.0 * s, true).r;
	float val2 = voronoi(xyz, 2.0 * s, false).r;
	float val3 = voronoi(xyz, 4.0 * s, false).r;

	val1 = saturate(val1);
	val2 = saturate(val2);
	val3 = saturate(val3);

	float worleyVal = val1;
	worleyVal = worleyVal - val2 * 0.3;
	worleyVal = worleyVal - val3 * 0.3;

	return worleyVal;	
}

////////////////////////////////////////////////////////////////
//
//             HELPER FUNCTIONS/MACROS
//
////////////////////////////////////////////////////////////////

// Sign function that doesn't return 0
float sgn(float x) {
	return (x<0)?-1:1;
}

vec2 sgn(vec2 v) {
	return vec2((v.x<0)?-1:1, (v.y<0)?-1:1);
}

float square (float x) {
	return x*x;
}

vec2 square (vec2 x) {
	return x*x;
}

vec3 square (vec3 x) {
	return x*x;
}

float lengthSqr(vec3 x) {
	return dot(x, x);
}


// Maximum/minumum elements of a vector
float vmax(vec2 v) {
	return max(v.x, v.y);
}

float vmax(vec3 v) {
	return max(max(v.x, v.y), v.z);
}

float vmax(vec4 v) {
	return max(max(v.x, v.y), max(v.z, v.w));
}

float vmin(vec2 v) {
	return min(v.x, v.y);
}

float vmin(vec3 v) {
	return min(min(v.x, v.y), v.z);
}

float vmin(vec4 v) {
	return min(min(v.x, v.y), min(v.z, v.w));
}

/*
################### Start Region Noise ###################
*/
// Fast and "discontinuous" random noise.
float random (in float4 st) {
	return frac(
		cos(
			dot(
				st, 
				float4(
					12.9898,
					78.233,
					123.691,
					43.7039
				)
			)
		)
		* 43758.5453123
	);
}

float random (in float3 st) {
	return frac(
		cos(
			dot(
				st, 
				float3(
					12.9898,
					78.233,
					123.691
				)
			)
		)
		* 43758.5453123
	);
}

float random (in float2 st) {
	return frac(
		cos(
			dot(
				st, 
				float2(
					12.9898,
					78.233
				)
			)
		)
		* 43758.5453123
	);
}

float random (in float st) {
	return frac(cos(st.x * 12.9898) * 43758.5453123);
}
/*

Description:
	Array- and textureless CgFx/HLSL 2D, 3D and 4D simplex noise functions.
	a.k.a. simplified and optimized Perlin noise.
	
	The functions have very good performance
	and no dependencies on external data.
	
	2D - Very fast, very compact code.
	3D - Fast, compact code.
	4D - Reasonably fast, reasonably compact code.

------------------------------------------------------------------

Ported by:
	Lex-DRL
	I've ported the code from GLSL to CgFx/HLSL for Unity,
	added a couple more optimisations (to speed it up even further)
	and slightly reformatted the code to make it more readable.

Original GLSL functions:
	https://github.com/ashima/webgl-noise
	Credits from original glsl file are at the end of this cginc.

------------------------------------------------------------------

Usage:
	
	float ns = snoise(v);
	// v is any of: float2, float3, float4
	
	Return type is float.
	To generate 2 or more components of noise (colorful noise),
	call these functions several times with different
	constant offsets for the arguments.
	E.g.:
	
	float3 colorNs = float3(
		snoise(v),
		snoise(v + 17.0),
		snoise(v - 43.0),
	);


Remark about those offsets from the original author:
	
	People have different opinions on whether these offsets should be integers
	for the classic noise functions to match the spacing of the zeroes,
	so we have left that for you to decide for yourself.
	For most applications, the exact offsets don't really matter as long
	as they are not too small or too close to the noise lattice period
	(289 in this implementation).

*/

// 1 / 289
#define NOISE_SIMPLEX_1_DIV_289 0.00346020761245674740484429065744f

float mod289(float x) {
	return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}

float2 mod289(float2 x) {
	return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}

float3 mod289(float3 x) {
	return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}

float4 mod289(float4 x) {
	return x - floor(x * NOISE_SIMPLEX_1_DIV_289) * 289.0;
}


// ( x*34.0 + 1.0 )*x = 
// x*x*34.0 + x
float permute(float x) {
	return mod289(
		x*x*34.0 + x
	);
}

float3 permute(float3 x) {
	return mod289(
		x*x*34.0 + x
	);
}

float4 permute(float4 x) {
	return mod289(
		x*x*34.0 + x
	);
}



float4 grad4(float j, float4 ip)
{
	const float4 ones = float4(1.0, 1.0, 1.0, -1.0);
	float4 p, s;
	p.xyz = floor( frac(j * ip.xyz) * 7.0) * ip.z - 1.0;
	p.w = 1.5 - dot( abs(p.xyz), ones.xyz );
	
	// GLSL: lessThan(x, y) = x < y
	// HLSL: 1 - step(y, x) = x < y
	p.xyz -= sign(p.xyz) * (p.w < 0);
	
	return p;
}



// ----------------------------------- 2D -------------------------------------

float snoise(float2 v)
{
	const float4 C = float4(
		0.211324865405187, // (3.0-sqrt(3.0))/6.0
		0.366025403784439, // 0.5*(sqrt(3.0)-1.0)
	 -0.577350269189626, // -1.0 + 2.0 * C.x
		0.024390243902439  // 1.0 / 41.0
	);
	
// First corner
	float2 i = floor( v + dot(v, C.yy) );
	float2 x0 = v - i + dot(i, C.xx);
	
// Other corners
	// float2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
	// Lex-DRL: afaik, step() in GPU is faster than if(), so:
	// step(x, y) = x <= y
	
	// Actually, a simple conditional without branching is faster than that madness :)
	int2 i1 = (x0.x > x0.y) ? float2(1.0, 0.0) : float2(0.0, 1.0);
	float4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	
// Permutations
	i = mod289(i); // Avoid truncation effects in permutation
	float3 p = permute(
		permute(
				i.y + float3(0.0, i1.y, 1.0 )
		) + i.x + float3(0.0, i1.x, 1.0 )
	);
	
	float3 m = max(
		0.5 - float3(
			dot(x0, x0),
			dot(x12.xy, x12.xy),
			dot(x12.zw, x12.zw)
		),
		0.0
	);
	m = m*m ;
	m = m*m ;
	
// Gradients: 41 points uniformly over a line, mapped onto a diamond.
// The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)
	
	float3 x = 2.0 * frac(p * C.www) - 1.0;
	float3 h = abs(x) - 0.5;
	float3 ox = floor(x + 0.5);
	float3 a0 = x - ox;

// Normalise gradients implicitly by scaling m
// Approximation of: m *= inversesqrt( a0*a0 + h*h );
	m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );

// Compute final noise value at P
	float3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}


#define madfrac(A,B) mad((A),(B),-floor((A)*(B)))


float inverseSF(float3 p, float n) {
    float phi = min(atan2(p.y, p.x), PI), cosTheta = p.z;

    float k = max(2, floor(
        log(n * PI * sqrt(5) * (1 - cosTheta*cosTheta))
            / log(PHI*PHI)));

    float Fk = pow(PHI, k)/sqrt(5);
    float F0 = round(Fk), F1 = round(Fk * PHI);

    float2x2 B = float2x2(
        2*PI*madfrac(F0+1, PHI-1) - 2*PI*(PHI-1),
        2*PI*madfrac(F1+1, PHI-1) - 2*PI*(PHI-1),
        -2*F0/n,
        -2*F1/n);
    float2x2 invB = float2x2(B._22, -B._12, -B._21, B._11)/(B._11*B._22-B._12*B._21);
    float2 c = floor(mul(invB, float2(phi, cosTheta - (1-1/n))));

    float d = 100000, j = 0;
    for (uint s = 0; s < 4; ++s)
    {
        float cosTheta = dot(B[1], float2(s%2, s/2) + c) + (1-1/n);
        cosTheta = clamp(cosTheta, -1, +1)*2 - cosTheta;
        
        float i = floor(n*0.5 - cosTheta*n*0.5);
        float phi = 2*PI*madfrac(i, PHI-1);
        cosTheta = 1 - (2*i + 1)*rcp(n);
        float sinTheta = sqrt(1 - cosTheta*cosTheta);
        
        float3 q = float3(
            cos(phi)*sinTheta,
            sin(phi)*sinTheta,
            cosTheta);
        
        float squaredDistance = dot(q-p, q-p);
        if (squaredDistance < d)
        {
            d = squaredDistance;
            j = i;
        }
    }
    return sqrt(d);
}


//Example usage of inverseSF
// float dist(float3 p)
// {
//     float dist = i_sphere(p, float4(0, 0, 0, 0.5));
//     return dist + inverseSF(normalize(p), 256.0)*0.6-0.1;
// }
//modified to put out vector q and a float2
float2 inverseSF2(float3 p, float n, out vec3 outq) {
    float phi = min(atan2(p.y, p.x), PI), cosTheta = p.z;

    float k = max(2, floor(
        log(n * PI * sqrt(5) * (1 - cosTheta*cosTheta))
            / log(PHI*PHI)));

    float Fk = pow(PHI, k)/sqrt(5);
    float F0 = round(Fk), F1 = round(Fk * PHI);

    float2x2 B = float2x2(
        2*PI*madfrac(F0+1, PHI-1) - 2*PI*(PHI-1),
        2*PI*madfrac(F1+1, PHI-1) - 2*PI*(PHI-1),
        -2*F0/n,
        -2*F1/n);
    float2x2 invB = float2x2(B._22, -B._12, -B._21, B._11)/(B._11*B._22-B._12*B._21);
    float2 c = floor(mul(invB, float2(phi, cosTheta - (1-1/n))));

    float d = 100000, j = 0;
    for (uint s = 0; s < 4; ++s)
    {
        float cosTheta = dot(B[1], float2(s%2, s/2) + c) + (1-1/n);
        cosTheta = clamp(cosTheta, -1, +1)*2 - cosTheta;
        
        float i = floor(n*0.5 - cosTheta*n*0.5);
        float phi = 2*PI*madfrac(i, PHI-1);
        cosTheta = 1 - (2*i + 1)*rcp(n);
        float sinTheta = sqrt(1 - cosTheta*cosTheta);
        
        float3 q = float3(
            cos(phi)*sinTheta,
            sin(phi)*sinTheta,
            cosTheta);
        
        float squaredDistance = dot(q-p, q-p);
        if (squaredDistance < d)
        {
            outq = q;
            d = squaredDistance;
            j = i;
        }
    }
    return vec2(j, sqrt(d));
}

// Originally from https://www.shadertoy.com/view/lllXz4
// Modified by fizzer to put out the vector q.
vec2 inverseSF3( vec3 p, float n, out vec3 outq ) 
{
    float m = 1.0 - 1.0/n;
    
    float phi = min(atan(p.y, p.x), PI), cosTheta = p.z;
    
    float k  = max(2.0, floor( log(n * PI * sqrt(5.0) * (1.0 - cosTheta*cosTheta))/ log(PHI+1.0)));
    float Fk = pow(PHI, k)/sqrt(5.0);
    vec2  F  = vec2( round(Fk), round(Fk * PHI) ); // k, k+1

    vec2 ka = 2.0*F/n;
    vec2 kb = 2.0*PI*( fract((F+1.0)*PHI) - (PHI-1.0) );    
    
    float2x2 iB = float2x2( ka.y, -ka.x, 
                    kb.y, -kb.x ) / (ka.y*kb.x - ka.x*kb.y);
    
    vec2 c = floor( mul(iB,vec2(phi, cosTheta - m)));
    float d = 8.0;
    float j = 0.0;
    for( int s=0; s<4; s++ ) 
    {
        vec2 uv = vec2( float(s-2*(s/2)), float(s/2) );
        
        float i = round(dot(F, uv + c));
        
        float phi = 2.0*PI*fract(i*PHI);
        float cosTheta = m - 2.0*i/n;
        float sinTheta = sqrt(1.0 - cosTheta*cosTheta);
        
        vec3 q = vec3( cos(phi)*sinTheta, sin(phi)*sinTheta, cosTheta );
        float squaredDistance = dot(q-p, q-p);
        if (squaredDistance < d) 
        {
            outq = q;
            d = squaredDistance;
            j = i;
        }
    }
    return vec2( j, sqrt(d) );
}


float3 SF(uint i, uint count) 
{
    const float golden_ratio = 1.61803398875; // (1 + sqrt(5)) / 2.0
    const float pi = 3.14159265359;
    
    float u_x = (i + 0.5) / count;
    float u_y = frac(i * golden_ratio);
    
    float phi = acos(1.0 - 2.0 * u_x);
    float theta = 2.0 * pi * u_y;
    float x = sin(phi) * cos(theta);
    float y = sin(phi) * sin(theta);
    float z = cos(phi);
    
    return float3(x, y, z);
}

// ----------------------------------- 3D -------------------------------------

float snoise(float3 v)
{
	const float2 C = float2(
		0.166666666666666667, // 1/6
		0.333333333333333333  // 1/3
	);
	const float4 D = float4(0.0, 0.5, 1.0, 2.0);
	
// First corner
	float3 i = floor( v + dot(v, C.yyy) );
	float3 x0 = v - i + dot(i, C.xxx);
	
// Other corners
	float3 g = step(x0.yzx, x0.xyz);
	float3 l = 1 - g;
	float3 i1 = min(g.xyz, l.zxy);
	float3 i2 = max(g.xyz, l.zxy);
	
	float3 x1 = x0 - i1 + C.xxx;
	float3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
	float3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y
	
// Permutations
	i = mod289(i);
	float4 p = permute(
		permute(
			permute(
					i.z + float4(0.0, i1.z, i2.z, 1.0 )
			) + i.y + float4(0.0, i1.y, i2.y, 1.0 )
		) 	+ i.x + float4(0.0, i1.x, i2.x, 1.0 )
	);
	
// Gradients: 7x7 points over a square, mapped onto an octahedron.
// The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
	float n_ = 0.142857142857; // 1/7
	float3 ns = n_ * D.wyz - D.xzx;
	
	float4 j = p - 49.0 * floor(p * ns.z * ns.z); // mod(p,7*7)
	
	float4 x_ = floor(j * ns.z);
	float4 y_ = floor(j - 7.0 * x_ ); // mod(j,N)
	
	float4 x = x_ *ns.x + ns.yyyy;
	float4 y = y_ *ns.x + ns.yyyy;
	float4 h = 1.0 - abs(x) - abs(y);
	
	float4 b0 = float4( x.xy, y.xy );
	float4 b1 = float4( x.zw, y.zw );
	
	//float4 s0 = float4(lessThan(b0,0.0))*2.0 - 1.0;
	//float4 s1 = float4(lessThan(b1,0.0))*2.0 - 1.0;
	float4 s0 = floor(b0)*2.0 + 1.0;
	float4 s1 = floor(b1)*2.0 + 1.0;
	float4 sh = -step(h, 0.0);
	
	float4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
	float4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;
	
	float3 p0 = float3(a0.xy,h.x);
	float3 p1 = float3(a0.zw,h.y);
	float3 p2 = float3(a1.xy,h.z);
	float3 p3 = float3(a1.zw,h.w);
	
//Normalise gradients
	float4 norm = rsqrt(float4(
		dot(p0, p0),
		dot(p1, p1),
		dot(p2, p2),
		dot(p3, p3)
	));
	p0 *= norm.x;
	p1 *= norm.y;
	p2 *= norm.z;
	p3 *= norm.w;
	
// Mix final noise value
	float4 m = max(
		0.6 - float4(
			dot(x0, x0),
			dot(x1, x1),
			dot(x2, x2),
			dot(x3, x3)
		),
		0.0
	);
	m = m * m;
	return 42.0 * dot(
		m*m,
		float4(
			dot(p0, x0),
			dot(p1, x1),
			dot(p2, x2),
			dot(p3, x3)
		)
	);
}

// ----------------------------------- 4D -------------------------------------

float snoise(float4 v)
{
	const float4 C = float4(
		0.138196601125011, // (5 - sqrt(5))/20 G4
		0.276393202250021, // 2 * G4
		0.414589803375032, // 3 * G4
	 -0.447213595499958  // -1 + 4 * G4
	);

// First corner
	float4 i = floor(
		v +
		dot(
			v,
			0.309016994374947451 // (sqrt(5) - 1) / 4
		)
	);
	float4 x0 = v - i + dot(i, C.xxxx);

// Other corners

// Rank sorting originally contributed by Bill Licea-Kane, AMD (formerly ATI)
	float4 i0;
	float3 isX = step( x0.yzw, x0.xxx );
	float3 isYZ = step( x0.zww, x0.yyz );
	i0.x = isX.x + isX.y + isX.z;
	i0.yzw = 1.0 - isX;
	i0.y += isYZ.x + isYZ.y;
	i0.zw += 1.0 - isYZ.xy;
	i0.z += isYZ.z;
	i0.w += 1.0 - isYZ.z;

	// i0 now contains the unique values 0,1,2,3 in each channel
	float4 i3 = saturate(i0);
	float4 i2 = saturate(i0-1.0);
	float4 i1 = saturate(i0-2.0);

	//	x0 = x0 - 0.0 + 0.0 * C.xxxx
	//	x1 = x0 - i1  + 1.0 * C.xxxx
	//	x2 = x0 - i2  + 2.0 * C.xxxx
	//	x3 = x0 - i3  + 3.0 * C.xxxx
	//	x4 = x0 - 1.0 + 4.0 * C.xxxx
	float4 x1 = x0 - i1 + C.xxxx;
	float4 x2 = x0 - i2 + C.yyyy;
	float4 x3 = x0 - i3 + C.zzzz;
	float4 x4 = x0 + C.wwww;

// Permutations
	i = mod289(i); 
	float j0 = permute(
		permute(
			permute(
				permute(i.w) + i.z
			) + i.y
		) + i.x
	);
	float4 j1 = permute(
		permute(
			permute(
				permute (
					i.w + float4(i1.w, i2.w, i3.w, 1.0 )
				) + i.z + float4(i1.z, i2.z, i3.z, 1.0 )
			) + i.y + float4(i1.y, i2.y, i3.y, 1.0 )
		) + i.x + float4(i1.x, i2.x, i3.x, 1.0 )
	);

// Gradients: 7x7x6 points over a cube, mapped onto a 4-cross polytope
// 7*7*6 = 294, which is close to the ring size 17*17 = 289.
	const float4 ip = float4(
		0.003401360544217687075, // 1/294
		0.020408163265306122449, // 1/49
		0.142857142857142857143, // 1/7
		0.0
	);

	float4 p0 = grad4(j0, ip);
	float4 p1 = grad4(j1.x, ip);
	float4 p2 = grad4(j1.y, ip);
	float4 p3 = grad4(j1.z, ip);
	float4 p4 = grad4(j1.w, ip);

// Normalise gradients
	float4 norm = rsqrt(float4(
		dot(p0, p0),
		dot(p1, p1),
		dot(p2, p2),
		dot(p3, p3)
	));
	p0 *= norm.x;
	p1 *= norm.y;
	p2 *= norm.z;
	p3 *= norm.w;
	p4 *= rsqrt( dot(p4, p4) );

// Mix contributions from the five corners
	float3 m0 = max(
		0.6 - float3(
			dot(x0, x0),
			dot(x1, x1),
			dot(x2, x2)
		),
		0.0
	);
	float2 m1 = max(
		0.6 - float2(
			dot(x3, x3),
			dot(x4, x4)
		),
		0.0
	);
	m0 = m0 * m0;
	m1 = m1 * m1;
	
	return 49.0 * (
		dot(
			m0*m0,
			float3(
				dot(p0, x0),
				dot(p1, x1),
				dot(p2, x2)
			)
		) + dot(
			m1*m1,
			float2(
				dot(p3, x3),
				dot(p4, x4)
			)
		)
	);
}



//                 Credits from source glsl file:
//
// Description : Array and textureless GLSL 2D/3D/4D simplex 
//               noise functions.
//      Author : Ian McEwan, Ashima Arts.
//  Maintainer : ijm
//     Lastmod : 20110822 (ijm)
//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
//               Distributed under the MIT License. See LICENSE file.
//               https://github.com/ashima/webgl-noise
//
//
//           The text from LICENSE file:
//
//
// Copyright (C) 2011 by Ashima Arts (Simplex noise)
// Copyright (C) 2011 by Stefan Gustavson (Classic noise)
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE. 

//
// Noise Shader Library for Unity - https://github.com/keijiro/NoiseShader
//
// Original work (webgl-noise) Copyright (C) 2011 Ashima Arts.
// Translation and modification was made by Keijiro Takahashi.
//
// This shader is based on the webgl-noise GLSL shader. For further details
// of the original shader, please see the following description from the
// original source code.
//

//
// Description : Array and textureless GLSL 2D/3D/4D simplex
//               noise functions.
//      Author : Ian McEwan, Ashima Arts.
//  Maintainer : ijm
//     Lastmod : 20110822 (ijm)
//     License : Copyright (C) 2011 Ashima Arts. All rights reserved.
//               Distributed under the MIT License. See LICENSE file.
//               https://github.com/ashima/webgl-noise
//



float4 taylorInvSqrt(float4 r)
{
    return 1.79284291400159 - r * 0.85373472095314;
}

float4 snoise_grad(float3 v)
{
    const float2 C = float2(1.0 / 6.0, 1.0 / 3.0);

    // First corner
    float3 i  = floor(v + dot(v, C.yyy));
    float3 x0 = v   - i + dot(i, C.xxx);

    // Other corners
    float3 g = step(x0.yzx, x0.xyz);
    float3 l = 1.0 - g;
    float3 i1 = min(g.xyz, l.zxy);
    float3 i2 = max(g.xyz, l.zxy);

    // x1 = x0 - i1  + 1.0 * C.xxx;
    // x2 = x0 - i2  + 2.0 * C.xxx;
    // x3 = x0 - 1.0 + 3.0 * C.xxx;
    float3 x1 = x0 - i1 + C.xxx;
    float3 x2 = x0 - i2 + C.yyy;
    float3 x3 = x0 - 0.5;

    // Permutations
    i = mod289(i); // Avoid truncation effects in permutation
    float4 p =
      permute(permute(permute(i.z + float4(0.0, i1.z, i2.z, 1.0))
                            + i.y + float4(0.0, i1.y, i2.y, 1.0))
                            + i.x + float4(0.0, i1.x, i2.x, 1.0));

    // Gradients: 7x7 points over a square, mapped onto an octahedron.
    // The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
    float4 j = p - 49.0 * floor(p / 49.0);  // mod(p,7*7)

    float4 x_ = floor(j / 7.0);
    float4 y_ = floor(j - 7.0 * x_);  // mod(j,N)

    float4 x = (x_ * 2.0 + 0.5) / 7.0 - 1.0;
    float4 y = (y_ * 2.0 + 0.5) / 7.0 - 1.0;

    float4 h = 1.0 - abs(x) - abs(y);

    float4 b0 = float4(x.xy, y.xy);
    float4 b1 = float4(x.zw, y.zw);

    //float4 s0 = float4(lessThan(b0, 0.0)) * 2.0 - 1.0;
    //float4 s1 = float4(lessThan(b1, 0.0)) * 2.0 - 1.0;
    float4 s0 = floor(b0) * 2.0 + 1.0;
    float4 s1 = floor(b1) * 2.0 + 1.0;
    float4 sh = -step(h, 0.0);

    float4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    float4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    float3 g0 = float3(a0.xy, h.x);
    float3 g1 = float3(a0.zw, h.y);
    float3 g2 = float3(a1.xy, h.z);
    float3 g3 = float3(a1.zw, h.w);

    // Normalise gradients
    float4 norm = taylorInvSqrt(float4(dot(g0, g0), dot(g1, g1), dot(g2, g2), dot(g3, g3)));
    g0 *= norm.x;
    g1 *= norm.y;
    g2 *= norm.z;
    g3 *= norm.w;

    // Compute noise and gradient at P
    float4 m = max(0.6 - float4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
    float4 m2 = m * m;
    float4 m3 = m2 * m;
    float4 m4 = m2 * m2;
    float3 grad =
        -6.0 * m3.x * x0 * dot(x0, g0) + m4.x * g0 +
        -6.0 * m3.y * x1 * dot(x1, g1) + m4.y * g1 +
        -6.0 * m3.z * x2 * dot(x2, g2) + m4.z * g2 +
        -6.0 * m3.w * x3 * dot(x3, g3) + m4.w * g3;
    float4 px = float4(dot(x0, g0), dot(x1, g1), dot(x2, g2), dot(x3, g3));
    return 42.0 * float4(grad, dot(m4, px));
}


/*
###################  End Region Noise ###################
*/

/*
###################  Start Region Utils ###################
*/


#define EL_PHI (sqrt(5.0) * 0.5 + 0.5)

/**
 * Performs a matrix inverse.
 *
 * @param input the input matrix.
 * @return the inverted matrix. If the matrix is not invertible the behaviour is undefined.
 */
float4x4 ELMatrixInverse(float4x4 input)
{
    #define minor(a, b, c) determinant(float3x3(input.a, input.b, input.c))
   
    float4x4 cofactors = float4x4(
        minor(_22_23_24, _32_33_34, _42_43_44), 
       -minor(_21_23_24, _31_33_34, _41_43_44),
        minor(_21_22_24, _31_32_34, _41_42_44),
       -minor(_21_22_23, _31_32_33, _41_42_43),
       
       -minor(_12_13_14, _32_33_34, _42_43_44),
        minor(_11_13_14, _31_33_34, _41_43_44),
       -minor(_11_12_14, _31_32_34, _41_42_44),
        minor(_11_12_13, _31_32_33, _41_42_43),
       
        minor(_12_13_14, _22_23_24, _42_43_44),
       -minor(_11_13_14, _21_23_24, _41_43_44),
        minor(_11_12_14, _21_22_24, _41_42_44),
       -minor(_11_12_13, _21_22_23, _41_42_43),
       
       -minor(_12_13_14, _22_23_24, _32_33_34),
        minor(_11_13_14, _21_23_24, _31_33_34),
       -minor(_11_12_14, _21_22_24, _31_32_34),
        minor(_11_12_13, _21_22_23, _31_32_33));

   #undef minor
   return transpose(cofactors) / determinant(input);
}
//Should maybe be transposed because glsl is col major and hlsl is row major.
float3x3 rotX(float a)
{
    return float3x3(1., 0., 0.,
        0., cos(a), sin(a),
        0., -sin(a), cos(a));
}

float3x3 rotY(float a)
{
    return float3x3(cos(a), 0., sin(a),
        0., 1., 0.,
        -sin(a), 0., cos(a));
}

float3x3 rotZ(float a)
{
    return float3x3(cos(a), sin(a), 0.,
        -sin(a), cos(a), 0.,
        0., 0., 1.);
}

/**
 * Creates a 2D rotation matrix rotating around the origin by the specified amount.
 *
 * @param angle the angle in radians.
 * @return the matrix.
 */
float2x2 ELRotationMatrix(float angle)
{
    float sina, cosa;
    sincos(angle, sina, cosa);
    return float2x2(cosa, -sina, sina, cosa);
}

/**
 * Creates a 3D rotation matrix rotating around the X axis by the specified amount.
 *
 * @param angle the angle in radians.
 * @return the matrix.
 */
float3 ELRotateAroundXInDegrees(float3 vertex, float angle)
{
    float2x2 m = ELRotationMatrix(radians(angle));
    return float3(vertex.x, mul(m, vertex.yz));
}

/**
 * Creates a 3D rotation matrix rotating around the Y axis by the specified amount.
 *
 * @param angle the angle in radians.
 * @return the matrix.
 */
float3 ELRotateAroundYInDegrees(float3 vertex, float angle)
{
    float2x2 m = ELRotationMatrix(radians(angle));
    return float3(mul(m, vertex.xz), vertex.y).xzy;
}

/**
 * Creates a 3D rotation matrix rotating around the Z axis by the specified amount.
 *
 * @param angle the angle in radians.
 * @return the matrix.
 */
float3 ELRotateAroundZInDegrees(float3 vertex, float angle)
{
    float2x2 m = ELRotationMatrix(radians(angle));
    return float3(mul(m, vertex.xy), vertex.z);
}

/**
 * Converts polar coordinates to Cartesian coordinates.
 *
 * @param radius the radius.
 * @param angle the angle.
 * @return the X-Y coordinates.
 */
float2 ELPolarToCartesian(float radius, float angle)
{
    float2 sin_cos;
    sincos(angle, sin_cos[1], sin_cos[0]);
    return sin_cos * radius;
}

/**
 * Corrected modulus operator.
 *
 * @param dividend the dividend.
 * @param divisor the divisor.
 * @return the non-negative remainder `<` the divisor.
 */
float ELMod(float dividend, float divisor)
{
    return dividend - divisor * floor(dividend / divisor);
}
float2 ELMod(float2 dividend, float2 divisor)
{
    return dividend - divisor * floor(dividend / divisor);
}
float3 ELMod(float3 dividend, float3 divisor)
{
    return dividend - divisor * floor(dividend / divisor);
}

// https://en.wikipedia.org/wiki/Smoothstep#Variations
float ELSmootherStep(float edge0, float edge1, float x) 
{
    x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return x * x * x * (x * (x * 6.0 - 15.0) + 10.0);
}

float3 ELHueShift (in float3 color, in float3 shift) {
    float3 p = float3(0.55735,0.55735,0.55735) * (float3(0.55735,0.55735,0.55735),color);
    float3 u = color - p;
    float3 v = cross(float3(0.55735,0.55735,0.55735),u);
    color = u*cos(shift*6.2832) + v*sin(shift*6.2832) + p;
	return color;
}



inline float fRemap(float s, float l0, float h0, float l1, float h1) {
	return (s-l0)/(h0-l0) * (h1-l1) + l1;
}

float3 HSVtoRGB( float3 c )
{
	float4 K = float4( 1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0 );
	float3 p = abs( frac( c.xxx + K.xyz ) * 6.0 - K.www );
	return c.z * lerp( K.xxx, clamp( p - K.xxx, 0.0, 1.0 ), c.y );
}

float3 RGBtoHSV(float3 RGB)
{
	float3 HSV = 0;
	float M = min(RGB.r, min(RGB.g, RGB.b));
	HSV.z = max(RGB.r, max(RGB.g, RGB.b));
	float C = HSV.z - M;
	if (C != 0)
	{
		HSV.y = C / HSV.z;
		float3 D = (((HSV.z - RGB) / 6) + (C / 2)) / C;
		if (RGB.r == HSV.z)
			HSV.x = D.b - D.g;
		else if (RGB.g == HSV.z)
			HSV.x = (1.0/3.0) + D.r - D.b;
		else if (RGB.b == HSV.z)
			HSV.x = (2.0/3.0) + D.g - D.r;
		if ( HSV.x < 0.0 ) { HSV.x += 1.0; }
		if ( HSV.x > 1.0 ) { HSV.x -= 1.0; }
	}
	return HSV;
}

const float EPS_L = 0.0000001;

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

vec3 hsv2rgb2( in vec3 c )
{
    vec3 rgb = clamp( abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );
    return c.z * mix( (vec3)1.0, rgb, c.y);
}

vec3 hsl2rgb( in vec3 c )
{
    vec3 rgb = clamp( abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );
    return c.z + c.y * (rgb-0.5)*(1.0-abs(2.0*c.z-1.0));
}

vec3 rgb2hsv2( in vec3 c)
{
    vec4 k = vec4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
    vec4 p = mix(vec4(c.zy, k.wz), vec4(c.yz, k.xy), (c.z<c.y) ? 1.0 : 0.0);
    vec4 q = mix(vec4(p.xyw, c.x), vec4(c.x, p.yzx), (p.x<c.x) ? 1.0 : 0.0);
    float d = q.x - min(q.w, q.y);
    return vec3(abs(q.z + (q.w - q.y) / (6.0*d+EPS_L)), d / (q.x+EPS_L), q.x);
}

vec3 rgb2hsl( vec3 col )
{
    float minc = min( col.r, min(col.g, col.b) );
    float maxc = max( col.r, max(col.g, col.b) );
    vec3  mask = step(col.grr,col.rgb) * step(col.bbg,col.rgb);
    vec3 h = mask * (vec3(0.0,2.0,4.0) + (col.gbr-col.brg)/(maxc-minc + EPS_L)) / 6.0;
    return vec3( fract( 1.0 + h.x + h.y + h.z ),              // H
                 (maxc-minc)/(1.0-abs(minc+maxc-1.0) + EPS_L),  // S
                 (minc+maxc)*0.5 );                           // L
}



float3 SyncColor(float f) {
	return HSVtoRGB(float3(f*1.618, 1, 1));
}

float SyncTime(float phase, float step) {
	float t = (_Time.y + phase) * .1;
	return t - frac(t) * step;
}

// Mirror detection courtesy of Merlin

bool ELIsInMirror()
{
    return unity_CameraProjection[2][0] != 0.0 || unity_CameraProjection[2][1] != 0.0;
}

// Camera detection courtesy of ScruffyRuffles

bool ELIsVR()
{
    // USING_STEREO_MATRICES
    #if UNITY_SINGLE_PASS_STEREO
        return true;
    #else
        return false;
    #endif
}

bool ELIsVRHandCamera()
{
    return !ELIsVR() && abs(UNITY_MATRIX_V[0].y) > 0.0000005;
}

bool ELIsDesktop()
{
    return !ELIsVR() && abs(UNITY_MATRIX_V[0].y) < 0.0000005;
}

bool ELIsVRHandCameraPreview()
{
    return ELIsVRHandCamera() && _ScreenParams.y == 720;
}

bool ELIsVRHandCameraPicture()
{
    return ELIsVRHandCamera() && _ScreenParams.y == 1080;
}

bool ELIsPanorama()
{
    // Crude method
    // FOV=90=camproj=[1][1]
    return unity_CameraProjection[1][1] == 1 && _ScreenParams.x == 1075 && _ScreenParams.y == 1025;
}

/*
################### End Region Utils ###################
*/


/*
###################  Start Region SDFs ###################
*/

// Adapted from:
// - http://iquilezles.org/www/articles/distfunctions/distfunctions.htm
// - http://mercury.sexy/hg_sdf

float dot2(float2 v)
{
    return dot(v, v);
}
float dot2(float3 v)
{
    return dot(v, v);
}

// SIGNED DISTANCE FUNCTIONS //
// These all return the minimum distance from a position to the desired shape's surface, given the other parameters.
// The result is negative if you are inside the shape.  All shapes are centered about the origin, so you may need to
// transform your input point to account for translation or rotation

// This one's a bit of a tautology but I thought it made sense to have it for completeness.
float udPoint(float2 pos)
{
    return length(pos);
}
float udPoint(float3 pos)
{
    return length(pos);
}

// Sphere
float sdSphere(float3 pos, float radius)
{
    return length(pos) - radius;
}

// Circle in 2D
float sdCircle(float2 pos, float radius)
{
    return length(pos) - radius;
}

// Circle laid down on X-Z plane
float udCircle(float3 pos, float radius)
{
    float l = sdCircle(pos.xz, radius);
    return length(float2(pos.y, l));
}

// Ellipse in 2D
float sdEllipse(float2 pos, float2 ab)
{
    pos = abs(pos);
    if (pos.x > pos.y)
    {
        pos = pos.yx;
        ab = ab.yx;
    }
    float l = ab.y * ab.y - ab.x * ab.x;
    float m = ab.x * pos.x / l;
    float m2 = m * m; 
    float n = ab.y * pos.y / l;
    float n2 = n * n; 
    float c = (m2 + n2 - 1.0) / 3.0;
    float c3 = c * c * c;
    float q = c3 + m2 * n2 * 2.0;
    float d = c3 + m2 * n2;
    float g = m + m * n2;
    float co;
    if (d < 0.0)
    {
        float h = acos(q / c3) / 3.0;
        float s = cos(h);
        float t = sin(h) * sqrt(3.0);
        float rx = sqrt(-c * (s + t + 2.0) + m2);
        float ry = sqrt(-c * (s - t + 2.0) + m2);
        co = (ry + sign(l) * rx + abs(g) / (rx * ry) - m) / 2.0;
    }
    else
    {
        float h = 2.0 * m * n * sqrt(d);
        float s = sign(q + h) * pow(abs(q + h), 1.0 / 3.0);
        float u = sign(q - h) * pow(abs(q - h), 1.0 / 3.0);
        float rx = -s - u - c * 4.0 + 2.0 * m2;
        float ry = (s - u) * sqrt(3.0);
        float rm = sqrt(rx * rx + ry * ry);
        co = (ry / sqrt(rm - rx) + 2.0 * g / rm - m) / 2.0;
    }
    float2 r = ab * float2(co, sqrt(1.0 - co * co));
    return length(r - pos) * sign(pos.y - r.y);
}

// Box
// box: size of box in x/y/z
float sdBox(float3 pos, float3 box)
{
    float3 d = abs(pos) - box;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

// Box (cheaper - distance to corners is overestimated)
float sdBoxCheap(float3 pos, float3 box)
{
    float3 d = abs(pos) - box;
	return max(d.x, max(d.y, d.z));
}

// Round Box
float sdRoundBox(float3 pos, float3 box, float radius)
{
    return sdBox(pos, box) - radius;
}

// 2D Box
float sdBox2(float2 pos, float2 box)
{
    float2 d = abs(pos) - box;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// 2D Box (cheaper - distance to corners is overestimated)
float fBox2Cheap(float2 pos, float2 box)
{
    float2 d = abs(pos) - box;
	return max(d.x, d.y);
}

// Makes a wireframe box at p with scale b and e is how much to hollow out.
float sdBoundingBox(float3 p, float3 b, float e)
{
    p = abs(p) - b;
    float3 q = abs(p + e) - e;
    return min(min(
        length(max(float3(p.x, q.y, q.z), 0.0)) + min(max(p.x, max(q.y, q.z)), 0.0),
        length(max(float3(q.x, p.y, q.z), 0.0)) + min(max(q.x, max(p.y, q.z)), 0.0)),
        length(max(float3(q.x, q.y, p.z), 0.0)) + min(max(q.x, max(q.y, p.z)), 0.0));
}

// Torus
// torus.x: diameter
// torus.y: thickness
float sdTorus(float3 pos, float2 torus)
{
    float2 q = float2(length(pos.xz) - torus.x, pos.y);
    return length(q) - torus.y;
}

// Capped Torus
float sdCappedTorus(float3 pos, float2 sc, float ra, float rb)
{
    pos.x = abs(pos.x);
    float k = (sc.y * pos.x > sc.x * pos.y) ? dot(pos.xy, sc) : length(pos.xy);
    return sqrt(dot(pos, pos) + ra * ra - 2.0 * ra * k) - rb;
}

// [Chain] Link
float sdLink(float3 pos, float le, float r1, float r2)
{
    float3 q = float3(pos.x, max(abs(pos.y) - le, 0.0), pos.z);
    return length(float2(length(q.xy) - r1, q.z)) - r2;
}

// Infinite Cylinder
float sdCylinder(float3 pos, float3 c)
{
    return length(pos.xz - c.xy) - c.z;
}

// Cylinder
// cylinder.x = diameter
// cylinder.y = height
float sdCylinder(float3 pos, float2 cylinder)
{
    float2 d = abs(float2(length(pos.xz), pos.y)) - cylinder;
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// Rounded Cylinder
float sdRoundedCylinder(float3 pos, float ra, float rb, float h)
{
    float2 d = float2(length(pos.xz) - 2.0 * ra + rb, abs(pos.y) - h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - rb;
}

// Cone
float sdCone(float3 pos, in float2 c, float h)
{
    // c is the sin/cos of the angle, h is height
    // Alternatively pass q instead of (c,h),
    // which is the point at the base in 2D
    float2 q = h * float2(c.x / c.y, -1.0);

    float2 w = float2(length(pos.xz), pos.y);
    float2 a = w - q * clamp(dot(w, q)/dot(q, q), 0.0, 1.0);
    float2 b = w - q * float2(clamp(w.x / q.x, 0.0, 1.0), 1.0);
    float k = sign(q.y);
    float d = min(dot(a, a),dot(b, b));
    float s = max(k * (w.x * q.y - w.y * q.x), k * (w.y - q.y));
    return sqrt(d) * sign(s);
}

// Cone Bound (not exact)
float sdConeBound(float3 pos, float2 c)
{
    // c must be normalized
    float q = length(pos.xy);
    return dot(c, float2(q, pos.z));
}

// Capped Cone
float sdCappedCone(in float3 pos, in float3 c)
{
    float2 q = float2(length(pos.xz), pos.y);
    float2 v = float2(c.z * c.y / c.x, -c.z);
    float2 w = v - q;
    float2 vv = float2(dot(v, v), v.x * v.x);
    float2 qv = float2(dot(v, w), v.x * w.x);
    float2 d = max(qv, 0.0) * qv / vv;
    return sqrt(dot(w, w) - max(d.x, d.y))* sign(max(q.y * v.x - q.x * v.y, w.y));
}

// Round Cone
float sdRoundCone(float3 pos, float r1, float r2, float h)
{
    float2 q = float2(length(pos.xz), pos.y);
    
    float b = (r1 - r2) / h;
    float a = sqrt(1.0 - b * b);
    float k = dot(q, float2(-b, a));
    
    if (k < 0.0)
    {
        return length(q) - r1;
    }
    if (k > a * h)
    {
        return length(q - float2(0.0, h)) - r2;
    }
        
    return dot(q, float2(a,b)) - r1;
}

// Infinite Cone
float sdInfiniteCone(float3 pos, float2 c)
{
    // c is the sin/cos of the angle
    float2 q = float2(length(pos.xz), -pos.y);
    float d = length(q - c * max(dot(q, c), 0.0));
    return d * ((q.x * c.y - q.y * c.x < 0.0) ? -1.0 : 1.0);
}

// (Infinite) Plane
// n.xyz: normal of the plane (must be normalized).
// n.w: offset
float sdPlane(float3 pos, float4 n)
{
    return dot(pos, n.xyz) + n.w;
}

float sdHexPrism(float3 pos, float2 h)
{
    float3 q = abs(pos);
    return max(q.z - h.y, max((q.x * 0.866025 + q.y * 0.5), q.y) - h.x);
}

float sdTriPrism(float3 pos, float2 h)
{
    float3 q = abs(pos);
    return max(q.z - h.y, max(q.x * 0.866025 + pos.y * 0.5, -pos.y) - h.x * 0.5);
}

float udLineSegment(float2 pos, float2 a, float2 b)
{
	float2 ab = b - a;
	float t = clamp(dot(pos - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length((ab * t + a) - pos);
}
float udLineSegment(float3 pos, float3 a, float3 b)
{
	float3 ab = b - a;
	float t = clamp(dot(pos - a, ab) / dot(ab, ab), 0.0, 1.0);
	return length((ab * t + a) - pos);
}

float sdCapsule(float3 pos, float3 a, float3 b, float r)
{
    return udLineSegment(pos, a, b) - r;
}

float sdEllipsoid(in float3 pos, in float3 r)
{
    return (length(pos / r) - 1.0) * min(min(r.x, r.y), r.z);
}

// Solid Angle
// c is the sin/cos of the angle
float sdSolidAngle(float3 pos, float2 c, float ra)
{
    float2 q = float2(length(pos.xz), pos.y);
    float l = length(q) - ra;
    float m = length(q - c * clamp(dot(q, c), 0.0, ra));
    return max(l, m * sign(c.y * q.x - c.x * q.y));
}


//
// "Generalized Distance Functions" by Akleman and Chen.
// see the Paper at https://www.viz.tamu.edu/faculty/ergun/research/implicitmodeling/papers/sm99.pdf
//
// This set of constants is used to construct a large variety of geometric primitives.
// Indices are shifted by 1 compared to the paper because we start counting at Zero.
// Some of those are slow whenever a driver decides to not unroll the loop,
// which seems to happen for fIcosahedron und fTruncatedIcosahedron on nvidia 350.12 at least.
// Specialized implementations can well be faster in all cases.
//

static const float3 GDFVectors[19] = {
	normalize(float3(1.0, 0.0, 0.0)),
	normalize(float3(0.0, 1.0, 0.0)),
	normalize(float3(0.0, 0.0, 1.0)),

	normalize(float3(1.0, 1.0, 1.0)),
	normalize(float3(-1.0, 1.0, 1.0)),
	normalize(float3(1.0, -1.0, 1.0)),
	normalize(float3(1.0, 1.0, -1.0)),

	normalize(float3(0.0, 1.0, EL_PHI + 1.0)),
	normalize(float3(0.0, -1.0, EL_PHI + 1.0)),
	normalize(float3(EL_PHI + 1.0, 0.0, 1.0)),
	normalize(float3(-EL_PHI - 1.0, 0.0, 1.0)),
	normalize(float3(1.0, EL_PHI + 1.0, 0.0)),
	normalize(float3(-1.0, EL_PHI + 1.0, 0.0)),

	normalize(float3(0.0, EL_PHI, 1.0)),
	normalize(float3(0.0, -EL_PHI, 1.0)),
	normalize(float3(1.0, 0.0, EL_PHI)),
	normalize(float3(-1.0, 0.0, EL_PHI)),
	normalize(float3(EL_PHI, 1.0, 0.0)),
	normalize(float3(-EL_PHI, 1.0, 0.0))
};

// Version with variable exponent.
// This is slow and does not produce correct distances, but allows for bulging of objects.
float sdGDF(float3 p, float r, float e, int begin, int end)
{
    float d = 0.0;
    for (int i = begin; i <= end; i++)
    {
        d += pow(abs(dot(p, GDFVectors[i])), e);
    }
    return pow(d, 1.0 / e) - r;
}

// Version with without exponent, creates objects with sharp edges and flat faces
float sdGDF(float3 p, float r, int begin, int end)
{
    float d = 0.0;
    for (int i = begin; i <= end; i++)
    {
        d = max(d, abs(dot(p, GDFVectors[i])));
    }
    return d - r;
}

// Primitives follow:

float sdOctahedron(float3 p, float r, float e)
{
    return sdGDF(p, r, e, 3, 6);
}

float sdDodecahedron(float3 p, float r, float e)
{
    return sdGDF(p, r, e, 13, 18);
}

float sdIcosahedron(float3 p, float r, float e)
{
    return sdGDF(p, r, e, 3, 12);
}

float sdTruncatedOctahedron(float3 p, float r, float e)
{
    return sdGDF(p, r, e, 0, 6);
}

float sdTruncatedIcosahedron(float3 p, float r, float e)
{
    return sdGDF(p, r, e, 3, 18);
}

float sdOctahedron(float3 p, float r)
{
    return sdGDF(p, r, 3, 6);
}

float sdDodecahedron(float3 p, float r)
{
    return sdGDF(p, r, 13, 18);
}

float sdIcosahedron(float3 p, float r)
{
    return sdGDF(p, r, 3, 12);
}

float sdTruncatedOctahedron(float3 p, float r)
{
    return sdGDF(p, r, 0, 6);
}

float sdTruncatedIcosahedron(float3 p, float r)
{
    return sdGDF(p, r, 3, 18);
}


// Tetrahedron
float sdTetrahedron(float3 pos, float h)
{
    float m2 = h * h + 0.25;

    pos.xz = abs(pos.xz);
    pos.xz = (pos.z > pos.x) ? pos.zx : pos.xz;
    pos.xz -= 0.5;

    float3 q = float3(pos.z, h * pos.y - 0.5 * pos.x, h * pos.x + 0.5 * pos.y);

    float s = max(-q.x, 0.0);
    float t = clamp((q.y - 0.5 * pos.z) / (m2 + 0.25), 0.0, 1.0);

    float a = m2 * (q.x + s) * (q.x + s) + q.y * q.y;
    float b = m2 * (q.x + 0.5 * t) * (q.x + 0.5 * t) + (q.y - m2 * t) * (q.y - m2 * t);

    float d2 = min(q.y,-q.x * m2 - q.y * 0.5) > 0.0 ? 0.0 : min(a, b);

    return sqrt((d2 + q.z * q.z) / m2) * sign(max(q.z, -pos.y));
}

// by pema99 based off of https://swiftcoder.wordpress.com/2010/06/21/logarithmic-spiral-distance-field/
float sdSpiral(float3 p, float thickness, float height, float a, float b, float offset)
{
    const float e = 2.7182;

    // calculate the target radius and theta
    float r = sqrt(p.x * p.x + p.y * p.y);
    float t = atan2(p.y, p.x) + offset;

    // calculate the floating point approximation for n
    float n = (log(r / a) / b - t) / UNITY_TWO_PI;

    // find the two possible radii for the closest point
    float r1 = a * exp(b * (t + UNITY_TWO_PI * ceil(n)));
    float r2 = a * exp(b * (t + UNITY_TWO_PI * floor(n)));
    
    // return the minimum distance to the target point
    float dist = min(abs(r1 - r), abs(r - r2));

    return max(dist / thickness, abs(p.z) - height);
}
float sdSpiral2(float3 p, float thickness, float height, float a, float b, float offset)
{
    const float e = 2.7182;

    // calculate the target radius and theta
    float r = log(sqrt(p.x * p.x + p.y * p.y));
    float t = atan2(p.y, p.x) + offset;

    // calculate the floating point approximation for n
    float n = (log(r / a) / b - t) / UNITY_TWO_PI;

    // find the two possible radii for the closest point
    float r1 = a * exp(b * (t + UNITY_TWO_PI * ceil(n)));
    float r2 = a * exp(b * (t + UNITY_TWO_PI * floor(n)));
    
    // return the minimum distance to the target point
    float dist = min(abs(r1 - r), abs(r - r2));

    return max(dist / thickness, abs(p.z) - height);
}
float sdSpiral3(float3 p, float thickness, float height, float a, float b, float offset)
{
    const float e = 2.7182;

    // calculate the target radius and theta
    float r = exp(sqrt(p.x * p.x + p.y * p.y));
    float t = atan2(p.y, p.x) + offset;

    // calculate the floating point approximation for n
    float n = (log(r / a) / b - t) / UNITY_TWO_PI;

    // find the two possible radii for the closest point
    float r1 = a * exp(b * (t + UNITY_TWO_PI * ceil(n)));
    float r2 = a * exp(b * (t + UNITY_TWO_PI * floor(n)));
    
    // return the minimum distance to the target point
    float dist = min(abs(r1 - r), abs(r - r2));

    return max(dist / thickness, abs(p.z) - height);
}
float udTriangle(float3 pos, float3 a, float3 b, float3 c)
{
    float3 ba = b - a;
    float3 pa = pos - a;
    float3 cb = c - b;
    float3 pb = pos - b;
    float3 ac = a - c;
    float3 pc = pos - c;
    float3 nor = cross(ba, ac);

    return sqrt(
        (sign(dot(cross(ba, nor), pa)) +
         sign(dot(cross(cb, nor), pb)) +
         sign(dot(cross(ac, nor), pc)) < 2.0)
        ?
        min(min(
            dot2(ba * clamp(dot(ba, pa) / dot2(ba), 0.0, 1.0) - pa),
            dot2(cb * clamp(dot(cb, pb) / dot2(cb), 0.0, 1.0) - pb)),
            dot2(ac * clamp(dot(ac, pc) / dot2(ac), 0.0, 1.0) - pc))
        :
        dot(nor, pa) * dot(nor, pa) / dot2(nor));
}

float udQuad(float3 pos, float3 a, float3 b, float3 c, float3 d)
{
    float3 ba = b - a;
    float3 pa = pos - a;
    float3 cb = c - b;
    float3 pb = pos - b;
    float3 dc = d - c;
    float3 pc = pos - c;
    float3 ad = a - d;
    float3 pd = pos - d;
    float3 nor = cross(ba, ad);

    return sqrt(
        (sign(dot(cross(ba, nor), pa)) +
         sign(dot(cross(cb, nor), pb)) +
         sign(dot(cross(dc, nor), pc)) +
         sign(dot(cross(ad, nor), pd)) < 3.0)
        ?
        min(min(min(
            dot2(ba * clamp(dot(ba, pa) / dot2(ba), 0.0, 1.0) - pa),
            dot2(cb * clamp(dot(cb, pb) / dot2(cb), 0.0, 1.0) - pb)),
            dot2(dc * clamp(dot(dc, pc) / dot2(dc), 0.0, 1.0) - pc)),
            dot2(ad * clamp(dot(ad, pd) / dot2(ad), 0.0, 1.0) - pd))
        :
        dot(nor, pa) * dot(nor, pa) / dot2(nor));
}

// Distance from a point in 2D space to an arc starting at arc_r on the X axis
// and rotating through arc_theta in the positive direction.
float udArc(float2 pos, float arc_r, float arc_theta)
{
    float p_theta = atan2(pos.y, pos.x);
    if (p_theta < 0.0)
    {
        p_theta += UNITY_TWO_PI;
    }

    if (p_theta >= 0 && p_theta <= arc_theta)
    {
        // Distance to intersection between ray from origin to point and arc
        return abs(length(pos) - arc_r);
    }
    else
    {
        // Distance to starting point of arc
        float d1 = length(pos - float2(arc_r, 0));
        // Distance to ending point of arc
        float d2 = length(pos - ELPolarToCartesian(arc_r, arc_theta));
        return min(d1, d2);
    }
}

// Distance from a point in 3D space to an arc starting at arc_r on the X axis
// and rotating through arc_theta in the positive direction on the Y axis.
// The thickness of the line can be provided as well at the moment,
// since it ended up commonly used at the caller anyway.
float udArc(float3 pos, float arc_r, float arc_theta, float line_r)
{
    return length(float2(udArc(pos.xy, arc_r, arc_theta), pos.z)) - line_r;
}

// Bezier curve
float udBezier(float2 pos, float2 A, float2 B, float2 C)
{    
    float2 a = B - A;
    float2 b = A - 2.0 * B + C;
    float2 c = a * 2.0;
    float2 d = A - pos;
    float kk = 1.0 / dot(b, b);
    float kx = kk * dot(a, b);
    float ky = kk * (2.0 * dot(a, a) + dot(d, b)) / 3.0;
    float kz = kk * dot(d, a);
    float res = 0.0;
    float p = ky - kx * kx;
    float p3 = p * p * p;
    float q = kx * (2.0 * kx * kx - 3.0 * ky) + kz;
    float h = q * q + 4.0 * p3;
    if (h >= 0.0)
    {
        h = sqrt(h);
        float2 x = (float2(h, -h) - q) / 2.0;
        float2 uv = sign(x) * pow(abs(x), 1.0 / 3.0);
        float t = clamp(uv.x + uv.y - kx, 0.0, 1.0);
        res = dot2(d + (c + b * t) * t);
    }
    else
    {
        float z = sqrt(-p);
        float v = acos(q / (p * z * 2.0)) / 3.0;
        float m = cos(v);
        float n = sin(v) * 1.732050808; // sqrt(3)
        float3  t = clamp(float3(m + m, -n - m, n - m) * z - kx, 0.0, 1.0);
        res = min(dot2(d + (c + b * t.x) * t.x),
                  dot2(d + (c + b * t.y) * t.y));
        // the third root cannot be the closest
        // res = min(res, dot2(d + (c + b * t.z) * t.z));
    }
    return sqrt(res);
}


////////////////////////////////////////////////////////////////
//
//                DOMAIN MANIPULATION OPERATORS
//
////////////////////////////////////////////////////////////////
//
// Conventions:
//
// Everything that modifies the domain is named pSomething.
//
// Many operate only on a subset of the three dimensions. For those,
// you must choose the dimensions that you want manipulated
// by supplying e.g. <p.x> or <p.zx>
//
// <inout p> is always the first argument and modified in place.
//
// Many of the operators partition space into cells. An identifier
// or cell index is returned, if possible. This return value is
// intended to be optionally used e.g. as a random seed to change
// parameters of the distance functions inside the cells.
//
// Unless stated otherwise, for cell index 0, <p> is unchanged and cells
// are centered on the origin so objects don't have to be moved to fit.
//
//
////////////////////////////////////////////////////////////////



// Rotate around a coordinate axis (i.e. in a plane perpendicular to that axis) by angle <a>.
// Read like this: R(p.xz, a) rotates "x towards z".
// This is fast if <a> is a compile-time constant and slower (but still practical) if not.
void pRotate(inout float2 pos, float theta)
{
	pos = cos(theta) * pos + sin(theta) * float2(pos.y, -pos.x);
}

// Shortcut for 45-degrees rotation
void pRotateEighth(inout float2 pos)
{
	pos = (pos + float2(pos.y, -pos.x)) * sqrt(0.5);
}

void pRotateQuarter(inout float2 pos)
{
	pos = float2(pos.y, -pos.x);
}

void pRotateBackQuarter(inout float2 pos)
{
	pos = float2(-pos.y, pos.x);
}

void pRotateHalf(inout float2 pos)
{
    pos = -pos;
}

/* I wish.

float pScale(float3 pos, float scale, sdf3d primitive)
{
    return primitive(pos / scale) * scale;
}

*/

// Repeat space along one axis. Use like this to repeat along the x axis:
// <float cell = pMod1(p.x,5);> - using the return value is optional.
float pMod1(inout float pos, float size)
{
    float halfsize = size * 0.5;
    float c = floor((pos + halfsize) / size);
    pos = ELMod(pos + halfsize, size) - halfsize;
    return c;
}

// Same, but mirror every second cell so they match at the boundaries
float pModMirror1(inout float pos, float size)
{
    float halfsize = size * 0.5;
    float c = floor((pos + halfsize)/size);
    pos = ELMod(pos + halfsize, size) - halfsize;
    pos *= ELMod(c, 2.0) * 2.0 - 1.0;
    return c;
}

// Repeat the domain only in positive direction. Everything in the negative half-space is unchanged.
float pModSingle1(inout float pos, float size)
{
    float halfsize = size * 0.5;
    float c = floor((pos + halfsize) / size);
    if (pos >= 0)
    {
        pos = ELMod(pos + halfsize, size) - halfsize;
    }
    return c;
}

// Repeat only a few times: from indices <start> to <stop> (similar to above, but more flexible)
float pModInterval1(inout float pos, float size, float start, float stop)
{
    float halfsize = size * 0.5;
    float c = floor((pos + halfsize) / size);
    pos = ELMod(pos + halfsize, size) - halfsize;
    if (c > stop) // yes, this might not be the best thing numerically.
    {
        pos += size * (c - stop);
        c = stop;
    }
    if (c < start)
    {
        pos += size * (c - start);
        c = start;
    }
    return c;
}

// Repeat space in two dimensions
float2 pMod2(inout float2 pos, float2 size)
{
    float halfsize = size * 0.5;
    float2 c = floor((pos + halfsize) / size);
    pos = ELMod(pos + halfsize, size) - halfsize;
    return c;
}

// Same, but mirror every second cell so all boundaries match
float2 pModMirror2(inout float2 pos, float2 size)
{
    float2 halfsize = size * 0.5;
    float2 c = floor((pos + halfsize) / size);
    pos = ELMod(pos + halfsize, size) - halfsize;
    pos *= ELMod(c, float2(2.0, 2.0)) * 2.0 - float2(1.0, 1.0);
    return c;
}

// Same, but mirror every second cell at the diagonal as well
float2 pModGrid2(inout float2 pos, float2 size)
{
    float2 halfsize = size * 0.5;
    float2 c = floor((pos + halfsize)/size);
    pos = ELMod(pos + halfsize, size) - halfsize;
    pos *= ELMod(c, float2(2.0, 2.0)) * 2.0 - float2(1.0, 1.0);
    pos -= halfsize;
    if (pos.x > pos.y)
    {
        pos.xy = pos.yx;
    }
    return floor(c * 0.5);
}

// Repeat in three dimensions
float3 pMod3(inout float3 pos, float3 size)
{
    float3 halfsize = size * 0.5;
	float3 c = floor((pos + halfsize) / size);
	pos = ELMod(pos + halfsize, size) - halfsize;
	return c;
}
// Mirror at an axis-aligned plane which is at a specified distance <dist> from the origin.
float pMirror (inout float p, float dist) {
	float s = sgn(p);
	p = abs(p)-dist;
	return s;
}

// Mirror in both dimensions and at the diagonal, yielding one eighth of the space.
// translate by dist before mirroring.
vec2 pMirrorOctant (inout vec2 p, vec2 dist) {
	vec2 s = sgn(p);
	pMirror(p.x, dist.x);
	pMirror(p.y, dist.y);
	if (p.y > p.x)
		p.xy = p.yx;
	return s;
}

// Reflect space at a plane
float pReflect(inout vec3 p, vec3 planeNormal, float offset) {
	float t = dot(p, planeNormal)+offset;
	if (t < 0) {
		p = p - (2*t)*planeNormal;
	}
	return sgn(t);
}
float2 pModRotate(float2 pos, float theta)
{
    return cos(theta) * pos + sin(theta) * float2(pos.y, -pos.x);
}

float2 pModPolar(float2 pos, float repetitions)
{
    float angle = UNITY_TWO_PI / repetitions;
    float r = length(pos);
    float a = atan2(pos.y, pos.x) + angle * 0.5;
    a = ELMod(a, angle) - angle * 0.5;
    float2 result;
    sincos(a, result.y, result.x);
    return result * r;
}

////////////////////////////////////////////////////////////////
//
//             OBJECT COMBINATION OPERATORS
//
////////////////////////////////////////////////////////////////
//
// We usually need the following boolean operators to combine two objects:
// Union: OR(a,b)
// Intersection: AND(a,b)
// Difference: AND(a,!b)
// (a and b being the distances to the objects).
//
// The trivial implementations are min(a,b) for union, max(a,b) for intersection
// and max(a,-b) for difference. To combine objects in more interesting ways to
// produce rounded edges, chamfers, stairs, etc. instead of plain sharp edges we
// can use combination operators. It is common to use some kind of "smooth minimum"
// instead of min(), but we don't like that because it does not preserve Lipschitz
// continuity in many cases.
//
// Naming convention: since they return a distance, they are called fOpSomething.
// The different flavours usually implement all the boolean operators above
// and are called fOpUnionRound, fOpIntersectionRound, etc.
//
// The basic idea: Assume the object surfaces intersect at a right angle. The two
// distances <a> and <b> constitute a new local two-dimensional coordinate system
// with the actual intersection as the origin. In this coordinate system, we can
// evaluate any 2D distance function we want in order to shape the edge.
//
// The operators below are just those that we found useful or interesting and should
// be seen as examples. There are infinitely more possible operators.
//
// They are designed to actually produce correct distances or distance bounds, unlike
// popular "smooth minimum" operators, on the condition that the gradients of the two
// SDFs are at right angles. When they are off by more than 30 degrees or so, the
// Lipschitz condition will no longer hold (i.e. you might get artifacts). The worst
// case is parallel surfaces that are close to each other.
//
// Most have a float argument <r> to specify the radius of the feature they represent.
// This should be much smaller than the object size.
//
// Some of them have checks like "if ((-a < r) && (-b < r))" that restrict
// their influence (and computation cost) to a certain area. You might
// want to lift that restriction or enforce it. We have left it as comments
// in some cases.
//
// usage example:
//
// float fTwoBoxes(vec3 p) {
//   float box0 = fBox(p, vec3(1));
//   float box1 = fBox(p-vec3(1), vec3(1));
//   return fOpUnionChamfer(box0, box1, 0.2);
// }
//
////////////////////////////////////////////////////////////////

// BOOLEAN OPERATIONS //
// Apply these operations to multiple "primitive" distance functions to create complex shapes.

// Union
float opU(float d1, float d2)
{
    return min(d1, d2);
}
float opU(float d1, float d2, float d3)
{
    return min(d1, min(d2, d3));
}

// Union (with extra data)
// d1,d2.x: Distance field result
// d1,d2.y: Extra data (material data for example)
float2 opU(float2 d1, float2 d2)
{
    return (d1.x < d2.x) ? d1 : d2;
}

float opSmoothUnion(float d1, float d2, float k)
{
    float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return lerp(d2, d1, h) - k * h * (1.0 - h);
}

float opSmoothSubtraction(float d1, float d2, float k)
{
    float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
    return lerp(d2, -d1, h) + k * h * (1.0 - h);
}

float opSmoothIntersection(float d1, float d2, float k)
{
    float h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return lerp(d2, d1, h) + k * h * (1.0 - h);
}

// Subtraction
float opS(float d1, float d2)
{
    return max(-d1, d2);
}

// Intersection
float opI(float d1, float d2)
{
    return max(d1, d2);
}

// Intersection (with extra data)
// d1,d2.x: Distance field result
// d1,d2.y: Extra data (material data for example)
float2 opI(float2 d1, float2 d2)
{
    return (d1.x > d2.x) ? d1 : d2;
}


// The "Chamfer" flavour makes a 45-degree chamfered edge (the diagonal of a square of size <r>):
float fOpUnionChamfer(float a, float b, float r) {
	return min(min(a, b), (a - r + b)*sqrt(0.5));
}

// Intersection has to deal with what is normally the inside of the resulting object
// when using union, which we normally don't care about too much. Thus, intersection
// implementations sometimes differ from union implementations.
float fOpIntersectionChamfer(float a, float b, float r) {
	return max(max(a, b), (a + r + b)*sqrt(0.5));
}

// Difference can be built from Intersection or Union:
float fOpDifferenceChamfer (float a, float b, float r) {
	return fOpIntersectionChamfer(a, -b, r);
}

// The "Round" variant uses a quarter-circle to join the two objects smoothly:
float fOpUnionRound(float a, float b, float r) {
	vec2 u = max(vec2(r - a,r - b), (float2)0.);
	return max(r, min (a, b)) - length(u);
}

float fOpIntersectionRound(float a, float b, float r) {
	vec2 u = max(vec2(r + a,r + b), (float2)0.);
	return min(-r, max (a, b)) + length(u);
}

float fOpDifferenceRound (float a, float b, float r) {
	return fOpIntersectionRound(a, -b, r);
}


// The "Columns" flavour makes n-1 circular columns at a 45 degree angle:
float fOpUnionColumns(float a, float b, float r, float n) {
	if ((a < r) && (b < r)) {
		vec2 p = vec2(a, b);
		float columnradius = r*sqrt(2)/((n-1)*2+sqrt(2));
		pRotateEighth(p);
		p.x -= sqrt(2)/2*r;
		p.x += columnradius*sqrt(2);
		if (mod(n,2) == 1) {
			p.y += columnradius;
		}
		// At this point, we have turned 45 degrees and moved at a point on the
		// diagonal that we want to place the columns on.
		// Now, repeat the domain along this direction and place a circle.
		pMod1(p.y, columnradius*2);
		float result = length(p) - columnradius;
		result = min(result, p.x);
		result = min(result, a);
		return min(result, b);
	} else {
		return min(a, b);
	}
}

float fOpDifferenceColumns(float a, float b, float r, float n) {
	a = -a;
	float m = min(a, b);
	//avoid the expensive computation where not needed (produces discontinuity though)
	if ((a < r) && (b < r)) {
		vec2 p = vec2(a, b);
		float columnradius = r*sqrt(2)/n/2.0;
		columnradius = r*sqrt(2)/((n-1)*2+sqrt(2));

		pRotateEighth(p);
		p.y += columnradius;
		p.x -= sqrt(2)/2*r;
		p.x += -columnradius*sqrt(2)/2;

		if (mod(n,2) == 1) {
			p.y += columnradius;
		}
		pMod1(p.y,columnradius*2);

		float result = -length(p) + columnradius;
		result = max(result, p.x);
		result = min(result, a);
		return -min(result, b);
	} else {
		return -m;
	}
}

float fOpIntersectionColumns(float a, float b, float r, float n) {
	return fOpDifferenceColumns(a,-b,r, n);
}

// The "Stairs" flavour produces n-1 steps of a staircase:
// much less stupid version by paniq
float fOpUnionStairs(float a, float b, float r, float n) {
	float s = r/n;
	float u = b-r;
	return min(min(a,b), 0.5 * (u + a + abs ((mod (u - a + s, 2 * s)) - s)));
}

// We can just call Union since stairs are symmetric.
float fOpIntersectionStairs(float a, float b, float r, float n) {
	return -fOpUnionStairs(-a, -b, r, n);
}

float fOpDifferenceStairs(float a, float b, float r, float n) {
	return -fOpUnionStairs(-a, b, r, n);
}


// Similar to fOpUnionRound, but more lipschitz-y at acute angles
// (and less so at 90 degrees). Useful when fudging around too much
// by MediaMolecule, from Alex Evans' siggraph slides
float fOpUnionSoft(float a, float b, float r) {
	float e = max(r - abs(a - b), 0);
	return min(a, b) - e*e*0.25/r;
}


// produces a cylindical pipe that runs along the intersection.
// No objects remain, only the pipe. This is not a boolean operator.
float fOpPipe(float a, float b, float r) {
	return length(vec2(a, b)) - r;
}

// first object gets a v-shaped engraving where it intersect the second
float fOpEngrave(float a, float b, float r) {
	return max(a, (a + r - abs(b))*sqrt(0.5));
}

// first object gets a capenter-style groove cut out
float fOpGroove(float a, float b, float ra, float rb) {
	return max(a, min(a + ra, rb - abs(b)));
}

// first object gets a capenter-style tongue attached
float fOpTongue(float a, float b, float ra, float rb) {
	return min(a, max(a - ra, abs(b) - rb));
}

float sdCross(vec3 p, float w) {
	p = abs(p);
	vec3 d = vec3(max(p.x, p.y),
				  max(p.y, p.z),
				  max(p.z, p.x));
	return min(d.x, min(d.y, d.z)) - w;
}

float sdCrossRep(vec3 p, float w) {
	vec3 q = mod(p + 1.0, 2.0) - 1.0;
	return sdCross(q, w);
}

float sdCrossRepScale(vec3 p, float s, float w) {
	return sdCrossRep(p * s, w) / s;	
}

// Blobby ball object. You've probably seen it somewhere. This is not a correct distance bound, beware.
float fBlob(vec3 p) {
	p = abs(p);
	if (p.x < max(p.y, p.z)) p = p.yzx;
	if (p.x < max(p.y, p.z)) p = p.yzx;
	float b = max(max(max(
		dot(p, normalize(vec3(1, 1, 1))),
		dot(p.xz, normalize(vec2(PHI+1, 1)))),
		dot(p.yx, normalize(vec2(1, PHI)))),
		dot(p.xz, normalize(vec2(1, PHI))));
	float l = length(p);
	return l - 1.5 - 0.2 * (1.5 / 2)* cos(min(sqrt(1.01 - b / l)*(PI / 0.25), PI));
}


// A circle line. Can also be used to make a torus by subtracting the smaller radius of the torus.
float fCircle(vec3 p, float r) {
	float l = length(p.xz) - r;
	return length(vec2(p.y, l));
}

// A circular disc with no thickness (i.e. a cylinder with no height).
// Subtract some value to make a flat disc with rounded edge.
float fDisc(vec3 p, float r) {
	float l = length(p.xz) - r;
	return l < 0 ? abs(p.y) : length(vec2(p.y, l));
}

// Hexagonal prism, circumcircle variant
float fHexagonCircumcircle(vec3 p, vec2 h) {
	vec3 q = abs(p);
	return max(q.y - h.y, max(q.x*sqrt(3)*0.5 + q.z*0.5, q.z) - h.x);
	//this is mathematically equivalent to this line, but less efficient:
	//return max(q.y - h.y, max(dot(vec2(cos(PI/3), sin(PI/3)), q.zx), q.z) - h.x);
}

// Hexagonal prism, incircle variant
float fHexagonIncircle(vec3 p, vec2 h) {
	return fHexagonCircumcircle(p, vec2(h.x*sqrt(3)*0.5, h.y));
}

float3 hmod(float3 a, float3 b)
{
	return frac(abs(a / b)) * abs(b);
}
float3 repeat(float3 pos, float3 span)
{
	return hmod(pos, span) - span * 0.5;
}
// Specialized implementations. You can use either or for the icosahedron and dodecahedron.
float sdIcosahedron2(float3 p, float r)
{
    const float q = (sqrt(5.)+3.)/2.;

    const float3 n1 = normalize(float3(q,1,0));
    const float3 n2 = sqrt(3.)/3.;

    p = abs(p/r);
    float a = dot(p, n1.xyz);
    float b = dot(p, n1.zxy);
    float c = dot(p, n1.yzx);
    float d = dot(p, n2.xyz)-n1.x;
    return max(max(max(a,b),c)-n1.x,d)*r; // turn into (...)/r  for weird refractive effects when you subtract this shape
}
float sdDodecahedron2(float3 p, float r)
{
    float phi = (1.+sqrt(5.))*.5;
    const float3 n = normalize(float3(phi,1,0));

    p = abs(p/r);
    float a = dot(p,n.xyz);
    float b = dot(p,n.zxy);
    float c = dot(p,n.yzx);
    return (max(max(a,b),c)-n.x)*r;
}

float sdRoundBox9PatchField(float3 pos, float box, float radius, float offset, float smin)
{
    pos = repeat(pos, offset);
    // Smoothing help from pema99
    float3 dirs[7] = 
    {
        float3(0, 0, 0),
        float3(0, 1, 0),
        float3(0, -1, 0),
        float3(1, 0, 0),
        float3(-1, 0, 0),
        float3(0, 0, 1),
        float3(0, 0, -1)
    };
    float m = 100000000;
    //For each of the 7 directions we want to smooth with a roundbox.
    for (int i = 0; i < 7; i++)
    {
        m = opSmoothUnion(m, sdRoundBox(pos + dirs[i] * offset, box, radius), smin);
    }
    return m;
}

float sdStarPrism(float3 objectPos, float scale)
{
    objectPos.xy = pModRotate(objectPos.xy, UNITY_HALF_PI);
    objectPos.xy = pModPolar(objectPos.xy, 5.0);
    objectPos -= float3(0.1, 0.0, 0.0);
    objectPos.xy = pModRotate(objectPos.xy, -UNITY_HALF_PI);

    objectPos /= scale;
    return sdTriPrism(objectPos, float2(0.1, 0.25)) * scale;
}

float sdKnighty(float3 p, float i0)
{
    const float minsx[5] = {-.3252, -1.05,-1.21,-1.04,-0.737};
    const float minsy[5] = {-.7862, -1.05,-.954,-.79,-0.73};
    const float minsz[5] = {-.0948, -0.0001,-.0001,-.126,-1.23};
    const float minsw[5] = {.678, .7,1.684,.833, .627};
    const float maxsx[5] = {.3457, 1.05,.39,.3457,.73};
    const float maxsy[5] = {1.0218, 1.05,.65,1.0218,0.73};
    const float maxsz[5] = {1.2215, 1.27,1.27,1.2215,.73};
    const float maxsw[5] = {.9834, .95,2.74,.9834, .8335};

    float4 mins = float4(minsx[i0], minsy[i0], minsz[i0], minsw[i0]);
    float4 maxs = float4(maxsx[i0], maxsy[i0], maxsz[i0], maxsw[i0]);

    float k = 0.0;
    float scale=1.0;
    for (int i=0; i < 5; i++)
    {
        p = 2.0 * clamp(p, mins.xyz, maxs.xyz) - p;
        k = max(mins.w / dot(p,p), 1.0);
        p *= k;
        scale *= k;
    }
    float rxy = length(p.xy);
    return 0.7 * max(rxy - maxs.w, rxy * p.z / length(p)) / scale;
}
/*
###################  End Region SDFs ###################
*/

/*
###################  Start Region Intersects ###################
*/

float2 iSphere(float3 ro, float3 rd, float4 sph)
{
	float3 oc = ro - sph.xyz;
	float b = dot(oc, rd);
	float c = dot(oc, oc) - sph.w * sph.w;
	float h = b * b - c;
	if (h < 0.0)
		return float2(-1.0, -1.0);
	h = sqrt(h);
	return float2(abs(-b-h), -b+h);
}


vec2 iSphere1(vec3 ro, vec3 rd, vec3 org, float rad)
{
   float a = dot(rd, rd);
   float b = 2. * dot(rd, ro - org);
   float c = dot(ro - org, ro - org) - rad * rad;
   float desc = b * b - 4. * a * c;
   if (desc < 0.)
      return vec2(1, 0);

   return vec2((-b - sqrt(desc)) / (2. * a), (-b + sqrt(desc)) / (2. * a));
}


// axis aligned box centered at the origin, with size boxSize
float2 iBox( float3 ro, float3 rd, float3 boxSize) 
{
    float3 m = 1.0/rd; // can precompute if traversing a set of aligned boxes

    float3 tmin = (float3(0.,0.,0.) - ro) * m;
	float3 tmax = (boxSize - ro) * m;
    
	float2 t1 = min(tmin,tmax);
    float2 t2 = max(tmin,tmax);

    float tN = max( max( t1.x, t1.y ), t1.y );
    float tF = min( min( t2.x, t2.y ), t2.y );

    if( tN>tF || tF>0.0) return (float2)-1.; // no intersection
    return vec2( tN, tF );
}
/*
###################  End Region Intersects ###################
*/


#endif // SDF_MASTER_
