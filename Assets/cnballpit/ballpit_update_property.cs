
using UnityEngine;
using VRC.SDKBase;

#if UDON
using UdonSharp;
using VRC.Udon;

public class ballpit_update_property : UdonSharpBehaviour
{
	public float SetValueGravity;
	public float SetValueFriction;
	public GameObject MainControl;

	void Start()
	{
	}
	void Interact()
	{
		ballpit_stable_control m = MainControl.GetComponent<ballpit_stable_control>();
		m.gravityF = SetValueGravity;
		m.friction = SetValueFriction;
	}
}

#else
public class ballpit_update_property : MonoBehaviour { }
#endif