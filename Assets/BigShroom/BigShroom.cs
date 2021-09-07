
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
public class BigShroom : UdonSharpBehaviour
{
	public GameObject Handle1;
	public GameObject Handle2;
	
    void Start()
    {
        
    }
	
	void Update()
	{
		Vector3 center = ( Handle1.transform.position + Handle2.transform.position ) / 2;
		float scale = ( Handle1.transform.position - Handle2.transform.position ).magnitude * 50;
		if( scale > 30*50 ) scale = 30*50;
		transform.localScale = new Vector3( scale, scale, scale );
		transform.position = center;
		float rx = Handle1.transform.position.x - Handle2.transform.position.x;
		float rz = Handle1.transform.position.z - Handle2.transform.position.z;
		transform.rotation = Quaternion.Euler(0, Mathf.Atan2( rx, rz ) * 57.2958f, 0);
	}
}
