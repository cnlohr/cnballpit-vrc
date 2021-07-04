
using UnityEngine;
using VRC.SDKBase;

#if UDON
using UdonSharp;
using VRC.Udon;

public class ballpit_stable_control : UdonSharpBehaviour
{

	[UdonSynced] public float gravityF = 9.8f;
	[UdonSynced] public float friction = .008f;
	[UdonSynced] public int mode = 3;
	[UdonSynced] public bool balls_reset = false;
	public Material ballpitA;
	public Material ballpitB;
	public Material ballpitRender;
	public GameObject ballpitRenderObject;

	void Start()
	{
		if (Networking.IsMaster)
		{
			gravityF = 9.8f;
			friction = .008f;
			mode = 3;
			balls_reset = false;
		}
		Debug.Log( "ballpit stable control " + gravityF + " / " + friction );
	}
	void Update()
	{
	
		ballpitA.SetFloat( "_ResetBalls", balls_reset?1.0f:0.0f );
		ballpitB.SetFloat( "_ResetBalls", balls_reset?1.0f:0.0f );
		//ballpitRenderObject.SetActive( !balls_reset );
		ballpitRender.SetFloat( "_Mode", mode );
		ballpitA.SetFloat( "_GravityValue", gravityF );
		ballpitB.SetFloat( "_GravityValue", gravityF );
		ballpitA.SetFloat( "_Friction", friction );
		ballpitB.SetFloat( "_Friction", friction );
		Physics.gravity = new Vector3( 0, -(gravityF*.85f+1.5f), 0 );
	}
}

#else
public class ballpit_stable_control : MonoBehaviour { }
#endif