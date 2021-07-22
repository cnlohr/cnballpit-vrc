
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

public class ManualIIRSyncManager : UdonSharpBehaviour
{
	ManualIIRSyncObject [] UpdateObjectList;
	int UpdateObjectListCount = 0;
	
	
    void Start()
    {
   		if( UpdateObjectList == null )
		{
			UpdateObjectList = new ManualIIRSyncObject[1000];
		}

    }
	
	public void RegisterSubscriptionB( ManualIIRSyncObject go )
	{
		if( UpdateObjectList == null )
		{
			UpdateObjectList = new ManualIIRSyncObject[1000];
		}
		if( UpdateObjectListCount < 1000 )
		{
			UpdateObjectList[UpdateObjectListCount] = go;
			UpdateObjectListCount++;
		}
	}
	
	public void UnregisterSubscriptionB( ManualIIRSyncObject go )
	{
		if( UpdateObjectList == null )
		{
			UpdateObjectList = new ManualIIRSyncObject[1000];
		}

		int i;
		for( i = 0; i < UpdateObjectListCount; i++ )
		{
			if( UpdateObjectList[i] == go )
			{
				UpdateObjectListCount--;
				//Remove from list and update list.
				for( ; i < UpdateObjectListCount; i++ )
				{
					UpdateObjectList[i] = UpdateObjectList[i+1];
				}
			}
		}
	}
	
	public void Update()
	{
		int i;
		Debug.Log( UpdateObjectListCount );
		for( i = 0; i < UpdateObjectListCount; i++ )
		{
			ManualIIRSyncObject behavior = UpdateObjectList[i];
			if( behavior != null )
			{
				behavior.OnSubscriptionUpdate();
			}
		}
	}
}
