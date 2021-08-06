
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class MaterialPropertyInstanceIDIncrementer : UdonSharpBehaviour
{
    void Start()
    {
		MaterialPropertyBlock block;
		MeshRenderer mr;
        int id = GameObject.Find( "BrokeredUpdateManager" ).GetComponent<BrokeredUpdateManager>().GetIncrementingID();
		block = new MaterialPropertyBlock();
		mr = GetComponent<MeshRenderer>();

		mr.GetPropertyBlock(block);
		block.SetVector( "_InstanceID", new Vector4( id, 0, 0, 0 ) );
		mr.SetPropertyBlock(block);
    }
}
