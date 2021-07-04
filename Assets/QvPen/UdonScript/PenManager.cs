using System;
using VRC.Udon.Common;
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDKBase;
using VRC.Udon.Common.Interfaces;

namespace QvPen.Udon
{
    public class PenManager : UdonSharpBehaviour
    {
        [SerializeField]
        private Pen
            pen;

        public Gradient
            colorGradient = new Gradient();

        public float
            inkWidth = 0.005f;

        public Material
            pcInkMaterial,
            questInkMaterial;

        [SerializeField]
        private GameObject
            respawnButton,
            clearButton,
            inUseUI;

        [SerializeField]
        private Text textInUse;

        public void Init(Settings settings)
        {
            // Wait for class inheritance
            pen.Init(this, settings);
        }

        public override void OnPlayerJoined(VRCPlayerApi player)
        {
            if (!Networking.LocalPlayer.IsOwner(pen.gameObject))
                return;

            if (pen.IsHeld())
                SendCustomNetworkEvent(NetworkEventTarget.All, nameof(StartUsing));
        }

        public override void OnPlayerLeft(VRCPlayerApi player)
        {
            if (!Utilities.IsValid(Networking.LocalPlayer))
                return;

            if (!Networking.LocalPlayer.IsOwner(pen.gameObject))
                return;

            if (!pen.IsHeld())
                SendCustomNetworkEvent(NetworkEventTarget.All, nameof(EndUsing));
        }

        public void StartUsing()
        {
            respawnButton.SetActive(false);
            clearButton.SetActive(false);
            inUseUI.SetActive(true);

            var owner = Networking.GetOwner(pen.gameObject);
            textInUse.text = owner != null ? owner.displayName : "Occupied";
        }

        public void EndUsing()
        {
            respawnButton.SetActive(true);
            clearButton.SetActive(true);
            inUseUI.SetActive(false);

            textInUse.text = string.Empty;
        }

        public void ResetAll()
        {
            pen.Respawn();
            pen.Clear();
        }

        public void ClearAll()
        {
            pen.Clear();
        }

        public void SetUseDoubleClick(bool value)
        {
            pen.SetUseDoubleClick(value);
        }

        #region Network

        [UdonSynced, NonSerialized]
        public Vector3[]
            syncPositions = new Vector3[0];

        public override void OnPostSerialization(SerializationResult result)
        {
            if (!result.success)
                pen.DestroyJustBeforeInk();
        }

        public override void OnDeserialization()
        {
            pen.CreateInkInstance(syncPositions);
        }

        #endregion Network
    }
}
