
using UnityEngine;
using VRC.SDKBase;

#if UDON
using UdonSharp;
using VRC.Udon;

public class ballpit_mode : UdonSharpBehaviour
{
	public int mode;
	public int NumModes;
	public Material ballpitRender;

	void Start()
	{
		ballpitRender.SetFloat( "_Mode", mode );
	}

	void Interact()
	{
		mode = ( mode + 1 ) % NumModes;
		ballpitRender.SetFloat( "_Mode", mode );
	}

}

#else
public class ballpit_mode : MonoBehaviour { }
#endif