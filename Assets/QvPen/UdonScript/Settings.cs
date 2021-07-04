using System;
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;

namespace QvPen.Udon
{
    public class Settings : UdonSharpBehaviour
    {
        [NonSerialized]
        public string
            version;

        [SerializeField]
        private TextAsset
            versionText;

        [SerializeField]
        private Text
            information;

        [SerializeField]
        private Transform
            pensParent,
            erasersParent;

        [NonSerialized]
        public PenManager[]
            penManagers;

        [NonSerialized]
        public EraserManager[]
            eraserManagers;

        // Layer 8 : Interactive
        // Layer 9 : Player
        public int
            inkLayer = 9,
            eraserLayer = 8;

        public readonly string
            inkPrefix = "Ink";

        [NonSerialized]
        public string
            inkPoolName;

        public Shader
            roundedTrail;

        [NonSerialized]
        public Transform
            inkPool;

        private void Start()
        {
            version = versionText.text.Trim();

            P_LOG($"{nameof(QvPen)} {version}");

            information.text = $"<size=20>{nameof(QvPen)}</size>\n<size=14>{version}</size>";

            inkPoolName = $"obj_{Guid.NewGuid()}";

            penManagers = pensParent.GetComponentsInChildren<PenManager>();
            eraserManagers = erasersParent.GetComponentsInChildren<EraserManager>();

            foreach (var penManager in penManagers)
            {
                penManager.Init(this);
            }

            foreach (var eraserManager in eraserManagers)
            {
                eraserManager.Init(this);
            }
        }

        #region Log

        public readonly string
            className = $"{nameof(QvPen)}.{nameof(QvPen.Udon)}.{nameof(QvPen.Udon.Settings)}";

        private Color
            C_APP = new Color(0xf2, 0x7d, 0x4a, 0xff) / 0xff,
            C_LOG = new Color(0x00, 0x8b, 0xca, 0xff) / 0xff,
            C_WAR = new Color(0xfe, 0xeb, 0x5b, 0xff) / 0xff,
            C_ERR = new Color(0xe0, 0x30, 0x5a, 0xff) / 0xff;

        private readonly string
            CTagEnd = "</color>";

        private void P(object o)
        {
            Debug.Log($"[{CTag(C_APP)}{className}{CTagEnd}] {CTag(C_LOG)}{o}{CTagEnd}", this);
        }

        private void P_LOG(object o)
        {
            Debug.Log($"[{CTag(C_APP)}{className}{CTagEnd}] {CTag(C_LOG)}{o}{CTagEnd}", this);
        }

        private void P_WAR(object o)
        {
            Debug.LogWarning($"[{CTag(C_APP)}{className}{CTagEnd}] {CTag(C_WAR)}{o}{CTagEnd}", this);
        }

        private void P_ERR(object o)
        {
            Debug.LogError($"[{CTag(C_APP)}{className}{CTagEnd}] {CTag(C_ERR)}{o}{CTagEnd}", this);
        }

        private string CTag(Color c)
        {
            return $"<color=\"#{ToHtmlStringRGB(c)}\">";
        }

        private string ToHtmlStringRGB(Color c)
        {
            c *= 0xff;
            return $"{Mathf.RoundToInt(c.r):x2}{Mathf.RoundToInt(c.g):x2}{Mathf.RoundToInt(c.b):x2}";
        }

        #endregion
    }
}
