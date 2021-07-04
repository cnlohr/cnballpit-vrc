using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

namespace QvPen.Udon
{
    public class EraserManager : UdonSharpBehaviour
    {
        [SerializeField]
        private Eraser
            eraser;

        [SerializeField]
        private GameObject
            respawnButton,
            inUseUI;

        [SerializeField]
        private Text
            textInUse;

        public void Init(Settings settings)
        {
            // Wait for class inheritance
            eraser.Init(this, settings);
        }

        public override void OnPlayerJoined(VRCPlayerApi player)
        {
            if (!Networking.LocalPlayer.IsOwner(eraser.gameObject))
                return;

            if (eraser.IsHeld())
                SendCustomNetworkEvent(NetworkEventTarget.All, nameof(StartUsing));
        }

        public override void OnPlayerLeft(VRCPlayerApi player)
        {
            if (!Utilities.IsValid(Networking.LocalPlayer))
                return;

            if (!Networking.LocalPlayer.IsOwner(eraser.gameObject))
                return;

            if (!eraser.IsHeld())
                SendCustomNetworkEvent(NetworkEventTarget.All, nameof(EndUsing));
        }

        public void StartUsing()
        {
            respawnButton.SetActive(false);
            inUseUI.SetActive(true);

            var owner = Networking.GetOwner(eraser.gameObject);
            textInUse.text = owner != null ? owner.displayName : "Occupied";
        }

        public void EndUsing()
        {
            respawnButton.SetActive(true);
            inUseUI.SetActive(false);

            textInUse.text = string.Empty;
        }

        public void ResetAll()
        {
            eraser.Respawn();
        }
    }
}
