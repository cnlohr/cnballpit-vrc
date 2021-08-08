
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using System;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class BrokeredSync : UdonSharpBehaviour
{
	[UdonSynced] private Vector3    syncPosition;
	[UdonSynced] private bool       syncMoving;
	[UdonSynced] private Quaternion syncRotation;

	private Vector3                 lastSyncPosition;
	private Quaternion              lastSyncRotation;

	public bool bDebug;
	public bool bSnap;
	public bool bHeld;
	
	private bool wasMoving;
	private Collider thisCollider;
	private BrokeredUpdateManager brokeredUpdateManager;
	private bool masterMoving;
	private bool firstUpdateSlave;
	private float fDeltaMasterSendUpdateTime;

	public void LogBlockState()
	{
		Debug.Log( $"SYNCMARK\t{gameObject.name}\t{transform.localPosition.x:F3},{transform.localPosition.y:F3},{transform.localPosition.z:F3}\t{transform.localRotation.x:F3},{transform.localRotation.y:F3},{transform.localRotation.z:F3},{transform.localRotation.w:F3}" );
		
	}
	
    void Start()
    {
		brokeredUpdateManager = GameObject.Find( "BrokeredUpdateManager" ).GetComponent<BrokeredUpdateManager>();
		brokeredUpdateManager.RegisterSnailUpdate( this );

        thisCollider = GetComponent<Collider>();
		
		if( Networking.IsMaster )
		{
			Networking.SetOwner( Networking.LocalPlayer, gameObject );

			syncPosition = transform.localPosition;
			syncRotation = transform.localRotation;
			syncMoving = false;
		}
		else
		{
			firstUpdateSlave = true;
		}
		wasMoving = false;
		masterMoving = false;
		bHeld = false;
    }
	
	public void SnailUpdate()
	{
		if( Networking.IsOwner( gameObject ) )
		{
			if( !syncMoving )
			{
				syncPosition = transform.localPosition;
				syncRotation = transform.localRotation;
				RequestSerialization();
			}
		}
	}

	public void SendMasterMove()
	{
		syncPosition = transform.localPosition;
		syncRotation = transform.localRotation;
		
		// If moving less than 2cm or 1 degree between updates, freeze.
		if( ( syncPosition - lastSyncPosition ).magnitude < 0.002 && 
			 Quaternion.Angle( syncRotation, lastSyncRotation) < 1 &&
			 !bHeld )
		{
			// Stop Updating
			brokeredUpdateManager.UnregisterSubscription( this );
			syncMoving = false;
			thisCollider.enabled = true;
			masterMoving = false;
		}
	
		lastSyncPosition = syncPosition;
		lastSyncRotation = syncRotation;
	
		//We are being moved.
		RequestSerialization();
	}

    override public void OnPickup ()
    {
		thisCollider.enabled = false;
		brokeredUpdateManager.RegisterSubscription( this );
		Networking.SetOwner( Networking.LocalPlayer, gameObject );
		fDeltaMasterSendUpdateTime = 10;
		syncMoving = true;
		masterMoving = true;
		bHeld = true;
    }

	// We don't use Drop here. We want to see if the object has actually stopped moving.
	// But, even if it's paused and it's being held, don't stop.
    override public void OnDrop()
    {
		bHeld = false;
		thisCollider.enabled = true;
	}
	
	public override void OnDeserialization()
	{
		//Shouldn't really happen.
		if( masterMoving ) return;

		if( firstUpdateSlave )
		{
			transform.localPosition = syncPosition;
			transform.localRotation = syncRotation; 
			firstUpdateSlave = false;
		}
		
		if( bDebug )
		{
			Vector4 col = GetComponent<MeshRenderer>().material.GetVector( "_Color" );
			col.z = ( col.z + 0.01f ) % 1;
			GetComponent<MeshRenderer>().material.SetVector( "_Color", col );
		}
		
		if( !syncMoving )
		{
			//We were released before we got the update.
			transform.localPosition = syncPosition;
			transform.localRotation = syncRotation;
			wasMoving = false;
			brokeredUpdateManager.UnregisterSubscription( this );
		}

		if( !masterMoving )
		{
			if( !wasMoving && syncMoving )
			{
				brokeredUpdateManager.RegisterSubscription( this );
				wasMoving = true;
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
	
	public void BrokeredUpdate()
	{
		if( masterMoving )
		{
			if( bSnap )
			{
				Vector3 ea = transform.localRotation.eulerAngles;
				transform.localPosition = new Vector3( 
					Mathf.Round( transform.localPosition.x / .35f ) * .35f,
					Mathf.Round( transform.localPosition.y / .35f ) * .35f,
					Mathf.Round( transform.localPosition.z / .35f ) * .35f
				);
				ea.x = Mathf.Round( ea.x / 30.0f ) * 30.0f;
				ea.y = Mathf.Round( ea.y / 30.0f ) * 30.0f;
				ea.z = Mathf.Round( ea.z / 30.0f ) * 30.0f;
				transform.localRotation =  Quaternion.Euler( ea );
			}
			if( bDebug )
			{
				Vector4 col = GetComponent<MeshRenderer>().material.GetVector( "_Color" );
				col.x = ( col.x + 0.01f ) % 1;
				GetComponent<MeshRenderer>().material.SetVector( "_Color", col );
			}
			fDeltaMasterSendUpdateTime += Time.deltaTime;
			
			// Don't send location more than 20 FPS.
			if( fDeltaMasterSendUpdateTime > 0.05f )
			{
				SendMasterMove();
				fDeltaMasterSendUpdateTime = 0.0f;
			}
		}
		else
		{
			//Still moving, make motion slacky.
			
			if( syncMoving )
			{

				if( bDebug )
				{
					Vector4 col = GetComponent<MeshRenderer>().material.GetVector( "_Color" );
					col.y = ( col.y + 0.01f ) % 1;
					GetComponent<MeshRenderer>().material.SetVector( "_Color", col );
				}

				float iir = Mathf.Pow( 0.001f, Time.deltaTime );
				float inviir = 1.0f - iir;
				transform.localPosition = transform.localPosition * iir + syncPosition * inviir;
				transform.localRotation = Quaternion.Slerp( transform.localRotation, syncRotation, inviir ); 
				
				wasMoving = true;
			}
			else if( wasMoving )
			{
				if( !syncMoving )
				{
					//We were released.
					transform.localPosition = syncPosition;
					transform.localRotation = syncRotation;
					wasMoving = false;
					brokeredUpdateManager.UnregisterSubscription( this );
				}
			}
		}
	}
}
