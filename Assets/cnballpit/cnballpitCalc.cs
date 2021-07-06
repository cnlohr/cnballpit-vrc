
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class cnballpitCalc : UdonSharpBehaviour
{
	public Camera CamCompositeDepth;
	
	public Camera CamCalcA;
	public Camera CamCalcB;
	public Camera CamAdj0;
	public Camera CamAdj1;

	public Camera CamAdj4;
	public Camera CamAdj5;

	public RenderTexture rtPositionA;
	public RenderTexture rtVelocityA;
	public RenderTexture rtPositionB;
	public RenderTexture rtVelocityB;
	public RenderTexture CAR0;
	public RenderTexture CAR1;
	public Shader TestShaderAdjacency, TestShaderCalc, TestShaderCompositeDepth;
	
	public Material      MatComputeB;
	public Material      MatComputeA;

	public float _TargetFramerate = 120.0f;


	private float        AccumulatedFrameBoundary;

    void Start()
    {
		CamCompositeDepth.SetReplacementShader (TestShaderCompositeDepth, "");
		CamAdj0.SetReplacementShader (TestShaderAdjacency,                "");
		CamAdj1.SetReplacementShader (TestShaderAdjacency,                "");
		CamCalcB.SetReplacementShader(TestShaderCalc,                     "");
		CamAdj4.SetReplacementShader (TestShaderAdjacency,                "");
		CamAdj5.SetReplacementShader (TestShaderAdjacency,                "");
		CamCalcA.SetReplacementShader(TestShaderCalc,                     "");
			
		//Tricky:  Call SetTargetBuffers in the order you want the cameras to execute.
		RenderBuffer[] CAR0A = new RenderBuffer[] { CAR0.colorBuffer };
		CamAdj0.SetTargetBuffers( CAR0A, CAR0.depthBuffer );
		RenderBuffer[] CAR1A = new RenderBuffer[] { CAR1.colorBuffer };
		CamAdj1.SetTargetBuffers( CAR1A, CAR1.depthBuffer );
		
		RenderBuffer[] renderBuffersB = new RenderBuffer[] { rtPositionB.colorBuffer, rtVelocityB.colorBuffer };
		CamCalcB.SetTargetBuffers(renderBuffersB, rtPositionB.depthBuffer);
		
		CamAdj4.SetTargetBuffers( CAR0A, CAR0.depthBuffer );
		CamAdj5.SetTargetBuffers( CAR1A, CAR1.depthBuffer );

		RenderBuffer[] renderBuffersA = new RenderBuffer[] { rtPositionA.colorBuffer, rtVelocityA.colorBuffer };
		CamCalcA.SetTargetBuffers(renderBuffersA, rtPositionA.depthBuffer);

/*		CamCompositeDepth.enabled = false;
		CamCalcA.enabled = false;
		CamCalcB.enabled = false;
		CamAdj0.enabled = false;
		CamAdj1.enabled = false;
		CamAdj4.enabled = false;
		CamAdj5.enabled = false;
		*/
		
		AccumulatedFrameBoundary = 0;
    }
	
	void Update()
	{
		AccumulatedFrameBoundary += _TargetFramerate*Time.deltaTime;
		MatComputeB.SetFloat( "_DontPerformStep", (AccumulatedFrameBoundary>2)?0:1 );
		MatComputeA.SetFloat( "_DontPerformStep", (AccumulatedFrameBoundary>1)?0:1 );
		AccumulatedFrameBoundary = AccumulatedFrameBoundary % 1;
	/*

		if( false )
		{
			CamCompositeDepth.Render();
			CamAdj0.Render();
			CamAdj1.Render();
			CamCalcB.Render();
			CamAdj4.Render();
			CamAdj5.Render();
			CamCalcA.Render();
		}
		else
		{
			CamCompositeDepth.RenderWithShader (TestShaderCompositeDepth, "");
			CamAdj0.RenderWithShader (TestShaderAdjacency,                "");
			CamAdj1.RenderWithShader (TestShaderAdjacency,                "");
			CamCalcB.RenderWithShader(TestShaderCalc,                     "");
			CamAdj4.RenderWithShader (TestShaderAdjacency,                "");
			CamAdj5.RenderWithShader (TestShaderAdjacency,                "");
			CamCalcA.RenderWithShader(TestShaderCalc,                     "");
		}
		*/
	}
}
