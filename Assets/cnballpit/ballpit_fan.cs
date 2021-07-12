
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class ballpit_fan : UdonSharpBehaviour
{
	public GameObject MainControl;
	private ballpit_stable_control m;

    void Start()
    {
		m = MainControl.GetComponent<ballpit_stable_control>();
		m.fan_position = transform.localPosition;
		m.fan_rotation = new Vector4( transform.localRotation.x, transform.localRotation.y, transform.localRotation.z, transform.localRotation.w );
    }
	
	void UpdateFanValue()
	{
		m.fan_position = transform.localPosition;
		m.fan_rotation = new Vector4( transform.localRotation.x, transform.localRotation.y, transform.localRotation.z, transform.localRotation.w );
	}

    void Update ()
	{
		UpdateFanValue();
	}		
	/*
    override public void OnPickup ()
    {
		UpdateFanValue();
    }

    override public void OnDrop()
    {
		UpdateFanValue();
    }

	override public void OnDeserialization()
	{
		UpdateFanValue();
	}
	*/
}

