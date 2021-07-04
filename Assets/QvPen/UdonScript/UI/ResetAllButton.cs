using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

namespace QvPen.Udon.UI
{
    public class ResetAllButton : UdonSharpBehaviour
    {
        [SerializeField]
        private Settings settings;

        [SerializeField]
        private Text message;

        private VRCPlayerApi master;

        public override void OnPlayerJoined(VRCPlayerApi player)
        {
            if (master == null || player.playerId <= master.playerId)
            {
                master = player;
                UpdateMessage();
            }
        }

        public override void OnPlayerLeft(VRCPlayerApi player)
        {
            if (player == master)
            {
                master = Networking.GetOwner(gameObject);
                UpdateMessage();
            }
        }

        private void UpdateMessage()
        {
            var masterName = master == null ? "master" : master.displayName;
            message.text =
                $"Reset All\n" +
                $"<size=8>[Only {masterName} can do]</size>\n" +
                $"<size=14>(Global)</size>";
        }

        public override void Interact()
        {
            if (!Networking.IsMaster)
                return;

            foreach (var penManager in settings.penManagers)
            {
                penManager.SendCustomNetworkEvent(NetworkEventTarget.All, nameof(PenManager.ResetAll));
            }

            foreach (var eraserManager in settings.eraserManagers)
            {
                eraserManager.SendCustomNetworkEvent(NetworkEventTarget.All, nameof(EraserManager.ResetAll));
            }
        }
    }
}
