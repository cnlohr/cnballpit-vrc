
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class cnballpitCalc : UdonSharpBehaviour
{
	//public Camera CamTop;
	//public Camera CamBottom;
	public Camera CamCompositeDepth;
	
	public Camera CamCalcA;
	public Camera CamCalcB;
	public Camera CamAdj0;
	public Camera CamAdj1;
	public Camera CamAdj2;
	public Camera CamAdj3;

	public Camera CamAdj4;
	public Camera CamAdj5;
	public Camera CamAdj6;
	public Camera CamAdj7;

	public RenderTexture rtPositionA;
	public RenderTexture rtVelocityA;
	public RenderTexture rtPositionB;
	public RenderTexture rtVelocityB;
	public RenderTexture CAR0;
	public RenderTexture CAR1;
	public RenderTexture CAR2;
	public RenderTexture CAR3;
    void Start()
    {
		RenderBuffer[] CAR0A = new RenderBuffer[] { CAR0.colorBuffer };
		CamAdj0.SetTargetBuffers( CAR0A, CAR0.depthBuffer );
		RenderBuffer[] CAR1A = new RenderBuffer[] { CAR1.colorBuffer };
		CamAdj1.SetTargetBuffers( CAR1A, CAR1.depthBuffer );
		RenderBuffer[] CAR2A = new RenderBuffer[] { CAR2.colorBuffer };
		CamAdj2.SetTargetBuffers( CAR2A, CAR2.depthBuffer );
		RenderBuffer[] CAR3A = new RenderBuffer[] { CAR3.colorBuffer };
		CamAdj3.SetTargetBuffers( CAR3A, CAR3.depthBuffer );
		
		RenderBuffer[] renderBuffersB = new RenderBuffer[] { rtPositionB.colorBuffer, rtVelocityB.colorBuffer };
		CamCalcB.SetTargetBuffers(renderBuffersB, rtPositionB.depthBuffer);
		
		CamAdj4.SetTargetBuffers( CAR0A, CAR0.depthBuffer );
		CamAdj5.SetTargetBuffers( CAR1A, CAR1.depthBuffer );
		CamAdj6.SetTargetBuffers( CAR2A, CAR2.depthBuffer );
		CamAdj7.SetTargetBuffers( CAR3A, CAR3.depthBuffer );

		RenderBuffer[] renderBuffersA = new RenderBuffer[] { rtPositionA.colorBuffer, rtVelocityA.colorBuffer };
		CamCalcA.SetTargetBuffers(renderBuffersA, rtPositionA.depthBuffer);
    }
}
