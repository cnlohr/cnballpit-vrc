using UdonSharp;
using UnityEngine;

namespace QvPen.Udon.UI
{
    public class ClearAllButton : UdonSharpBehaviour
    {
        [SerializeField]
        private Settings settings;

        public override void Interact()
        {
            foreach (var penManager in settings.penManagers)
            {
                penManager.ClearAll();
            }
        }
    }
}
