using UdonSharp;
using UnityEngine;
using UnityEngine.UI;

namespace QvPen.Udon.UI
{
    public class ShowOrHideButton : UdonSharpBehaviour
    {
        [SerializeField]
        private Text message;

        [SerializeField]
        private GameObject[] gameObjects;

        [SerializeField]
        private bool isShown = true;

        private void Start()
        {
            foreach (var go in gameObjects)
            {
                go.SetActive(isShown);
            }
        }

        public override void Interact()
        {
            isShown ^= true;

            if (message)
                message.text = $"{(isShown ? "Hide" : "Show")}\n<size=14>(Local)</size>";

            foreach (var go in gameObjects)
            {
                go.SetActive(isShown);
            }
        }
    }
}
