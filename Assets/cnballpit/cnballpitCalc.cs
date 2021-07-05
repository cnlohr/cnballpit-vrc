
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
	
	public Material      MatComputeB;
	public Material      MatComputeA;

	public float _TargetFramerate = 120.0f;


	private float        AccumulatedFrameBoundary;

    void Start()
    {
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

		AccumulatedFrameBoundary = 0;
    }
	
	void Update()
	{
		//Target 100 Updates per second.
		AccumulatedFrameBoundary += _TargetFramerate*Time.deltaTime;
		MatComputeB.SetFloat( "_DontPerformStep", (AccumulatedFrameBoundary>2)?0:1 );
		MatComputeA.SetFloat( "_DontPerformStep", (AccumulatedFrameBoundary>1)?0:1 );
		AccumulatedFrameBoundary = AccumulatedFrameBoundary % 1;
	}
}
