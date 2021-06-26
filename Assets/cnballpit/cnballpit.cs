
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class cnballpit : UdonSharpBehaviour
{
	public RenderTexture rtPosition;
	public RenderTexture rtVelocity;
	RenderBuffer[] renderBuffers;
	private Camera         selCamera;

    void Start()
    {
		Debug.Log( "cnballpit - initialization script - should be unused." );
		selCamera = GetComponent<Camera>();
		//Debug.Log( selCamera.name + " ===>>> " + rtPosition.name + " / " + rtVelocity );
		renderBuffers = new RenderBuffer[] { rtPosition.colorBuffer, rtVelocity.colorBuffer };
		selCamera.SetTargetBuffers(renderBuffers, rtPosition.depthBuffer);
    }
}
