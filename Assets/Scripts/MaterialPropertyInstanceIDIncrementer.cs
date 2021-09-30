
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;
using BrokeredUpdates;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class MaterialPropertyInstanceIDIncrementer : UdonSharpBehaviour
{
	public BrokeredUpdateManager brokeredUpdateManager;

    void Start()
    {
		MaterialPropertyBlock block;
		MeshRenderer mr;

		if( !Utilities.IsValid( brokeredUpdateManager ) )
				brokeredUpdateManager = GameObject.Find( "BrokeredUpdateManager" ).GetComponent<BrokeredUpdateManager>();

        int id = brokeredUpdateManager.GetComponent<BrokeredUpdateManager>()._GetIncrementingID();
		block = new MaterialPropertyBlock();
		mr = GetComponent<MeshRenderer>();
		//mr.GetPropertyBlock(block);
		block.SetVector( "_InstanceID", new Vector4( id, 0, 0, 0 ) );
		mr.SetPropertyBlock(block);
    }
}
