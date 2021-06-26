
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class cnballpitCalc : UdonSharpBehaviour
{
	public Camera CamTop;
	public Camera CamBottom;

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
	
    void Start()
    {
		CamTop.enabled = false;
		CamBottom.enabled = false;
		CamCalcA.enabled = false;
		CamCalcB.enabled = false;
		CamAdj0.enabled = false;
		CamAdj1.enabled = false;
		CamAdj2.enabled = false;
		CamAdj3.enabled = false;
		CamAdj4.enabled = false;
		CamAdj5.enabled = false;
		CamAdj6.enabled = false;
		CamAdj7.enabled = false;

		RenderBuffer[] renderBuffersA = new RenderBuffer[] { rtPositionA.colorBuffer, rtVelocityA.colorBuffer };
		CamCalcA.SetTargetBuffers(renderBuffersA, rtPositionA.depthBuffer);
		RenderBuffer[] renderBuffersB = new RenderBuffer[] { rtPositionB.colorBuffer, rtVelocityB.colorBuffer };
		CamCalcB.SetTargetBuffers(renderBuffersB, rtPositionB.depthBuffer);

    }
	
	void OnPreCull()
	{
		if( CamAdj0 )
		{
			CamTop.Render();
			CamBottom.Render();

			CamAdj0.Render();
			CamAdj1.Render();
			CamAdj2.Render();
			CamAdj3.Render();
			CamCalcB.Render();
		
			CamAdj4.Render();
			CamAdj5.Render();
			CamAdj6.Render();
			CamAdj7.Render();
			CamCalcA.Render();
		}
	}
}
