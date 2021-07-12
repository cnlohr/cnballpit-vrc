
using UnityEngine;
using VRC.SDKBase;

#if UDON
using UdonSharp;
using VRC.Udon;

public class ballpit_stable_control : UdonSharpBehaviour
{

	[UdonSynced] public float gravityF = 9.8f;
	[UdonSynced] public float friction = .008f;
	[UdonSynced] public int mode = 5;
	[UdonSynced] public bool balls_reset = false;
	[UdonSynced] public Vector3 fan_position;
	[UdonSynced] public Vector4 fan_rotation;
	public int qualitymode;
	public Material ballpitA;
	public Material ballpitB;
	public Material ballpitRender;
	public GameObject ballpitRenderObject;
	public Material VideoToStealMaterial;
	public CustomRenderTexture CRTColors;
	void Start()
	{
		if (Networking.IsMaster)
		{
			gravityF = 9.8f;
			friction = .008f;
			mode = 5;
			balls_reset = false;
		}
		qualitymode = 1;
		Debug.Log( "ballpit stable control " + gravityF + " / " + friction );
	}
	
	void Update()
	{
		ballpitA.SetVector( "_FanPosition", fan_position );
		ballpitA.SetVector( "_FanRotation", fan_rotation );
		ballpitB.SetVector( "_FanPosition", fan_position );
		ballpitB.SetVector( "_FanRotation", fan_rotation );

		ballpitA.SetFloat( "_ResetBalls", balls_reset?1.0f:0.0f );
		ballpitB.SetFloat( "_ResetBalls", balls_reset?1.0f:0.0f );
		ballpitRender.SetFloat( "_Mode", mode );

		CRTColors.updateMode = (mode == 6)?CustomRenderTextureUpdateMode.Realtime:CustomRenderTextureUpdateMode.OnLoad;

		ballpitA.SetFloat( "_GravityValue", gravityF );
		ballpitB.SetFloat( "_GravityValue", gravityF );
		ballpitA.SetFloat( "_Friction", friction );
		ballpitB.SetFloat( "_Friction", friction );
		ballpitRender.SetFloat( "_ExtraPretty", qualitymode );
		Physics.gravity = new Vector3( 0, -(gravityF*.85f+1.5f), 0 );
	}
}

#else
public class ballpit_stable_control : MonoBehaviour { }
#endif