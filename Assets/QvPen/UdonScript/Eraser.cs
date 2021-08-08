using UdonSharp;
using UnityEngine;
using VRC.SDK3.Components;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

namespace QvPen.Udon
{
	[UdonBehaviourSyncMode(BehaviourSyncMode.Manual)]
    public class Eraser : UdonSharpBehaviour
    {
        [SerializeField]
        private Material
            normal,
            erasing;

#pragma warning disable CS0108
        private Renderer
            renderer;
#pragma warning restore CS0108
        private VRC_Pickup
            pickup;
        private VRCObjectSync
            objectSync;

        private bool
            isErasing;

        // EraserManager
        private EraserManager
            eraserManager;

        private int
            inkLayer,
            eraserLayer;
        private string
            inkPrefix;
        private string
            inkPoolName;
        private Transform
            inkPool;

        public void Init(EraserManager eraserManager, Settings settings)
        {
            this.eraserManager = eraserManager;

            inkLayer = settings.inkLayer;
            eraserLayer = settings.eraserLayer;
            inkPrefix = settings.inkPrefix;
            inkPoolName = settings.inkPoolName;

            gameObject.layer = eraserLayer;

            renderer = GetComponent<Renderer>();
            if (eraserManager)
            {
                // For stand-alone erasers
                pickup = (VRC_Pickup)GetComponent(typeof(VRC_Pickup));
                pickup.InteractionText = nameof(Eraser);
                pickup.UseText = "Erase";
            }
            else
            {
                renderer.sharedMaterial = normal;
                inkPool = settings.inkPool;
            }

            objectSync = (VRCObjectSync)GetComponent(typeof(VRCObjectSync));
			RequestSerialization();
        }

        public override void OnPickup()
        {
            eraserManager.SendCustomNetworkEvent(NetworkEventTarget.All, nameof(EraserManager.StartUsing));

            SendCustomNetworkEvent(NetworkEventTarget.All, nameof(OnPickupEvent));
			RequestSerialization();
        }

        public override void OnDrop()
        {
            eraserManager.SendCustomNetworkEvent(NetworkEventTarget.All, nameof(EraserManager.EndUsing));

            SendCustomNetworkEvent(NetworkEventTarget.All, nameof(OnDropEvent));
			RequestSerialization();
        }

        public override void OnPickupUseDown()
        {
            SendCustomNetworkEvent(NetworkEventTarget.All, nameof(StartErasing));
			RequestSerialization();
        }

        public override void OnPickupUseUp()
        {
            SendCustomNetworkEvent(NetworkEventTarget.All, nameof(FinishErasing));
			RequestSerialization();
        }

        public void OnPickupEvent()
        {
            renderer.sharedMaterial = normal;
			RequestSerialization();
        }

        public void OnDropEvent()
        {
            renderer.sharedMaterial = erasing;
			RequestSerialization();
        }

        public void StartErasing()
        {
            isErasing = true;
            renderer.sharedMaterial = erasing;
			RequestSerialization();
        }

        public void FinishErasing()
        {
            isErasing = false;
            renderer.sharedMaterial = normal;
			RequestSerialization();
        }

        private void OnTriggerEnter(Collider other)
        {
            if (
                isErasing &&
                other &&
                other.gameObject.layer == inkLayer &&
                other.transform.parent &&
                other.transform.parent.name.StartsWith(inkPrefix) &&
                other.transform.parent.parent &&
                other.transform.parent.parent.name == inkPoolName
                )
            {
                if (inkPool && other.transform.parent.parent != inkPool)
                    return;

                Destroy(other.transform.parent.gameObject);
            }
			RequestSerialization();
        }

        public bool IsHeld() => pickup.IsHeld;

        public void Respawn()
        {
            pickup.Drop();

            if (Networking.LocalPlayer.IsOwner(gameObject))
                objectSync.Respawn();
			RequestSerialization();
        }
    }
}
