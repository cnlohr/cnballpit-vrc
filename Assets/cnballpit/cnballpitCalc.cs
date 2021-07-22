
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class cnballpitCalc : UdonSharpBehaviour
{
	public Camera CamCompositeDepth;

	public Camera CamDepthTop;
	public Camera CamDepthBottom;
	
	public Camera CamCalcA;
	public Camera CamCalcB;
	public Camera CamAdj0;
	public Camera CamAdj4;

	public RenderTexture rtDepthThrowawayColor;
	public RenderTexture rtTopDepth;
	public RenderTexture rtBotDepth;
	public RenderTexture rtCompositeDepth;

	public RenderTexture rtPositionA;
	public RenderTexture rtVelocityA;
	public RenderTexture rtPositionB;
	public RenderTexture rtVelocityB;
	public RenderTexture CAR0;

	public Shader TestShaderAdjacency, TestShaderCalc, TestShaderCompositeDepth;
	
	public Material	  MatComputeB;
	public Material	  MatComputeA;

	public float _TargetFramerate = 100.0f;

	private float		AccumulatedFrameBoundary;

	void Start()
	{
		// Just FYI - tested with adding a tag for compute-only.  Only appeared as same speed in-game, or slower.
		CamCompositeDepth.SetReplacementShader (TestShaderCompositeDepth, "");
		CamAdj0.SetReplacementShader (TestShaderAdjacency, "");
		CamCalcB.SetReplacementShader(TestShaderCalc, "");
		CamAdj4.SetReplacementShader (TestShaderAdjacency, "");
		CamCalcA.SetReplacementShader(TestShaderCalc, "");

		RenderBuffer[] CAR0A = new RenderBuffer[] { CAR0.colorBuffer };
		RenderBuffer[] renderBuffersB = new RenderBuffer[] { rtPositionB.colorBuffer, rtVelocityB.colorBuffer };
		RenderBuffer[] renderBuffersA = new RenderBuffer[] { rtPositionA.colorBuffer, rtVelocityA.colorBuffer };

			
		//Tricky:  Call SetTargetBuffers in the order you want the cameras to execute.
		CamDepthBottom.SetTargetBuffers( rtDepthThrowawayColor.colorBuffer, rtBotDepth.depthBuffer );
		CamDepthTop.SetTargetBuffers( rtDepthThrowawayColor.colorBuffer, rtTopDepth.depthBuffer );
		CamCompositeDepth.SetTargetBuffers( rtCompositeDepth.colorBuffer, rtCompositeDepth.depthBuffer );
		CamAdj0.SetTargetBuffers( CAR0A, CAR0.depthBuffer );
		CamCalcB.SetTargetBuffers(renderBuffersB, rtPositionB.depthBuffer);
		CamAdj4.SetTargetBuffers( CAR0A, CAR0.depthBuffer );
		CamCalcA.SetTargetBuffers(renderBuffersA, rtPositionA.depthBuffer);

		AccumulatedFrameBoundary = 0;
	}
	
	void Update()
	{
		AccumulatedFrameBoundary += _TargetFramerate*Time.deltaTime;
		int i;
		i = (AccumulatedFrameBoundary>1)?0:1;
		if( i == 0 ) AccumulatedFrameBoundary--;
		MatComputeB.SetFloat( "_DontPerformStep", i );
		i = (AccumulatedFrameBoundary>1)?0:1;
		if( i == 0 ) AccumulatedFrameBoundary--;
		MatComputeA.SetFloat( "_DontPerformStep", i );
		//Debug.Log( AccumulatedFrameBoundary );
	}
}
