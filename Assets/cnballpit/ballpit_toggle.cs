
using UnityEngine;
using VRC.SDKBase;

#if UDON
using UdonSharp;
using VRC.Udon;

public class ballpit_toggle : UdonSharpBehaviour
{

	public bool resetted;
	public Material ballpitA;
	public Material ballpitB;
	public GameObject ballpitRender;
	public GameObject ballpitIntroScreen;

	void Start()
	{
		ballpitA.SetFloat( "_ResetBalls", resetted?1.0f:0.0f );
		ballpitB.SetFloat( "_ResetBalls", resetted?1.0f:0.0f );
		ballpitRender.SetActive( !resetted );
	}

	void Interact()
	{
		resetted = !resetted;
		ballpitIntroScreen.SetActive( false );
		ballpitA.SetFloat( "_ResetBalls", resetted?1.0f:0.0f );
		ballpitB.SetFloat( "_ResetBalls", resetted?1.0f:0.0f );
		ballpitRender.SetActive( !resetted );
	}

}

#else
public class ballpit_toggle : MonoBehaviour { }
#endif