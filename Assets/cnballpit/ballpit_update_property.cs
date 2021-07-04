﻿
using UnityEngine;
using VRC.SDKBase;

#if UDON
using UdonSharp;
using VRC.Udon;

public class ballpit_update_property : UdonSharpBehaviour
{
	public float SetValueGravity;
	public float SetValueFriction;
	public int NumModes;
	public bool  UpdateGravityFriction;
	public bool  UpdateEnable;
	public bool  UpdateDrawMode;
	public GameObject MainControl;

	void Start()
	{
	}
	void Interact()
	{
		ballpit_stable_control m = MainControl.GetComponent<ballpit_stable_control>();
		Networking.SetOwner( Networking.LocalPlayer, MainControl );
		if( UpdateGravityFriction )
		{
			m.gravityF = SetValueGravity;
			m.friction = SetValueFriction;
		}
		if( UpdateEnable )
		{
			m.balls_reset = !m.balls_reset;
		}
		
		if( UpdateDrawMode )
		{
			m.mode = ( m.mode + 1 ) % NumModes;
		}
	}
}

#else
public class ballpit_update_property : MonoBehaviour { }
#endif