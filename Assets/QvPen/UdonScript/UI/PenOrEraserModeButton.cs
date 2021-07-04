using UdonSharp;
using UnityEngine;
using UnityEngine.UI;

namespace QvPen.Udon.UI
{
    public class PenOrEraserModeButton : UdonSharpBehaviour
    {
        [SerializeField]
        private Settings settings;

        [SerializeField]
        private Text message;

        private bool use = true;

        public override void Interact()
        {
            use ^= true;

            message.text =
                $"{(use ? "Disable" : "Enable")}\n" +
                $"<size=12>Pen ↔ Eraser</size>\n" +
                $"<size=8>[Double-click the pen]</size>\n" +
                $"<size=14>(Local)</size>";

            foreach (var penManager in settings.penManagers)
            {
                penManager.SetUseDoubleClick(use);
            }
        }
    }
}
