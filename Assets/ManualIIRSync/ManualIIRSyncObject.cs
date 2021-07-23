
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class ManualIIRSyncObject : UdonSharpBehaviour
{
	[UdonSynced] public Vector3 SyncPosition;
	[UdonSynced] public bool    SyncMoving;
	[UdonSynced] public Quaternion SyncRotation;
	
	private bool WasMoving;
	private Collider thisCollider;
	private ManualIIRSyncManager dispatchManager;
	private bool MasterMoving;
	
    void Start()
    {
		dispatchManager = GameObject.Find( "ManualIIRSyncManager" ).GetComponent<ManualIIRSyncManager>();
        thisCollider = GetComponent<Collider>();
		WasMoving = false;
		MasterMoving = false;
    }

	public void SendMasterMove()
	{
		SyncPosition = transform.localPosition;
		SyncRotation = transform.localRotation;
		
		//We are being moved.
		RequestSerialization();
	}

    override public void OnPickup ()
    {
		thisCollider.enabled = false;
		dispatchManager.RegisterSubscriptionB( this );
		Networking.SetOwner( Networking.LocalPlayer, gameObject );
		SyncMoving = true;
		MasterMoving = true;
    }

    override public void OnDrop()
    {
		dispatchManager.UnregisterSubscriptionB( this );
		SyncMoving = false;
		thisCollider.enabled = true;
		MasterMoving = false;
		SendMasterMove();
    }
	
	public override void OnDeserialization()
	{
		if( !MasterMoving )
		{
			if( WasMoving )
			{
				if( !SyncMoving )
				{
					//We were released.
					transform.localPosition = SyncPosition;
					transform.localRotation = SyncRotation;
					WasMoving = false;
					dispatchManager.UnregisterSubscriptionB( this );
				}
			}
			else
			{
				if( SyncMoving )
				{
					dispatchManager.RegisterSubscriptionB( this );
				}
			}
		}
		else
		{
			if( Networking.GetOwner( gameObject ) != Networking.LocalPlayer )
			{
				//Master is moving AND another player has it.
				((VRC_Pickup)(gameObject.GetComponent(typeof(VRC_Pickup)))).Drop();
			}
		}
	}
	
	public void OnSubscriptionUpdate()
	{
		if( MasterMoving )
		{
			SendMasterMove();
		}
		else
		{
			//Moving Started
			Vector3 lpr = transform.localPosition;
			//Still moving, make motion slacky.
			transform.localPosition = lpr * .7f + SyncPosition * .3f;
			transform.localRotation = Quaternion.Slerp( transform.localRotation, SyncRotation, .3f ); 
			
			WasMoving = true;
		}
	}
}
