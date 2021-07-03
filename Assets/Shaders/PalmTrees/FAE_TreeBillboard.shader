// Made with Amplify Shader Editor
// Available at the Unity Asset Store - http://u3d.as/y3X 
Shader "FAE/Tree Billboard"
{
	Properties
	{
		_Cutoff( "Mask Clip Value", Float ) = 0.5
		_Atlas("Atlas", 2D) = "white" {}
		_Variationcolor("Variation color", Color) = (1,0.5,0,0.184)
		_Normals("Normals", 2D) = "white" {}
		[HideInInspector] _texcoord( "", 2D ) = "white" {}
		[HideInInspector] __dirty( "", Int ) = 1
	}

	SubShader
	{
		Tags{ "RenderType" = "TransparentCutout"  "Queue" = "AlphaTest+0" }
		Cull Front
		CGPROGRAM
		#include "UnityShaderVariables.cginc"
		#pragma target 3.0
		#pragma multi_compile_instancing
		#include "VS_InstancedIndirect.cginc"
		#pragma instancing_options assumeuniformscaling lodfade maxcount:50 procedural:setup forwardadd
		#pragma multi_compile GPU_FRUSTUM_ON __
		#pragma exclude_renderers xbox360 psp2 n3ds wiiu 
		#pragma surface surf Lambert keepalpha addshadow fullforwardshadows nolightmap  nodirlightmap dithercrossfade vertex:vertexDataFunc 
		struct Input
		{
			half2 uv_texcoord;
		};

		uniform half _WindSpeed;
		uniform half _TrunkWindSpeed;
		uniform half4 _WindDirection;
		uniform half _TrunkWindSwinging;
		uniform half _TrunkWindWeight;
		uniform sampler2D _Normals;
		uniform float4 _Normals_ST;
		uniform sampler2D _Atlas;
		uniform float4 _Atlas_ST;
		uniform half4 _Variationcolor;
		uniform float _Cutoff = 0.5;

		void vertexDataFunc( inout appdata_full v, out Input o )
		{
			UNITY_INITIALIZE_OUTPUT( Input, o );
			float3 ase_objectScale = float3( length( unity_ObjectToWorld[ 0 ].xyz ), length( unity_ObjectToWorld[ 1 ].xyz ), length( unity_ObjectToWorld[ 2 ].xyz ) );
			float3 appendResult18 = (half3(_WindDirection.x , 0.0 , _WindDirection.z));
			half3 _Vector23 = half3(1,1,1);
			float3 break55 = (float3( 0,0,0 ) + (sin( ( ( ( ( _WindSpeed * 0.05 ) * _Time.w ) * ( _TrunkWindSpeed / ase_objectScale ) ) * appendResult18 ) ) - ( half3(-1,-1,-1) + _TrunkWindSwinging )) * (_Vector23 - float3( 0,0,0 )) / (_Vector23 - ( half3(-1,-1,-1) + _TrunkWindSwinging )));
			float3 appendResult56 = (half3(break55.x , 0.0 , break55.z));
			float3 Wind48 = ( ( appendResult56 * _TrunkWindWeight ) * v.color.a );
			v.vertex.xyz += Wind48;
			v.normal = half3(0,1,0);
		}

		void surf( Input i , inout SurfaceOutput o )
		{
			float2 uv_Normals = i.uv_texcoord * _Normals_ST.xy + _Normals_ST.zw;
			half3 tex2DNode11 = UnpackNormal( tex2D( _Normals, uv_Normals ) );
			o.Normal = tex2DNode11;
			float2 uv_Atlas = i.uv_texcoord * _Atlas_ST.xy + _Atlas_ST.zw;
			half4 tex2DNode1 = tex2D( _Atlas, uv_Atlas );
			float4 transform43 = mul(unity_ObjectToWorld,float4( 0,0,0,1 ));
			float4 lerpResult46 = lerp( tex2DNode1 , _Variationcolor , ( _Variationcolor.a * frac( ( ( transform43.x + transform43.y ) + transform43.z ) ) ));
			o.Albedo = lerpResult46.rgb;
			o.Alpha = 1;
			clip( tex2DNode1.a - _Cutoff );
		}

		ENDCG
	}
	Fallback "Diffuse"
}
/*ASEBEGIN
Version=15700
1927;29;1906;1004;718.396;339.832;1;True;False
Node;AmplifyShaderEditor.ObjectToWorldTransfNode;43;-1453.147,140.8373;Float;False;1;0;FLOAT4;0,0,0,1;False;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleAddOpNode;40;-1237.012,160.2166;Float;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleAddOpNode;41;-1049.013,193.016;Float;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.FractNode;42;-885.2475,193.9371;Float;False;1;0;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ColorNode;44;-894.7302,-43.89215;Float;False;Property;_Variationcolor;Variation color;2;0;Create;True;0;0;False;0;1,0.5,0,0.184;0,0,0,0;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;45;-638.8769,97.19617;Float;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.SamplerNode;1;-825.0991,-299.9994;Float;True;Property;_Atlas;Atlas;1;0;Create;True;0;0;False;0;None;None;True;0;False;white;Auto;False;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.CommentaryNode;49;-2516.138,-1505.089;Float;False;3322.649;1011.52;Comment;26;56;55;27;31;48;32;26;24;23;28;25;21;20;22;19;18;37;17;14;36;15;16;35;34;33;57;Wind engine;1,1,1,1;0;0
Node;AmplifyShaderEditor.SamplerNode;11;-72.10028,45.0998;Float;True;Property;_Normals;Normals;3;0;Create;True;0;0;False;0;None;None;True;0;False;white;Auto;True;Object;-1;Auto;Texture2D;6;0;SAMPLER2D;;False;1;FLOAT2;0,0;False;2;FLOAT;0;False;3;FLOAT2;0,0;False;4;FLOAT2;0,0;False;5;FLOAT;1;False;5;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;31;-2.56002,-1130.665;Float;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.VertexColorNode;28;-60.77927,-893.9528;Float;False;0;5;COLOR;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;27;-342.4654,-950.4337;Float;False;Global;_TrunkWindWeight;_TrunkWindWeight;10;0;Create;True;0;0;False;0;2;6;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.DynamicAppendNode;56;-303.8236,-1120.83;Float;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.LerpOp;46;-307.0044,-53.29811;Float;False;3;0;COLOR;0,0,0,0;False;1;COLOR;0,0,0,0;False;2;FLOAT;0;False;1;COLOR;0
Node;AmplifyShaderEditor.RegisterLocalVarNode;48;584.6132,-1107.404;Float;False;Wind;-1;True;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.GetLocalVarNode;50;-30.18862,300.6029;Float;False;48;Wind;1;0;OBJECT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.VertexToFragmentNode;57;408.7239,-1109.255;Float;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;32;269.0231,-1120.742;Float;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.OneMinusNode;54;303.7151,47.08692;Float;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.Vector3Node;53;8.802795,418.4017;Float;False;Constant;_Vector0;Vector 0;4;0;Create;True;0;0;False;0;0,1,0;0,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;37;-1865.635,-1399.488;Float;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.ObjectScaleNode;16;-2135.238,-852.6451;Float;False;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.Vector4Node;14;-2143.935,-1126.542;Float;False;Global;_WindDirection;_WindDirection;9;0;Create;True;0;0;False;0;0,0,0,0;-0.9450631,0,-0.326888,0;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.SimpleDivideOpNode;17;-1860.936,-908.9457;Float;False;2;0;FLOAT;0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.RangedFloatNode;33;-2466.138,-1455.089;Float;False;Global;_WindSpeed;_WindSpeed;7;0;Create;True;0;0;False;0;0.3;0.5;0;1;0;1;FLOAT;0
Node;AmplifyShaderEditor.RangedFloatNode;34;-2400.276,-1376.865;Float;False;Constant;_Float26;Float 26;10;0;Create;True;0;0;False;0;0.05;0;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.TimeNode;36;-2166.043,-1335.786;Float;False;0;5;FLOAT4;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4
Node;AmplifyShaderEditor.RangedFloatNode;15;-2172.73,-941.0371;Float;False;Global;_TrunkWindSpeed;_TrunkWindSpeed;10;0;Create;True;0;0;False;0;10;10;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;19;-1562.932,-1223.736;Float;False;2;2;0;FLOAT;0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SinOpNode;23;-1114.033,-1119.242;Float;False;1;0;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.Vector3Node;25;-1167.489,-767.9471;Float;False;Constant;_Vector23;Vector 23;10;0;Create;True;0;0;False;0;1,1,1;0,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.DynamicAppendNode;18;-1883.295,-1096.746;Float;False;FLOAT3;4;0;FLOAT;0;False;1;FLOAT;0;False;2;FLOAT;0;False;3;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.TFHCRemapNode;26;-869.7344,-1107.843;Float;False;5;0;FLOAT3;0,0,0;False;1;FLOAT3;-1,-1,-1;False;2;FLOAT3;1,1,1;False;3;FLOAT3;0,0,0;False;4;FLOAT3;1,1,1;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleAddOpNode;24;-1096.338,-945.3469;Float;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT;0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;35;-2087.876,-1448.266;Float;False;2;2;0;FLOAT;0;False;1;FLOAT;0;False;1;FLOAT;0
Node;AmplifyShaderEditor.BreakToComponentsNode;55;-642.2948,-1112.043;Float;False;FLOAT3;1;0;FLOAT3;0,0,0;False;16;FLOAT;0;FLOAT;1;FLOAT;2;FLOAT;3;FLOAT;4;FLOAT;5;FLOAT;6;FLOAT;7;FLOAT;8;FLOAT;9;FLOAT;10;FLOAT;11;FLOAT;12;FLOAT;13;FLOAT;14;FLOAT;15
Node;AmplifyShaderEditor.RangedFloatNode;22;-1420.338,-835.3469;Float;False;Global;_TrunkWindSwinging;_TrunkWindSwinging;10;0;Create;True;0;0;False;0;0;0.2;0;0;0;1;FLOAT;0
Node;AmplifyShaderEditor.SimpleMultiplyOpNode;21;-1301.334,-1131.742;Float;False;2;2;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;1;FLOAT3;0
Node;AmplifyShaderEditor.Vector3Node;20;-1334.436,-1005.644;Float;False;Constant;_Vector21;Vector 21;10;0;Create;True;0;0;False;0;-1,-1,-1;0,0,0;0;4;FLOAT3;0;FLOAT;1;FLOAT;2;FLOAT;3
Node;AmplifyShaderEditor.StandardSurfaceOutputNode;0;662.8,-36.6;Half;False;True;2;Half;;0;0;Lambert;FAE/Tree Billboard;False;False;False;False;False;False;True;False;True;False;False;False;True;False;False;False;True;False;False;False;Front;0;False;-1;0;False;-1;False;0;False;-1;0;False;-1;False;0;Masked;0.5;True;True;0;False;TransparentCutout;;AlphaTest;All;True;True;True;True;True;True;True;False;True;True;False;False;False;True;True;True;True;0;False;-1;False;0;False;-1;255;False;-1;255;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;0;False;-1;False;0;4;10;25;False;0.5;True;0;0;False;-1;0;False;-1;0;0;False;-1;0;False;-1;1;False;-1;1;False;-1;0;False;0;0,0,0,0;VertexOffset;True;False;Cylindrical;False;Relative;0;;0;-1;-1;-1;0;False;0;0;False;-1;-1;0;False;-1;3;Include;VS_InstancedIndirect.cginc;False;;Pragma;instancing_options assumeuniformscaling lodfade maxcount:50 procedural:setup forwardadd;False;;Pragma;multi_compile GPU_FRUSTUM_ON __;False;;0;0;15;0;FLOAT3;0,0,0;False;1;FLOAT3;0,0,0;False;2;FLOAT3;0,0,0;False;3;FLOAT;0;False;4;FLOAT;0;False;6;FLOAT3;0,0,0;False;7;FLOAT3;0,0,0;False;8;FLOAT;0;False;9;FLOAT;0;False;10;FLOAT;0;False;13;FLOAT3;0,0,0;False;11;FLOAT3;0,0,0;False;12;FLOAT3;0,0,0;False;14;FLOAT4;0,0,0,0;False;15;FLOAT3;0,0,0;False;0
WireConnection;40;0;43;1
WireConnection;40;1;43;2
WireConnection;41;0;40;0
WireConnection;41;1;43;3
WireConnection;42;0;41;0
WireConnection;45;0;44;4
WireConnection;45;1;42;0
WireConnection;31;0;56;0
WireConnection;31;1;27;0
WireConnection;56;0;55;0
WireConnection;56;2;55;2
WireConnection;46;0;1;0
WireConnection;46;1;44;0
WireConnection;46;2;45;0
WireConnection;48;0;57;0
WireConnection;57;0;32;0
WireConnection;32;0;31;0
WireConnection;32;1;28;4
WireConnection;54;0;11;0
WireConnection;37;0;35;0
WireConnection;37;1;36;4
WireConnection;17;0;15;0
WireConnection;17;1;16;0
WireConnection;19;0;37;0
WireConnection;19;1;17;0
WireConnection;23;0;21;0
WireConnection;18;0;14;1
WireConnection;18;2;14;3
WireConnection;26;0;23;0
WireConnection;26;1;24;0
WireConnection;26;2;25;0
WireConnection;26;4;25;0
WireConnection;24;0;20;0
WireConnection;24;1;22;0
WireConnection;35;0;33;0
WireConnection;35;1;34;0
WireConnection;55;0;26;0
WireConnection;21;0;19;0
WireConnection;21;1;18;0
WireConnection;0;0;46;0
WireConnection;0;1;11;0
WireConnection;0;10;1;4
WireConnection;0;11;50;0
WireConnection;0;12;53;0
ASEEND*/
//CHKSM=DC3C465AEE134FC28554E464FD727EE9C86FE8B8