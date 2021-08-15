
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using System;

namespace BrokeredUpdates
{
	[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
	public class BrokeredSync : UdonSharpBehaviour
	{
		[UdonSynced] private Vector3    syncPosition = new Vector3( 0, 0, 0 );
		[UdonSynced] private bool       syncMoving;
		[UdonSynced] private Quaternion syncRotation;

		private Vector3                 lastSyncPosition;
		private Quaternion              lastSyncRotation;

		private float fTimeStill;

		public bool bDebug;
		public bool bSnap;
		public bool bHeld;
		public bool bDisableColliderOnGrab = true;
		
		private bool wasMoving;
		private Collider thisCollider;
		private BrokeredUpdateManager brokeredUpdateManager;
		private bool masterMoving;
		private bool firstUpdateSlave;
		private float fDeltaMasterSendUpdateTime;
		
		private bool bUseGravityOnRelease;
		private bool bKinematicOnRelease;

		public void _LogBlockState()
		{
			Debug.Log( $"SYNCMARK\t{gameObject.name}\t{transform.localPosition.x:F3},{transform.localPosition.y:F3},{transform.localPosition.z:F3}\t{transform.localRotation.x:F3},{transform.localRotation.y:F3},{transform.localRotation.z:F3},{transform.localRotation.w:F3}" );
		}
		
		void Start()
		{
			brokeredUpdateManager = GameObject.Find( "BrokeredUpdateManager" ).GetComponent<BrokeredUpdateManager>();
			brokeredUpdateManager._RegisterSlowObjectSyncUpdate( this );

			thisCollider = GetComponent<Collider>();
			
			if( Networking.IsMaster )
			{
				// We previously would do this but it would freeze the master from messing with stuff.
				// XXX TODO: See if you can cycle through players and prevent them from losing sync and reverting locations.
				
				//Let's try ownerless to begin
				//Networking.SetOwner( Networking.LocalPlayer, gameObject );
				//syncPosition = transform.localPosition;
				//syncRotation = transform.localRotation;
				//syncMoving = false;
				
				// This makes things more stable, by initializting everything
				// but, this also makes it so the master can't touch anything for a bit.
				// RequestSerialization();
			}
			else
			{
				firstUpdateSlave = true;
				
				// For whatever reason, we've checked but the sync'd variables are not
				// here populated on Start.  Don't trust their data.
			}
			if( Utilities.IsValid( GetComponent<Rigidbody>() ) )
			{
				bUseGravityOnRelease = GetComponent<Rigidbody>().useGravity;
				bKinematicOnRelease = GetComponent<Rigidbody>().isKinematic;
			}
			wasMoving = false;
			masterMoving = false;
			bHeld = false;
		}
		
		public void _SlowObjectSyncUpdate()
		{
			// In Udon, when loading, sometimes later joining clients miss OnDeserialization().
			// This function will force all of the client's blocks to eventually line up to where
			// they're supposed to be.
			
			// XXX TODO: REVISIT THIS WITH MORE TESTING!!!  It seems buggy when you cause motion to
			// happen but Unity is unaware of it.
			
			// But, don't accidentally move it.  (note: syncPosition.magnitude > 0 is a not great way...
			if( !masterMoving )
			{
				if( Networking.GetOwner( gameObject ) == Networking.LocalPlayer )
				{
					// If we are the last owner, update the sync positions.
					// XXX TODO: This is not well tested XXX TEST MORE.
					// The syncPosition.magnitude clause is to make sure we don'tested
					// do this on start.
					if( ( ( syncPosition - transform.localPosition ).magnitude > 0.001 || 
						Quaternion.Angle( syncRotation, transform.localRotation) > .1 ) &&
						syncPosition.magnitude > 0 )
					{
						syncPosition = transform.localPosition;
						syncRotation = transform.localRotation;
						RequestSerialization();
						if( Utilities.IsValid( GetComponent<Rigidbody>() ) )
						{
							GetComponent<Rigidbody>().velocity = new Vector3( 0, 0, 0 );
							GetComponent<Rigidbody>().Sleep();
						}
					}
				}
				else
				{
					if( syncPosition.magnitude > 0 ) OnDeserialization();
				}
			}
		}

		public void _SendMasterMove()
		{
			syncPosition = transform.localPosition;
			syncRotation = transform.localRotation;
			
			// If moving less than 1mm or .1 degree over a second (or less if no rigid body), freeze.
			if( ( syncPosition - lastSyncPosition ).magnitude < 0.001 && 
				 Quaternion.Angle( syncRotation, lastSyncRotation) < .1 &&
				 !bHeld )
			{
				fTimeStill += Time.deltaTime;
				
				// Make sure we're still for a while before we actually disable the object.
				if( fTimeStill > 1 || !Utilities.IsValid( GetComponent<Rigidbody>() ) || GetComponent<Rigidbody>().isKinematic )
				{
					// Stop Updating
					brokeredUpdateManager._UnregisterSubscription( this );
					
					// Do this so if we were moving SUPER slowly, we actually stop.  TODO: How to disable motion?
					if( Utilities.IsValid( GetComponent<Rigidbody>() ) )
					{
						GetComponent<Rigidbody>().velocity = new Vector3( 0, 0, 0 );
						GetComponent<Rigidbody>().Sleep();
					}

					syncMoving = false;
					if( bDisableColliderOnGrab ) thisCollider.enabled = true;
					masterMoving = false;
				}
			}
			else
			{
				fTimeStill = 0;
			}
		
			lastSyncPosition = syncPosition;
			lastSyncRotation = syncRotation;
		
			//We are being moved.
			RequestSerialization();
		}

		override public void OnPickup ()
		{
			if( bDisableColliderOnGrab ) thisCollider.enabled = false;
			brokeredUpdateManager._RegisterSubscription( this );
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
			if( bDisableColliderOnGrab ) thisCollider.enabled = true;
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
				brokeredUpdateManager._UnregisterSubscription( this );
				if( Utilities.IsValid( GetComponent<Rigidbody>() ) )
				{
					GetComponent<Rigidbody>().useGravity = bUseGravityOnRelease;
					GetComponent<Rigidbody>().isKinematic = bKinematicOnRelease;
					GetComponent<Rigidbody>().velocity = new Vector3( 0, 0, 0 );
					GetComponent<Rigidbody>().Sleep();
				}
			}

			if( !masterMoving )
			{
				if( !wasMoving && syncMoving )
				{
					// If we start being moved by the master, then disable gravity.
					if( Utilities.IsValid( GetComponent<Rigidbody>() ) )
					{
						bUseGravityOnRelease = GetComponent<Rigidbody>().useGravity;
						bKinematicOnRelease = GetComponent<Rigidbody>().isKinematic;
						GetComponent<Rigidbody>().useGravity = false;
						GetComponent<Rigidbody>().isKinematic = true;
					}
					brokeredUpdateManager._RegisterSubscription( this );
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
		
		public void _BrokeredUpdate()
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
					_SendMasterMove();
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
						if( Utilities.IsValid( GetComponent<Rigidbody>() ) )
						{
							GetComponent<Rigidbody>().useGravity = bUseGravityOnRelease;
							GetComponent<Rigidbody>().isKinematic = bKinematicOnRelease;
							GetComponent<Rigidbody>().velocity = new Vector3( 0, 0, 0 );
							GetComponent<Rigidbody>().Sleep();
						}
						brokeredUpdateManager._UnregisterSubscription( this );
					}
				}
			}
		}
	}
}
