Shader "Kit/Mushroom Trip"
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
        _Metallic ("Metallic", Float) = 47.4
		_Glossiness("Smoothness", Float) = 0.55
        _LumWeight ("Lum Weight", Vector) = (5.0,0.69,0.44,1.0)

    }
	CGINCLUDE
            #pragma target 5.0

            
            #include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "UnityPBSLighting.cginc"
			#include "AutoLight.cginc"            
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
				float3 worldDirection : TEXCOORD4;
				float4 screenPosition : TEXCOORD5;	
	            float3 ray : TEXCOORD6;

            };
			sampler2D _CameraDepthTexture;


            sampler2D _MainTex;
            float4 _MainTex_ST;
			float4 _Tint;
			float _Glossiness;
            float4 _CameraDepthTexture_TexelSize;
            float _Metallic;

            float4 _LumWeight;

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
float3 BlendOverlay (float3 base, float3 blend) // overlay
{
    return base < 0.5 ? (2.0 * base * blend) : (1.0 - 2.0 * (1.0 - base) * (1.0 - blend));
}

/*
###################  End Region Noise ###################
*/



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


			// from http://answers.unity.com/answers/641391/view.html
			// creates inverse matrix of input
			float4x4 inverse(float4x4 input)
			{
				#define minor(a,b,c) determinant(float3x3(input.a, input.b, input.c))
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
					minor(_11_12_13, _21_22_23, _31_32_33)
				);
				#undef minor
				return transpose(cofactors) / determinant(input);
			}

			float4x4 INVERSE_UNITY_MATRIX_VP;
			float3 calculateWorldSpace(float4 screenPos)
			{	
				// Transform from adjusted screen pos back to world pos
				float4 worldPos = mul(INVERSE_UNITY_MATRIX_VP, screenPos);
				// Subtract camera position from vertex position in world
				// to get a ray pointing from the camera to this vertex.
				float3 worldDir = worldPos.xyz / worldPos.w - _WorldSpaceCameraPos;
				// Calculate screen UV
				float2 screenUV = screenPos.xy / screenPos.w;
				screenUV.y *= _ProjectionParams.x;
				screenUV = screenUV * 0.5f + 0.5f;
				// Adjust screen UV for VR single pass stereo support
				screenUV = UnityStereoTransformScreenSpaceTex(screenUV);
				// Read depth, linearizing into worldspace units.    
				float depth = LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2D(_CameraDepthTexture, screenUV))) / screenPos.w;
				// Advance by depth along our view ray from the camera position.
				// This is the worldspace coordinate of the corresponding fragment
				// we retrieved from the depth buffer.
				return worldDir * depth;
			}      
            vo vert (vi v)
            {
                vo o;

				//Normally, we would do this:
				//o.vertex = UnityObjectToClipPos(v.vertex);
				//But...
				//Cursed mechansm to draw effect on top. https://forum.unity.com/threads/pull-to-camera-shader.459767/
                float3 pullPos = mul(unity_ObjectToWorld,v.vertex);
                // Determine cam direction (needs Normalize)
                float3 camDirection=_WorldSpaceCameraPos-pullPos; 
				float camdist = length(camDirection);
				camDirection = normalize( camDirection );
                // Pull in the direction of the camera by a fixed amount
				float dotdepth = camdist;
				float moveamount = 5;
				float near = _ProjectionParams.y*1.8;  //Center of vision hits near, but extremes may exceed.
				if( moveamount > dotdepth-near ) moveamount = dotdepth-near;
				float3 camoff = camDirection*moveamount;
                pullPos+=camoff;
                o.vertex=mul(UNITY_MATRIX_VP,float4(pullPos,1));

                o.uv = v.uv;
                o.wpos = mul(unity_ObjectToWorld, v.vertex);
                o.dgpos = ComputeGrabScreenPos(o.vertex);
                o.rd.xyz =  mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos + camoff;
                o.rd.w = dot(o.vertex, ObliqueFrustumCorrection);

				// Subtract camera position from vertex position in world
				// to get a ray pointing from the camera to this vertex.
				o.worldDirection = mul(unity_ObjectToWorld, v.vertex).xyz - _WorldSpaceCameraPos + camoff;

				// Save the clip space position so we can use it later.
				// (There are more efficient ways to do this in SM 3.0+, 
				// but here I'm aiming for the simplest version I can.
				// Optimized versions welcome in additional answers!)
				o.screenPosition = o.vertex;//UnityObjectToClipPos(v.vertex);
            	o.ray = mul(UNITY_MATRIX_MV, v.vertex).xyz * float3(-1,-1,1);

//				//Push out Z so that this appears on top even though it's only drawing backfaces.
//				float z = o.vertex.z * o.vertex.w;
//				//z += 1.8;
//				//if( z < 3 ) z = 3;
//				float zadjust = 150;
//				z += zadjust / (1000-.3);
//				o.vertex.z = z / o.vertex.w;
                return o;
            }
            


            //hsv and rgb functions
            
            // float3 rgb2hsv(float3 c) {
            //     float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
            //     float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
            //     float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));

            //     float d = q.x - min(q.w, q.y);
            //     float e = 1.0e-10;
            //     return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
            // }

            // float3 hsv2rgb(float3 hsv){
            //     float4 t = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
            //     float3 p = abs(frac(hsv.xxx + t.xyz) * 6.0 - t.www);
            //     return hsv.z * lerp(t.xxx, clamp(p - t.xxx, 0.0, 1.0), hsv.y);
            // }

            float3 hsv2rgb_smooth(in float3 c)
            {
                float3 rgb = clamp(abs(glsl_mod(c.x*6.+float3(0., 4., 2.), 6.)-3.)-1., 0., 1.);
                return c.z*lerp(((float3)1.), rgb, c.y);
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


	ENDCG
	
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent+100" "LightMode"="ForwardBase"}
  //      Pass
  //      {
   //         ZWrite On
    //        ColorMask 0
     //   }    
		// Pass {
		//     Cull Front
        //     Blend One Zero
        //     ZWrite Off
        //     ZTest [_ZTest]
        //     CGPROGRAM
        //     #pragma vertex vert
        //     #pragma fragment frag


		// 	ENDCG			
		// }    

		// GrabPass{"_BackDepthTexture"}		
        
		Pass
        {
            AlphaToMask On
            ZWrite [_ZWrite]
            Cull [_Cull]
            Blend [_SourceBlend] [_DestinationBlend]
            ZTest [_ZTest]
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			sampler2D _BackDepthTexture;
            
      
            


            float4 frag (vo __vo) : SV_Target
            {
                vop = __vo;
				// Compute projective scaling factor...
				float perspectiveDivide = 1.0f / vop.screenPosition.w;

				// Scale our view ray to unit depth.
				float3 direction = vop.worldDirection * perspectiveDivide;

				// Calculate our UV within the screen (for reading depth buffer)
				float2 screenUV = (vop.screenPosition.xy * perspectiveDivide) * 0.5f + 0.5f;

				// No idea
				if (_ProjectionParams.x < 0)
					screenUV.y = 1 - screenUV.y; 
				// VR stereo support
				screenUV = UnityStereoTransformScreenSpaceTex(screenUV);
				
                float w = 1.f / vop.vertex.w;
                float4 rd = vop.rd * w;
                float2 dgpos = vop.dgpos.xy * w;
                #ifdef UNITY_UV_STARTS_AT_TOP
                    dgpos.y = lerp(dgpos.y, 1 - dgpos.y, step(0, _ProjectionParams.x));
                #endif


                const int mSize = 11;
                const int kSize = (mSize-1)/2;
                float kernel[mSize];
                float sigma = 7.;
                float rz = 0.;
                float fz = 0.;

				
                for (int j = 0;j<=kSize; ++j)
                {
                    kernel[kSize+j] = kernel[kSize-j] = normpdf(float(j), sigma);
                }
                for (int k = 0;k<mSize; ++k)
                {
                    rz += kernel[k];
                }

                for (int i = -kSize;i<=kSize; ++i)
                {
                    for (int j = -kSize;j<=kSize; ++j)
                    {
						fz += kernel[kSize+j] * kernel[kSize+i] * DecodeFloatRG(tex2D(_CameraDepthTexture, float2(screenUV.xy + float2(float(i),float(j)) * fwidth(screenUV))));
                        //fz += kernel[kSize+j] * kernel[kSize+i] * SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenUV.xy + float2(float(i),float(j)) * fwidth(screenUV));
                    }
                }
				
				
                float z = (fz/(rz*rz));
                float z2 = pow(0.9,z);
				
				float rawDepth = DecodeFloatRG(tex2D(_CameraDepthTexture, float2(screenUV.xy)));
				float linearDepth = Linear01Depth(rawDepth);
				float3 ray = vop.ray * (_ProjectionParams.z / vop.ray.z);
				float4 vpos = float4(ray * linearDepth, 1);
				float3 wpos2 = mul(unity_CameraToWorld, vpos).xyz;
				float3 wposx = ddx_fine(wpos2);
				float3 wposy = ddy_fine(wpos2);
				float3 wnormal = normalize(cross(wposy, wposx));

				// Convert to object space
				float3 opos2 = mul(unity_WorldToObject, float4(wpos2, 1));
				float3 onormal = mul(unity_WorldToObject, wnormal);		
				float3 oposx = ddx_fine(opos2);
				float3 oposy = ddy_fine(opos2);						
				#if UNITY_REVERSED_Z
				if (z == 0.f) {
				#else
				if (z == 1.f) {
				#endif
					// skybox
					return float4(0.f, 0.f, 0.f, 1.f);
				}
                //Get more precise screenspace uv derivatives. 
                float dx = ddx_fine(screenUV.x);
                float dy = ddy_fine(screenUV.y);

                float angle = atan2(rz * _LumWeight.x, fz * _LumWeight.x)/(2.*UNITY_PI)+_Time.y*(1.-dx)/2.;                
                float angle2 = atan2(rz* _LumWeight.x, fz * _LumWeight.x)/(2.*UNITY_PI)+_Time.y*(1.-dx)/2.;                

                float depth = LinearEyeDepth(z);
				#if UNITY_REVERSED_Z
				//if (z == 0.f) {
                    float fd = LinearEyeDepth(0.0);
                #else
				//if (z == 1.f) {
                    float fd = LinearEyeDepth(1.0);
                #endif                

				float4 vpos2 = float4(ray * depth, 1);
				float3 wpos = direction * depth + _WorldSpaceCameraPos.xyz;
				float depth2 = LinearEyeDepth(rawDepth);
				float3 wpos3 = direction * depth2 + _WorldSpaceCameraPos.xyz;

                //float3 wpos = mul(unity_CameraToWorld, vpos2).xyz;
                float4 opos = mul(unity_WorldToObject, float4(wpos3, 1.0));
                float3 wnorm = normalize(wpos);



				float4 screenPos2 = UnityObjectToClipPos(opos2); 
				// float2 offset = 1.2 / _ScreenParams.xy * screenPos2.w ; 
				// float3 worldPos1 = calculateWorldSpace(screenPos2);
				// float3 worldPos2 = calculateWorldSpace(screenPos2 + float4(0, offset.y, 0, 0));
				// float3 worldPos3 = calculateWorldSpace(screenPos2 + float4(-offset.x, 0, 0, 0));
				// float3 worldNormal = normalize(cross(worldPos2 - worldPos1, worldPos3 - worldPos1));

                float nx = _LumWeight.z;
                float ny = _LumWeight.z;
							
                float2 Offset[5];
				float4 dgpos2 = ComputeGrabScreenPos(screenPos2);
				float pd2 = 1.0f / dgpos2.w;
				float4 dgpos3 = dgpos2 * pd2;
				dgpos3.xy *= 0.5f + 0.5f;
                // #ifndef UNITY_UV_STARTS_AT_TOP
                //     dgpos3.y = 1.0-dgpos2.y;
                // #endif	
                #ifdef UNITY_UV_STARTS_AT_TOP
                    dgpos3.y = lerp(dgpos3.y, 1 - dgpos3.y, step(0, _ProjectionParams.x));
                #endif

                float3 rd2 = (wpos3 - _WorldSpaceCameraPos);

                Offset[0] = dgpos3.xy + (float2( 0, 0) / _ScreenParams.xy) ;
                Offset[1] = dgpos3.xy + (float2(nx, 0) / _ScreenParams.xy) ;
                Offset[2] = dgpos3.xy + (float2(-nx, 0) / _ScreenParams.xy);
                Offset[3] = dgpos3.xy + (float2( 0, ny) / _ScreenParams.xy);
                Offset[4] = dgpos3.xy + (float2( 0,-ny) / _ScreenParams.xy);
                float M = abs(LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, float4(Offset[0], dgpos3.zw)).r )));
                float L = abs(LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, float4(Offset[1], dgpos3.zw)).r )));
                float R = abs(LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, float4(Offset[2], dgpos3.zw)).r )));
                float U = abs(LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, float4(Offset[3], dgpos3.zw)).r )));
                float D = abs(LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, float4(Offset[4], dgpos3.zw)).r )));
                float X = ((R-M)+(M-L))*.5;
                float Y = ((D-M)+(M-U))*.5;

                float4 N = float4(normalize(float3(X, Y, .01))-.5, 1.0);


				float WPthis  = direction * LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, float4(dgpos2.xy + float2( 1./_ScreenParams.x, 0 ), dgpos2.zw ))));
				float WPleft  = (direction - ddx_fine( direction ) ) * LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, float4(dgpos2.xy + float2(-1./_ScreenParams.x, 0 ), dgpos2.zw ))));
				float WPright = (direction + ddx_fine( direction ) ) * LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, float4(dgpos2.xy + float2( 0, 0 ), dgpos2.zw ))));
				float WPup    = (direction - ddy_fine( direction ) ) * LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, float4(dgpos2.xy + float2( 0, 1./_ScreenParams.y ), dgpos2.zw ))));
				float WPdown  = (direction + ddy_fine( direction ) )* LinearEyeDepth(UNITY_SAMPLE_DEPTH(tex2Dproj(_CameraDepthTexture, float4(dgpos2.xy + float2( 0,-1./_ScreenParams.y ), dgpos2.zw ))));
				
				float3 deltas = 0.;
				if( abs( WPthis - WPleft ) < abs( WPright - WPthis ) )
					deltas.x = WPthis - WPleft;
				else
					deltas.x = WPright - WPthis;

				if( abs( WPthis - WPup ) < abs( WPdown - WPthis ) )
					deltas.y = WPthis - WPup;
				else
					deltas.y = WPdown - WPthis;
				deltas.z = .01;
				deltas = normalize( deltas );	


				N.xyz = N.xyz * .5  + .5;
				float3 wnorm2 = mul((float3x3)UNITY_MATRIX_I_V, N);
				float3 onormal2 = mul(unity_WorldToObject, wnorm2);		

				//angle = lerp(angle,angle2,smoothstep(0.005,0.007,linearDepth));
                float3 cwa = float3(angle, 1.,1.);
                float3 cwac = hsv2rgb_smooth(cwa);
                float4 sColor = snoise_grad(wpos*0.3);
           		sColor.xyz = rgb2hsv(sColor.xyz);
                sColor.r += _Time.y;
				float3 blendColor = lerp(hsv2rgb_smooth(sColor.xyz),1.0-hsv2rgb_smooth(sColor.xyz),smoothstep(0.0,1.5,sColor.w));
                // blendColor = rgb2hsv(blendColor);
                // blendColor.r += _Time.y;
                // blendColor = hsv2rgb_smooth(blendColor);



                float3 col = float3(angle,1.0,z);
                col = hsv2rgb_smooth(col);

				#if UNITY_REVERSED_Z
				//if (z == 0.f) {
                    col = lerp(blendColor, col, z2);
                #else
				//if (z == 1.f) {
                    col = lerp(col, blendColor, z2);
                #endif
                col = lerp(BlendOverlay(col, blendColor),col,z2);
                // col = rgb2hsv(col);
                // col.r += _Time.y;-
				float3 worldViewDir = normalize(UnityWorldSpaceViewDir(wpos));

				col = clamp(col, 0.0, 1.0)*_LumWeight.y; 
                col = col*col*col;
                col = lerp(col, blendColor, dx);			
                col = lerp(col, blendColor, dy);      
				col = clamp(col,0.0,_LumWeight.w);          

				SurfaceOutputStandard o;
				UNITY_INITIALIZE_OUTPUT(SurfaceOutputStandard, o);
				o.Albedo = col;
				o.Emission = 0.0;
				o.Alpha = 1.0;
				o.Metallic = _Metallic;
				o.Smoothness = _Glossiness;
				o.Occlusion = 1.0;
				o.Normal = onormal2;

				UnityGI gi;
				UNITY_INITIALIZE_OUTPUT(UnityGI, gi);
				gi.indirect.diffuse = 0;
				gi.indirect.specular = 0;
				gi.light.color = cwac;
				gi.light.dir = _WorldSpaceLightPos0.xyz;

				UnityGIInput giInput;
				UNITY_INITIALIZE_OUTPUT(UnityGIInput, giInput);
				giInput.light = gi.light;
				giInput.worldPos = wpos;
				giInput.worldViewDir = worldViewDir;
				giInput.atten = 1;
				giInput.lightmapUV = 0.0;
				giInput.ambient.rgb = 0.0;

				giInput.probeHDR[0] = unity_SpecCube0_HDR;
				giInput.probeHDR[1] = unity_SpecCube1_HDR;

				#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
					giInput.boxMin[0] = unity_SpecCube0_BoxMin;
				#endif

				#ifdef UNITY_SPECCUBE_BOX_PROJECTION
					giInput.boxMax[0] = unity_SpecCube0_BoxMax;
					giInput.probePosition[0] = unity_SpecCube0_ProbePosition;
					giInput.boxMax[1] = unity_SpecCube1_BoxMax;
					giInput.boxMin[1] = unity_SpecCube1_BoxMin;
					giInput.probePosition[1] = unity_SpecCube1_ProbePosition;
				#endif

				LightingStandard_GI(o, giInput, gi);
				float4 color = LightingStandard(o, worldViewDir, gi);

				float4 screenPos = UnityWorldToClipPos(wpos);
				// fo.depth = z;
				
				UNITY_CALC_FOG_FACTOR(vop.dgPos.z);
				UNITY_APPLY_FOG(unityFogFactor, color);
				color.a = 1;







					// skybox
					//return float4(col, 1.0);
				//}
                  
                // col = spectrum03(fCircle(wpos, depth));
                // col = rgb2hsv(col);
                // col.r += _Time.y;
                // col = hsv2rgb(col);
				// col = clamp(col, 0.0, 1.0);                       
                return color;
            }
            ENDCG
        }
    }
}