﻿
using UdonSharp;
using UnityEngine;
using UnityEngine.UI;
using VRC.SDKBase;
using VRC.Udon;
using VRC.SDK3.Components;
using VRC.SDK3.Components.Video;
using System.Collections.Generic;

#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UnityEditor;
using UnityEditorInternal;
using UdonSharpEditor;
#endif

namespace Texel
{
    [AddComponentMenu("VideoTXL/UI/Player Controls")]
    public class PlayerControls : UdonSharpBehaviour
    {
        public SyncPlayer videoPlayer;
        public AudioManager audioManager;
        public ControlColorProfile colorProfile;

        public VRCUrlInputField urlInput;

        public GameObject volumeSliderControl;
        public GameObject audio2DControl;
        public GameObject urlInputControl;
        public GameObject progressSliderControl;
        public GameObject syncSliderControl;

        public Image stopIcon;
        public Image pauseIcon;
        public Image lockedIcon;
        public Image unlockedIcon;
        public Image loadIcon;
        public Image resyncIcon;
        public Image repeatIcon;
        public Image shuffleIcon;
        public Image infoIcon;
        public Image playCurrentIcon;
        public Image playLastIcon;
        public Image nextIcon;
        public Image prevIcon;
        public Image playlistIcon;
        public Image masterIcon;
        public Image whitelistIcon;

        public GameObject muteToggleOn;
        public GameObject muteToggleOff;
        public GameObject audio2DToggleOn;
        public GameObject audio2DToggleOff;
        public Slider volumeSlider;

        public Slider progressSlider;
        public Slider syncSlider;
        public Text statusText;
        public Text urlText;
        public Text placeholderText;
        public Text modeText;
        public Text queuedText;

        public Text playlistText;

        public GameObject infoPanel;
        public Text instanceOwnerText;
        public Text masterText;
        public Text playerOwnerText;
        public Text videoOwnerText;
        public InputField currentVideoInput;
        public InputField lastVideoInput;
        public Text currentVideoText;
        public Text lastVideoText;

        public GameObject playlistPanel;

        VideoPlayerProxy dataProxy;

        Color normalColor = new Color(1f, 1f, 1f, .8f);
        Color disabledColor = new Color(.5f, .5f, .5f, .4f);
        Color activeColor = new Color(0f, 1f, .5f, .7f);
        Color attentionColor = new Color(.9f, 0f, 0f, .5f);

        const int PLAYER_STATE_STOPPED = 0;
        const int PLAYER_STATE_LOADING = 1;
        const int PLAYER_STATE_PLAYING = 2;
        const int PLAYER_STATE_ERROR = 3;

        const short VIDEO_SOURCE_NONE = 0;
        const short VIDEO_SOURCE_AVPRO = 1;
        const short VIDEO_SOURCE_UNITY = 2;

        bool infoPanelOpen = false;

        string statusOverride = null;
        string instanceMaster = "";
        string instanceOwner = "";

        bool loadActive = false;
        VRCUrl pendingSubmit;
        bool pendingFromLoadOverride = false;

        VRCPlayerApi[] _playerBuffer = new VRCPlayerApi[100];

        void Start()
        {
            if (Utilities.IsValid(videoPlayer))
                videoPlayer._EnsureInit();

            _PopulateMissingReferences();

            if (Utilities.IsValid(colorProfile))
            {
                normalColor = colorProfile.normalColor;
                disabledColor = colorProfile.disabledColor;
                activeColor = colorProfile.activeColor;
                attentionColor = colorProfile.attentionColor;
            }

            infoIcon.color = normalColor;
            _DisableAllVideoControls();

            queuedText.text = "";
            playlistText.text = "";

            if (Utilities.IsValid(audioManager))
                audioManager._RegisterControls(this);

            if (Utilities.IsValid(videoPlayer))
            {
                if (Utilities.IsValid(videoPlayer.dataProxy))
                {
                    dataProxy = videoPlayer.dataProxy;
                    dataProxy._RegisterEventHandler(this, "_VideoStateUpdate");
                    dataProxy._RegisterEventHandler(this, "_VideoLockUpdate");
                    dataProxy._RegisterEventHandler(this, "_VideoTrackingUpdate");
                    dataProxy._RegisterEventHandler(this, "_VideoInfoUpdate");
                    dataProxy._RegisterEventHandler(this, "_VideoPlaylistUpdate");

                    unlockedIcon.color = normalColor;
                }
            }

            if (dataProxy.quest)
            {
                currentVideoText.enabled = true;
                lastVideoText.enabled = true;

                if (Utilities.IsValid(currentVideoInput))
                    currentVideoInput.enabled = false;
                if (Utilities.IsValid(lastVideoInput))
                    lastVideoInput.enabled = false;
                if (Utilities.IsValid(urlInput))
                    urlInput.enabled = false;
            }
            else
            {
                currentVideoInput.enabled = true;
                lastVideoInput.enabled = true;
            }

            if (Utilities.IsValid(playlistPanel))
            {
                PlaylistUI pui = (PlaylistUI)playlistPanel.GetComponent(typeof(UdonBehaviour));
                if (Utilities.IsValid(pui))
                    pui._InitFromPlayer(videoPlayer);
            }

#if !UNITY_EDITOR
            instanceMaster = Networking.GetOwner(gameObject).displayName;
            _FindOwners();
            SendCustomEventDelayedFrames("_RefreshPlayerAccessIcon", 1);
#endif

            _UpdateAll();
        }

        void _DisableAllVideoControls()
        {
            stopIcon.color = disabledColor;
            pauseIcon.color = disabledColor;
            lockedIcon.color = disabledColor;
            unlockedIcon.color = disabledColor;
            loadIcon.color = disabledColor;
            resyncIcon.color = disabledColor;
            repeatIcon.color = disabledColor;
            //shuffleIcon.color = disabledColor;
            playCurrentIcon.color = disabledColor;
            playLastIcon.color = disabledColor;
            nextIcon.color = disabledColor;
            prevIcon.color = disabledColor;
            playlistIcon.color = disabledColor;
        }

        bool inVolumeControllerUpdate = false;

        public void _AudioManagerUpdate()
        {
            if (!Utilities.IsValid(audioManager))
                return;

            inVolumeControllerUpdate = true;

            if (Utilities.IsValid(volumeSlider))
            {
                float volume = audioManager.masterVolume;
                if (volume != volumeSlider.value)
                    volumeSlider.value = volume;
            }

            UpdateToggleVisual();

            inVolumeControllerUpdate = false;
        }

        /*public void _VolumeControllerUpdate()
        {
            if (!Utilities.IsValid(audioManager))
                return;

            inVolumeControllerUpdate = true;

            if (Utilities.IsValid(volumeSlider))
            {
                float volume = audioManager.volume;
                if (volume != volumeSlider.value)
                    volumeSlider.value = volume;
            }

            UpdateToggleVisual();

            inVolumeControllerUpdate = false;
        }*/

        public void _VideoStateUpdate()
        {
            _UpdateAll();
        }

        public void _VideoLockUpdate()
        {
            _UpdateAll();
        }

        public void _VideoTrackingUpdate()
        {
            _UpdateTracking();
        }

        public void _VideoInfoUpdate()
        {
            _UpdateInfo();
        }

        public void _VideoPlaylistUpdate()
        {
            _UpdatePlaylistInfo();
        }

        public void _HandleUrlInput()
        {
            if (!Utilities.IsValid(videoPlayer))
                return;

            pendingFromLoadOverride = loadActive;
            pendingSubmit = urlInput.GetUrl();

            SendCustomEventDelayedSeconds("_HandleUrlInputDelay", 0.5f);
        }

        public void _HandleUrlInputDelay()
        {
            VRCUrl url = urlInput.GetUrl();
            urlInput.SetUrl(VRCUrl.Empty);

            // Hack to get around Unity always firing OnEndEdit event for submit and lost focus
            // If loading override was on, but it's off immediately after submit, assume user closed override
            // instead of submitting.  Half second delay is a crude defense against a UI race.
            if (pendingFromLoadOverride && !loadActive)
                return;

            videoPlayer._ChangeUrl(url);
            if (Utilities.IsValid(videoPlayer.playlist))
                videoPlayer.playlist._SetEnabled(false);
            loadActive = false;
            _UpdateAll();
        }

        public void _HandleUrlInputClick()
        {
            if (!videoPlayer._CanTakeControl())
                _SetStatusOverride(MakeOwnerMessage(), 3);
        }

        public void _HandleUrlInputChange()
        {
            if (!Utilities.IsValid(videoPlayer))
                return;

            VRCUrl url = urlInput.GetUrl();
            if (url.Get().Length > 0)
                videoPlayer._UpdateQueuedUrl(urlInput.GetUrl());
        }

        public void _HandleStop()
        {
            if (!Utilities.IsValid(videoPlayer))
                return;

            if (videoPlayer._CanTakeControl())
                videoPlayer._TriggerStop();
            else
                _SetStatusOverride(MakeOwnerMessage(), 3);
        }

        public void _HandlePause()
        {
            if (!Utilities.IsValid(videoPlayer))
                return;

            if (videoPlayer._CanTakeControl())
                videoPlayer._TriggerPause();
            else
                _SetStatusOverride(MakeOwnerMessage(), 3);
        }

        public void _HandleResync()
        {
            if (!Utilities.IsValid(videoPlayer))
                return;

            videoPlayer._Resync();
        }

        public void _HandlePlayCurrent()
        {
            if (!Utilities.IsValid(videoPlayer))
                return;
            if (videoPlayer.currentUrl == VRCUrl.Empty)
                return;

            if (videoPlayer._CanTakeControl())
                videoPlayer._ChangeUrl(videoPlayer.currentUrl);
            else
                _SetStatusOverride(MakeOwnerMessage(), 3);
        }

        public void _HandlePlayLast()
        {
            if (!Utilities.IsValid(videoPlayer))
                return;
            if (videoPlayer.lastUrl == VRCUrl.Empty)
                return;

            if (videoPlayer._CanTakeControl())
                videoPlayer._ChangeUrl(videoPlayer.lastUrl);
            else
                _SetStatusOverride(MakeOwnerMessage(), 3);
        }

        public void _HandleInfo()
        {
            infoPanelOpen = !infoPanelOpen;
            infoPanel.SetActive(infoPanelOpen);
            infoIcon.color = infoPanelOpen ? activeColor : normalColor;
        }

        public void _HandleLock()
        {
            if (!Utilities.IsValid(videoPlayer))
                return;

            if (videoPlayer._CanTakeControl())
                videoPlayer._TriggerLock();
            else
                _SetStatusOverride(MakeOwnerMessage(), 3);
        }

        public void _HandleLoad()
        {
            if (!Utilities.IsValid(videoPlayer))
                return;

            if (!videoPlayer._CanTakeControl())
            {
                _SetStatusOverride(MakeOwnerMessage(), 3);
                return;
            }

            //if (videoPlayer.localPlayerState == PLAYER_STATE_ERROR)
            //    loadActive = false;
            //else
                loadActive = !loadActive;

            _UpdateAll();
        }

        public void _HandleRepeat()
        {
            if (!Utilities.IsValid(videoPlayer))
                return;

            if (videoPlayer._CanTakeControl())
                videoPlayer._TriggerRepeatMode();
            else
                _SetStatusOverride(MakeOwnerMessage(), 3);
        }

        bool _draggingProgressSlider = false;
        bool _updatingProgressSlider = false;

        public void _HandleProgressBeginDrag()
        {
            _draggingProgressSlider = true;
            _UpdateTrackingDragging();
        }

        public void _HandleProgressEndDrag()
        {
            _draggingProgressSlider = false;
            _HandleProgressSliderChanged();
        }

        public void _HandleProgressSliderChanged()
        {
            if (_draggingProgressSlider || _updatingProgressSlider)
                return;

            if (float.IsInfinity(dataProxy.trackDuration) || dataProxy.trackDuration <= 0)
                return;

            float targetTime = dataProxy.trackDuration * progressSlider.value;
            videoPlayer._SetTargetTime(targetTime);
        }

        public void _HandleSourceModeClick()
        {
            if (!Utilities.IsValid(videoPlayer))
                return;

            if (!videoPlayer._CanTakeControl())
            {
                _SetStatusOverride(MakeOwnerMessage(), 3);
                return;
            }

            short mode = (short)(dataProxy.playerSourceOverride + 1);
            if (mode > 2)
                mode = 0;

            videoPlayer._SetSourceMode(mode);
        }

        public void _ToggleVolumeMute()
        {
            if (inVolumeControllerUpdate)
                return;

            if (Utilities.IsValid(audioManager))
                audioManager._SetMasterMute(!audioManager.masterMute);
            //audioManager._ToggleMute();
        }

        public void _ToggleAudio2D()
        {
            if (inVolumeControllerUpdate)
                return;

            //if (Utilities.IsValid(audioManager))
            //    audioManager._ToggleAudio2D();
        }

        public void _UpdateVolumeSlider()
        {
            if (inVolumeControllerUpdate)
                return;

            if (Utilities.IsValid(audioManager) && Utilities.IsValid(volumeSlider))
                audioManager._SetMasterVolume(volumeSlider.value);
            //audioManager._ApplyVolume(volumeSlider.value);
        }

        public void _HandlePlaylist()
        {
            if (!Utilities.IsValid(videoPlayer) || !Utilities.IsValid(videoPlayer.playlist))
                return;

            // Toggle panel if present
            if (Utilities.IsValid(playlistPanel))
            {
                playlistPanel.SetActive(!playlistPanel.activeSelf);
                playlistIcon.color = playlistPanel.activeSelf ? activeColor : normalColor;

                SendCustomEventDelayedFrames("_ScrollPlaylistCurrent", 10);

                return;
            }

            // If no panel, legacy behavior of re-enabling playlist at current track
            videoPlayer.playlist._SetEnabled(true);
            if (!videoPlayer.playlist.PlaylistEnabled)
                return;

            if (videoPlayer.playlist.holdOnReady)
                videoPlayer._HoldNextVideo();

            videoPlayer._ChangeUrl(videoPlayer.playlist._GetCurrent());
        }

        public void _ScrollPlaylistCurrent()
        {
            PlaylistUI pui = (PlaylistUI)playlistPanel.GetComponent(typeof(UdonBehaviour));
            if (Utilities.IsValid(pui))
                pui._ScrollToCurrentTrack();
        }

        public void _HandlePlaylistNext()
        {
            if (!Utilities.IsValid(videoPlayer) || !Utilities.IsValid(videoPlayer.playlist))
                return;

            if (videoPlayer.playlist._MoveNext())
            {
                if (videoPlayer.playlist.holdOnReady)
                    videoPlayer._HoldNextVideo();
                videoPlayer._ChangeUrlQuestFallback(videoPlayer.playlist._GetCurrent(), videoPlayer.playlist._GetCurrentQuest());
            }
        }

        public void _HandlePlaylistPrev()
        {
            if (!Utilities.IsValid(videoPlayer) || !Utilities.IsValid(videoPlayer.playlist))
                return;

            if (videoPlayer.playlist._MovePrev())
            {
                if (videoPlayer.playlist.holdOnReady)
                    videoPlayer._HoldNextVideo();
                videoPlayer._ChangeUrlQuestFallback(videoPlayer.playlist._GetCurrent(), videoPlayer.playlist._GetCurrentQuest());
            }
        }

        void _SetStatusOverride(string msg, float timeout)
        {
            statusOverride = msg;
            SendCustomEventDelayedSeconds("_ClearStatusOverride", timeout);
            _UpdateAll();
        }

        public void _ClearStatusOverride()
        {
            statusOverride = null;
            _UpdateAll();
        }

        public void _UpdateTrackingDragging()
        {
            int playerState = dataProxy.playerState;
            if (!_draggingProgressSlider || playerState != PLAYER_STATE_PLAYING || loadActive || !dataProxy.seekableSource)
                return;

            string durationStr = System.TimeSpan.FromSeconds(dataProxy.trackDuration).ToString(@"hh\:mm\:ss");
            string positionStr = System.TimeSpan.FromSeconds(dataProxy.trackDuration * progressSlider.value).ToString(@"hh\:mm\:ss");
            SetStatusText(positionStr + " / " + durationStr);
            progressSliderControl.SetActive(true);
            syncSliderControl.SetActive(false);

            SendCustomEventDelayedSeconds("_UpdateTrackingDragging", 0.1f);
        }

        public void _UpdateTracking()
        {
            int playerState = dataProxy.playerState;
            if (playerState != PLAYER_STATE_PLAYING || loadActive)
                return;

            if (!videoPlayer.seekableSource)
            {
                SetStatusText("Streaming...");
                progressSliderControl.SetActive(false);
                syncSliderControl.SetActive(false);
            }
            else if (!_draggingProgressSlider)
            {
                if (dataProxy.trackTarget - dataProxy.trackPosition > 1)
                {
                    SetStatusText("Synchronizing...");
                    progressSliderControl.SetActive(false);
                    syncSliderControl.SetActive(true);
                    syncSlider.value = dataProxy.trackPosition / dataProxy.trackTarget;
                }
                else
                {
                    string durationStr = System.TimeSpan.FromSeconds(dataProxy.trackDuration).ToString(@"hh\:mm\:ss");
                    string positionStr = System.TimeSpan.FromSeconds(dataProxy.trackPosition).ToString(@"hh\:mm\:ss");
                    SetStatusText(positionStr + " / " + durationStr);
                    progressSliderControl.SetActive(true);
                    syncSliderControl.SetActive(false);

                    _updatingProgressSlider = true;
                    progressSlider.value = (dataProxy.trackDuration <= 0) ? 0f : Mathf.Clamp01(dataProxy.trackPosition / dataProxy.trackDuration);
                    _updatingProgressSlider = false;
                }
            }
        }

        public void _UpdateInfo()
        {
            bool canControl = videoPlayer._CanTakeControl();
            bool enableControl = !videoPlayer.locked || canControl;

            string currentUrl = dataProxy.currentUrl.Get();
            string lastUrl = dataProxy.lastUrl.Get();

            playCurrentIcon.color = (enableControl && currentUrl != "") ? normalColor : disabledColor;
            playLastIcon.color = (enableControl && lastUrl != "") ? normalColor : disabledColor;

            if (dataProxy.quest)
            {
                currentVideoText.text = currentUrl;
                lastVideoText.text = lastUrl;
            }
            else
            {
                currentVideoInput.text = currentUrl;
                lastVideoInput.text = lastUrl;
            }

            instanceOwnerText.text = instanceOwner;
            masterText.text = instanceMaster;
            // videoOwnerText.text = videoPlayer.videoOwner;

            string queuedUrl = dataProxy.queuedUrl.Get();
            queuedText.text = (queuedUrl != "") ? "QUEUED" : "";

            VRCPlayerApi owner = Networking.GetOwner(videoPlayer.gameObject);
            if (Utilities.IsValid(owner) && owner.IsValid())
                playerOwnerText.text = owner.displayName;
            else
                playerOwnerText.text = "";

        }

        public void _UpdatePlaylistInfo()
        {
            bool canControl = videoPlayer._CanTakeControl();
            bool enableControl = !videoPlayer.locked || canControl;

            repeatIcon.color = videoPlayer.repeatPlaylist ? activeColor : normalColor;
            Playlist playlist = videoPlayer.playlist;

            if (Utilities.IsValid(playlist) && playlist.trackCount > 0)
            {
                nextIcon.color = (enableControl && playlist.PlaylistEnabled && playlist._HasNextTrack()) ? normalColor : disabledColor;
                prevIcon.color = (enableControl && playlist.PlaylistEnabled && playlist._HasPrevTrack()) ? normalColor : disabledColor;
                playlistIcon.color = enableControl ? normalColor : disabledColor;

                bool playlistActive = playlist.PlaylistEnabled && playlist.CurrentIndex >= 0 && playlist.trackCount > 0;
                if (!playlistActive)
                    playlistText.text = "";
                else if (playlist.catalogueMode)
                    playlistText.text = $"TRACK: {playlist.CurrentIndex + 1}";
                else
                    playlistText.text = $"TRACK: {playlist.CurrentIndex + 1} / {playlist.trackCount}";
            }
            else
            {
                nextIcon.color = disabledColor;
                prevIcon.color = disabledColor;
                playlistIcon.color = disabledColor;
                playlistText.text = "";
            }

            if (Utilities.IsValid(playlist) && Utilities.IsValid(playlistPanel))
                playlistIcon.color = playlistPanel.activeSelf ? activeColor : normalColor;
        }

        public void _UpdateAll()
        {
            bool canControl = videoPlayer._CanTakeControl();
            bool enableControl = !videoPlayer.locked || canControl;

            int playerState = dataProxy.playerState;

            if (enableControl && loadActive)
            {
                loadIcon.color = activeColor;
                urlInputControl.SetActive(true);
                urlInput.readOnly = !canControl;
                SetPlaceholderText("Enter Video URL...");
                SetStatusText("");
            } else
                loadIcon.color = enableControl ? normalColor : disabledColor;

            if (playerState == PLAYER_STATE_PLAYING && !loadActive)
            {
                urlInput.readOnly = true;
                urlInputControl.SetActive(false);

                stopIcon.color = enableControl ? normalColor : disabledColor;
                //loadIcon.color = enableControl ? normalColor : disabledColor;
                resyncIcon.color = normalColor;

                if (dataProxy.paused)
                    pauseIcon.color = activeColor;
                else
                    pauseIcon.color = (enableControl && videoPlayer.seekableSource) ? normalColor : disabledColor;

                progressSlider.interactable = enableControl;
                _UpdateTracking();
            }
            else
            {
                _draggingProgressSlider = false;

                stopIcon.color = disabledColor;
                //loadIcon.color = disabledColor;
                progressSliderControl.SetActive(false);
                syncSliderControl.SetActive(false);
                urlInputControl.SetActive(true);

                if (playerState == PLAYER_STATE_LOADING)
                {
                    stopIcon.color = enableControl ? normalColor : disabledColor;
                    //loadIcon.color = enableControl ? normalColor : disabledColor;
                    resyncIcon.color = normalColor;
                    pauseIcon.color = disabledColor;

                    if (!loadActive)
                    {
                        SetPlaceholderText(dataProxy.heldReady ? "Ready" : "Loading...");
                        urlInput.readOnly = true;
                        SetStatusText("");
                    }
                }
                else if (playerState == PLAYER_STATE_ERROR)
                {
                    stopIcon.color = disabledColor;
                    //loadIcon.color = normalColor;
                    resyncIcon.color = normalColor;
                    pauseIcon.color = disabledColor;
                    //loadActive = false;

                    if (!loadActive)
                    {
                        switch (videoPlayer.localLastErrorCode)
                        {
                            case VideoError.RateLimited:
                                SetPlaceholderText("Rate limited, wait and try again");
                                break;
                            case VideoError.PlayerError:
                                SetPlaceholderText("Video player error");
                                break;
                            case VideoError.InvalidURL:
                                SetPlaceholderText("Invalid URL or source offline");
                                break;
                            case VideoError.AccessDenied:
                                SetPlaceholderText("Video blocked, enable untrusted URLs");
                                break;
                            case VideoError.Unknown:
                            default:
                                SetPlaceholderText("Failed to load video");
                                break;
                        }

                        if (dataProxy.streamFallback)
                            SetPlaceholderText("Retrying as stream source");

                        urlInput.readOnly = !canControl;
                        SetStatusText("");
                    }
                }
                else if (playerState == PLAYER_STATE_PLAYING || playerState == PLAYER_STATE_STOPPED)
                {
                    if (playerState == PLAYER_STATE_STOPPED)
                    {
                        //loadActive = false;
                        pendingFromLoadOverride = false;
                        stopIcon.color = disabledColor;
                        //loadIcon.color = disabledColor;
                        resyncIcon.color = disabledColor;
                        pauseIcon.color = disabledColor;
                    }
                    else
                    {
                        stopIcon.color = enableControl ? normalColor : disabledColor;
                        //loadIcon.color = activeColor;
                        resyncIcon.color = normalColor;

                        if (dataProxy.paused)
                            pauseIcon.color = activeColor;
                        else
                            pauseIcon.color = (enableControl && videoPlayer.seekableSource) ? normalColor : disabledColor;
                    }

                    if (!loadActive)
                    {
                        urlInput.readOnly = !canControl;
                        if (canControl)
                        {
                            SetPlaceholderText("Enter Video URL...");
                            SetStatusText("");
                        }
                        else
                        {
                            SetPlaceholderText("");
                            SetStatusText(MakeOwnerMessage());
                        }
                    }
                }
            }

            lockedIcon.enabled = videoPlayer.locked;
            unlockedIcon.enabled = !videoPlayer.locked;
            if (videoPlayer.locked)
                lockedIcon.color = canControl ? normalColor : attentionColor;

            switch (dataProxy.playerSourceOverride)
            {
                case VIDEO_SOURCE_UNITY:
                    modeText.text = "VIDEO";
                    break;
                case VIDEO_SOURCE_AVPRO:
                    modeText.text = "STREAM";
                    break;
                case VIDEO_SOURCE_NONE:
                default:
                    if (playerState == PLAYER_STATE_STOPPED)
                        modeText.text = "AUTO";
                    else
                    {
                        switch (dataProxy.playerSource)
                        {
                            case VIDEO_SOURCE_UNITY:
                                modeText.text = "AUTO VIDEO";
                                break;
                            case VIDEO_SOURCE_AVPRO:
                                modeText.text = "AUTO STREAM";
                                break;
                            case VIDEO_SOURCE_NONE:
                            default:
                                modeText.text = "AUTO";
                                break;
                        }
                    }
                    break;
            }

            _UpdatePlaylistInfo();
        }

        void SetStatusText(string msg)
        {
            if (statusOverride != null)
                statusText.text = statusOverride;
            else
                statusText.text = msg;
        }

        void SetPlaceholderText(string msg)
        {
            if (statusOverride != null)
                placeholderText.text = "";
            else
                placeholderText.text = msg;
        }

        void _FindOwners()
        {
            int playerCount = VRCPlayerApi.GetPlayerCount();
            _playerBuffer = VRCPlayerApi.GetPlayers(_playerBuffer);

            foreach (VRCPlayerApi player in _playerBuffer)
            {
                if (!Utilities.IsValid(player) || !player.IsValid())
                    continue;
                if (player.isInstanceOwner)
                    instanceOwner = player.displayName;
                if (player.isMaster)
                    instanceMaster = player.displayName;
            }
        }

        string MakeOwnerMessage()
        {
            if (instanceMaster == instanceOwner || instanceOwner == "")
                return $"Controls locked to master {instanceMaster}";
            else
                return $"Controls locked to master {instanceMaster} and owner {instanceOwner}";
        }

        public override void OnPlayerJoined(VRCPlayerApi player)
        {
            _FindOwners();
            _RefreshPlayerAccessIcon();
        }

        public override void OnPlayerLeft(VRCPlayerApi player)
        {
            _FindOwners();
            _RefreshPlayerAccessIcon();
        }

        void UpdateToggleVisual()
        {
            if (Utilities.IsValid(audioManager))
            {
                if (Utilities.IsValid(muteToggleOn) && Utilities.IsValid(muteToggleOff))
                {
                    muteToggleOn.SetActive(audioManager.masterMute);
                    muteToggleOff.SetActive(!audioManager.masterMute);
                }
                if (Utilities.IsValid(audio2DToggleOn) && Utilities.IsValid(audio2DToggleOff))
                {
                    //audio2DToggleOn.SetActive(audioManager.audio2D);
                    //audio2DToggleOff.SetActive(!audioManager.audio2D);
                }
            }
        }

        public void _RefreshPlayerAccessIcon()
        {
            masterIcon.enabled = false;
            whitelistIcon.enabled = false;

            if (!Utilities.IsValid(videoPlayer.accessControl))
            {
                masterIcon.enabled = videoPlayer._IsAdmin();
                return;
            }

            VRCPlayerApi player = Networking.LocalPlayer;
            if (!Utilities.IsValid(player))
                return;

            AccessControl acl = videoPlayer.accessControl;
            if (acl.allowInstanceOwner && player.isInstanceOwner)
                masterIcon.enabled = true;
            else if (acl.allowMaster && player.isMaster)
                masterIcon.enabled = true;
            else if (acl.allowWhitelist && acl._LocalWhitelisted())
                whitelistIcon.enabled = true;
        }

        void _PopulateMissingReferences()
        {
            if (!Utilities.IsValid(videoPlayer))
            {
                videoPlayer = transform.parent.GetComponent<SyncPlayer>();
                if (Utilities.IsValid(videoPlayer))
                    videoPlayer.debugLog._Write("PlayerControls", $"Missing syncplayer reference, found one on parent");
                else
                    Debug.LogError("Missing syncplayer reference, also could not find one on parent!");
            }

            // Volume

            if (!Utilities.IsValid(volumeSliderControl))
                volumeSliderControl = _FindGameObject("MainPanel/UpperRow/VolumeGroup/Slider");
            if (!Utilities.IsValid(volumeSlider))
                volumeSlider = (Slider)_FindComponent("MainPanel/UpperRow/VolumeGroup/Slider", typeof(Slider));
            if (!Utilities.IsValid(muteToggleOn))
                muteToggleOn = _FindGameObject("MainPanel/UpperRow/VolumeGroup/MuteButton/IconMuted");
            if (!Utilities.IsValid(muteToggleOff))
                muteToggleOff = _FindGameObject("MainPanel/UpperRow/VolumeGroup/MuteButton/IconVolume");

            // Icons

            if (!Utilities.IsValid(stopIcon))
                stopIcon = (Image)_FindComponent("MainPanel/UpperRow/ControlGroup/StopButton/IconStop", typeof(Image));
            if (!Utilities.IsValid(pauseIcon))
                pauseIcon = (Image)_FindComponent("MainPanel/UpperRow/ControlGroup/PauseButton/IconPause", typeof(Image));
            if (!Utilities.IsValid(lockedIcon))
                lockedIcon = (Image)_FindComponent("MainPanel/LowerRow/InputProgress/MasterLockButton/IconLocked", typeof(Image));
            if (!Utilities.IsValid(unlockedIcon))
                unlockedIcon = (Image)_FindComponent("MainPanel/LowerRow/InputProgress/MasterLockButton/IconUnlocked", typeof(Image));
            if (!Utilities.IsValid(loadIcon))
                loadIcon = (Image)_FindComponent("MainPanel/LowerRow/InputProgress/LoadButton/IconLoad", typeof(Image));
            if (!Utilities.IsValid(resyncIcon))
                resyncIcon = (Image)_FindComponent("MainPanel/UpperRow/SyncGroup/ResyncButton/IconResync", typeof(Image));
            if (!Utilities.IsValid(repeatIcon))
                repeatIcon = (Image)_FindComponent("MainPanel/UpperRow/ButtonGroup/RepeatButton/IconRepeat", typeof(Image));
            if (!Utilities.IsValid(playlistIcon))
                playlistIcon = (Image)_FindComponent("MainPanel/UpperRow/ButtonGroup/PlaylistButton/IconPlaylist", typeof(Image));
            if (!Utilities.IsValid(infoIcon))
                infoIcon = (Image)_FindComponent("MainPanel/UpperRow/ButtonGroup/InfoButton/IconInfo", typeof(Image));
            if (!Utilities.IsValid(nextIcon))
                nextIcon = (Image)_FindComponent("MainPanel/UpperRow/ControlGroup/NextButton/IconNext", typeof(Image));
            if (!Utilities.IsValid(prevIcon))
                prevIcon = (Image)_FindComponent("MainPanel/UpperRow/ControlGroup/PrevButton/IconPrev", typeof(Image));
            if (!Utilities.IsValid(masterIcon))
                masterIcon = (Image)_FindComponent("MainPanel/LowerRow/InputProgress/PlayerAccess/IconMaster", typeof(Image));
            if (!Utilities.IsValid(whitelistIcon))
                whitelistIcon = (Image)_FindComponent("MainPanel/LowerRow/InputProgress/PlayerAccess/IconWhitelist", typeof(Image));

            // Super Bar

            if (!Utilities.IsValid(progressSliderControl))
                progressSliderControl = _FindGameObject("MainPanel/LowerRow/InputProgress/TrackingSlider");
            if (!Utilities.IsValid(progressSlider))
                progressSlider = (Slider)_FindComponent("MainPanel/LowerRow/InputProgress/TrackingSlider", typeof(Slider));
            if (!Utilities.IsValid(syncSliderControl))
                syncSliderControl = _FindGameObject("MainPanel/LowerRow/InputProgress/SyncSlider");
            if (!Utilities.IsValid(syncSlider))
                syncSlider = (Slider)_FindComponent("MainPanel/LowerRow/InputProgress/SyncSlider", typeof(Slider));
            if (!Utilities.IsValid(urlInputControl))
                urlInputControl = _FindGameObject("MainPanel/LowerRow/InputProgress/InputField");
            if (!Utilities.IsValid(urlInput))
                urlInput = (VRCUrlInputField)_FindComponent("MainPanel/LowerRow/InputProgress/InputField", typeof(VRCUrlInputField));
            if (!Utilities.IsValid(urlText))
                urlText = (Text)_FindComponent("MainPanel/LowerRow/InputProgress/InputField/TextMask/Text", typeof(Text));
            if (!Utilities.IsValid(statusText))
                statusText = (Text)_FindComponent("MainPanel/LowerRow/InputProgress/StatusText", typeof(Text));
            if (!Utilities.IsValid(placeholderText))
                placeholderText = (Text)_FindComponent("MainPanel/LowerRow/InputProgress/InputField/TextMask/Placeholder", typeof(Text));
            if (!Utilities.IsValid(modeText))
                modeText = (Text)_FindComponent("MainPanel/LowerRow/InputProgress/SourceMode", typeof(Text));
            if (!Utilities.IsValid(queuedText))
                queuedText = (Text)_FindComponent("MainPanel/LowerRow/InputProgress/QueuedText", typeof(Text));
            if (!Utilities.IsValid(playlistText))
                playlistText = (Text)_FindComponent("MainPanel/LowerRow/InputProgress/PlaylistText", typeof(Text));

            if (!Utilities.IsValid(urlInput) && Utilities.IsValid(videoPlayer.debugLog))
                videoPlayer.debugLog._Write("PlayerControls", "Could not resolve URL input component: is your VRC SDK missing VRCUrlInput?");

            // Info Panel 

            if (!Utilities.IsValid(infoPanel))
                infoPanel = _FindGameObject("InfoPanel");
            if (!Utilities.IsValid(instanceOwnerText))
                instanceOwnerText = (Text)_FindComponent("InfoPanel/Fields/InstanceOwner/InstanceOwnerName", typeof(Text));
            if (!Utilities.IsValid(masterText))
                masterText = (Text)_FindComponent("InfoPanel/Fields/Master/MasterName", typeof(Text));
            if (!Utilities.IsValid(playerOwnerText))
                playerOwnerText = (Text)_FindComponent("InfoPanel/Fields/PlayerOwner/PlayerOwnerName", typeof(Text));
            if (!Utilities.IsValid(videoOwnerText))
                videoOwnerText = (Text)_FindComponent("InfoPanel/Fields/VideoOwner/VideoOwnerName", typeof(Text));
            if (!Utilities.IsValid(currentVideoInput))
                currentVideoInput = (InputField)_FindComponent("InfoPanel/Fields/CurrentVideo/InputField", typeof(InputField));
            if (!Utilities.IsValid(currentVideoText))
                currentVideoText = (Text)_FindComponent("InfoPanel/Fields/CurrentVideo/InputField/TextMask/Text", typeof(Text));
            if (!Utilities.IsValid(playCurrentIcon))
                playCurrentIcon = (Image)_FindComponent("InfoPanel/Fields/CurrentVideo/InputField/PlayButton/IconPlay", typeof(Image));
            if (!Utilities.IsValid(lastVideoInput))
                lastVideoInput = (InputField)_FindComponent("InfoPanel/Fields/LastVideo/InputField", typeof(InputField));
            if (!Utilities.IsValid(lastVideoText))
                lastVideoText = (Text)_FindComponent("InfoPanel/Fields/LastVideo/InputField/TextMask/Text", typeof(Text));
            if (!Utilities.IsValid(playLastIcon))
                playLastIcon = (Image)_FindComponent("InfoPanel/Fields/LastVideo/InputField/PlayButton/IconPlay", typeof(Image));

        }

        GameObject _FindGameObject (string path)
        {
            if (Utilities.IsValid(videoPlayer) && Utilities.IsValid(videoPlayer.debugLog))
                videoPlayer.debugLog._Write("PlayerControls", $"Missing UI Game Object {path}");

            Transform t = transform.Find(path);
            if (!Utilities.IsValid(t))
                return null;

            return t.gameObject;
        }

        Component _FindComponent (string path, System.Type type)
        {
            if (Utilities.IsValid(videoPlayer) && Utilities.IsValid(videoPlayer.debugLog))
                videoPlayer.debugLog._Write("PlayerControls", $"Missing UI Component {path}:{type}");

            Transform t = transform.Find(path);
            if (!Utilities.IsValid(t))
                return null;

            return t.GetComponent(type);
        }
    }

#if UNITY_EDITOR && !COMPILER_UDONSHARP
    [CustomEditor(typeof(PlayerControls))]
    internal class PlayerControlsInspector : Editor
    {
        static bool _showObjectFoldout;

        SerializedProperty videoPlayerProperty;
        SerializedProperty volumeControllerProperty;
        SerializedProperty colorProfileProperty;

        SerializedProperty urlInputProperty;

        SerializedProperty volumeSliderControlProperty;
        SerializedProperty audio2DControlProperty;
        SerializedProperty urlInputControlProperty;
        SerializedProperty progressSliderControlProperty;
        SerializedProperty syncSliderControlProperty;

        SerializedProperty stopIconProperty;
        SerializedProperty pauseIconProperty;
        SerializedProperty lockedIconProperty;
        SerializedProperty unlockedIconProperty;
        SerializedProperty loadIconProperty;
        SerializedProperty resyncIconProperty;
        SerializedProperty repeatIconProperty;
        SerializedProperty shuffleIconProperty;
        SerializedProperty infoIconProperty;
        SerializedProperty playCurrentIconProperty;
        SerializedProperty playlastIconProperty;
        SerializedProperty nextIconProperty;
        SerializedProperty prevIconProperty;
        SerializedProperty playlistIconProperty;
        SerializedProperty masterIconProperty;
        SerializedProperty whitelistIconProperty;

        SerializedProperty muteToggleOnProperty;
        SerializedProperty muteToggleOffProperty;
        SerializedProperty audio2DToggleOnProperty;
        SerializedProperty audio2DToggleOffProperty;
        SerializedProperty volumeSliderProperty;

        SerializedProperty progressSliderProperty;
        SerializedProperty syncSliderProperty;
        SerializedProperty statusTextProperty;
        SerializedProperty urlTextProperty;
        SerializedProperty placeholderTextProperty;
        SerializedProperty modeTextProperty;
        SerializedProperty queuedTextProperty;

        SerializedProperty playlistTextProperty;

        SerializedProperty infoPanelProperty;
        SerializedProperty instanceOwnerTextProperty;
        SerializedProperty masterTextProperty;
        SerializedProperty playerOwnerTextProperty;
        SerializedProperty videoOwnerTextProperty;
        SerializedProperty currentVideoInputProperty;
        SerializedProperty lastVideoInputProperty;
        SerializedProperty currentVideoTextProperty;
        SerializedProperty lastVideoTextProperty;

        SerializedProperty playlistPanelProperty;

        string[] backgroundImagePaths = new string[] {
            "MainPanel/Background",
            "InfoPanel/Background"
        };
        string[] backgroundTitleImagePaths = new string[]
        {
            "InfoPanel/VersionInfo",
        };
        string[] sliderBgImagePaths = new string[] {
            "MainPanel/UpperRow/VolumeGroup/Background",
            "MainPanel/LowerRow/InputProgress/Background",
            "InfoPanel/Fields/CurrentVideo/InputField",
            "InfoPanel/Fields/LastVideo/InputField",
        };
        string[] volumeFillBgPaths = new string[] {
            "MainPanel/UpperRow/VolumeGroup/Slider/Fill Area/Fill",
        };
        string[] volumeHandleBgPaths = new string[] {
            "MainPanel/UpperRow/VolumeGroup/Slider/Handle Slide Area/Handle",
        };
        string[] trackerFillBgPaths = new string[] {
            "MainPanel/LowerRow/InputProgress/TrackingSlider/Fill Area/Fill",
            "MainPanel/LowerRow/InputProgress/SyncSlider/Fill Area/Fill",
        };
        string[] trackerHandleBgPaths = new string[] {
            "MainPanel/LowerRow/InputProgress/TrackingSlider/Handle Slide Area/Handle",
        };
        string[] buttonBgImagePaths = new string[] {
            "MainPanel/UpperRow/VolumeGroup/MuteButton",
            "MainPanel/UpperRow/SyncGroup/ResyncButton",
            "MainPanel/UpperRow/ControlGroup/PrevButton",
            "MainPanel/UpperRow/ControlGroup/PauseButton",
            "MainPanel/UpperRow/ControlGroup/StopButton",
            "MainPanel/UpperRow/ControlGroup/NextButton",
            "MainPanel/UpperRow/ButtonGroup/RepeatButton",
            "MainPanel/UpperRow/ButtonGroup/PlaylistButton",
            "MainPanel/UpperRow/ButtonGroup/InfoButton",
            "MainPanel/LowerRow/InputProgress/LoadButton",
            "MainPanel/LowerRow/InputProgress/MasterLockButton",
            "InfoPanel/Fields/CurrentVideo/InputField/PlayButton",
            "InfoPanel/Fields/LastVideo/InputField/PlayButton",
        };
        string[] buttonIconImagePaths = new string[]
        {
            "MainPanel/UpperRow/VolumeGroup/MuteButton/IconMuted",
            "MainPanel/UpperRow/VolumeGroup/MuteButton/IconVolume",
            "MainPanel/UpperRow/SyncGroup/ResyncButton/IconResync",
            "MainPanel/UpperRow/ControlGroup/PrevButton/IconPrev",
            "MainPanel/UpperRow/ControlGroup/PauseButton/IconPause",
            "MainPanel/UpperRow/ControlGroup/StopButton/IconStop",
            "MainPanel/UpperRow/ControlGroup/NextButton/IconNext",
            "MainPanel/UpperRow/ButtonGroup/RepeatButton/IconRepeat",
            "MainPanel/UpperRow/ButtonGroup/PlaylistButton/IconPlaylist",
            "MainPanel/UpperRow/ButtonGroup/InfoButton/IconInfo",
            "MainPanel/LowerRow/InputProgress/LoadButton/IconLoad",
            "MainPanel/LowerRow/InputProgress/MasterLockButton/IconLocked",
            "MainPanel/LowerRow/InputProgress/MasterLockButton/IconUnlocked",
            "InfoPanel/Fields/CurrentVideo/InputField/PlayButton/IconPlay",
            "InfoPanel/Fields/LastVideo/InputField/PlayButton/IconPlay",
        };
        string[] generalTextPaths = new string[]
        {
            "InfoPanel/VersionInfo/Text",
            "InfoPanel/Fields/InstanceOwner",
            "InfoPanel/Fields/InstanceOwner/InstanceOwnerName",
            "InfoPanel/Fields/Master",
            "InfoPanel/Fields/Master/MasterName",
            "InfoPanel/Fields/PlayerOwner",
            "InfoPanel/Fields/PlayerOwner/PlayerOwnerName",
            "InfoPanel/Fields/VideoOwner",
            "InfoPanel/Fields/VideoOwner/VideoOwnerName",
            "InfoPanel/Fields/CurrentVideo",
            "InfoPanel/Fields/LastVideo",
        };
        string[] mainTextPaths = new string[]
        {
            "MainPanel/LowerRow/InputProgress/StatusText",
            "MainPanel/LowerRow/InputProgress/InputField/TextMask/Text",
            "MainPanel/LowerRow/InputProgress/InputField/TextMask/Placeholder",
            "InfoPanel/Fields/CurrentVideo/InputField/TextMask/Text",
            "InfoPanel/Fields/CurrentVideo/InputField/TextMask/Placeholder",
            "InfoPanel/Fields/LastVideo/InputField/TextMask/Text",
            "InfoPanel/Fields/LastVideo/InputField/TextMask/Placeholder",
        };
        string[] subTextPaths = new string[]
        {
            "MainPanel/LowerRow/InputProgress/QueuedText",
            "MainPanel/LowerRow/InputProgress/PlaylistText",
            "MainPanel/LowerRow/InputProgress/SourceMode",
        };
        string[] subTextIconPaths = new string[]
        {
            "MainPanel/LowerRow/InputProgress/PlayerAccess/IconMaster",
            "MainPanel/LowerRow/InputProgress/PlayerAccess/IconWhitelist",
        };

        private void OnEnable()
        {
            videoPlayerProperty = serializedObject.FindProperty(nameof(PlayerControls.videoPlayer));
            volumeControllerProperty = serializedObject.FindProperty(nameof(PlayerControls.audioManager));
            colorProfileProperty = serializedObject.FindProperty(nameof(PlayerControls.colorProfile));

            urlInputProperty = serializedObject.FindProperty(nameof(PlayerControls.urlInput));

            volumeSliderControlProperty = serializedObject.FindProperty(nameof(PlayerControls.volumeSliderControl));
            audio2DControlProperty = serializedObject.FindProperty(nameof(PlayerControls.audio2DControl));
            progressSliderControlProperty = serializedObject.FindProperty(nameof(PlayerControls.progressSliderControl));
            syncSliderControlProperty = serializedObject.FindProperty(nameof(PlayerControls.syncSliderControl));
            urlInputControlProperty = serializedObject.FindProperty(nameof(PlayerControls.urlInputControl));

            stopIconProperty = serializedObject.FindProperty(nameof(PlayerControls.stopIcon));
            pauseIconProperty = serializedObject.FindProperty(nameof(PlayerControls.pauseIcon));
            lockedIconProperty = serializedObject.FindProperty(nameof(PlayerControls.lockedIcon));
            unlockedIconProperty = serializedObject.FindProperty(nameof(PlayerControls.unlockedIcon));
            loadIconProperty = serializedObject.FindProperty(nameof(PlayerControls.loadIcon));
            resyncIconProperty = serializedObject.FindProperty(nameof(PlayerControls.resyncIcon));
            repeatIconProperty = serializedObject.FindProperty(nameof(PlayerControls.repeatIcon));
            shuffleIconProperty = serializedObject.FindProperty(nameof(PlayerControls.shuffleIcon));
            infoIconProperty = serializedObject.FindProperty(nameof(PlayerControls.infoIcon));
            playCurrentIconProperty = serializedObject.FindProperty(nameof(PlayerControls.playCurrentIcon));
            playlastIconProperty = serializedObject.FindProperty(nameof(PlayerControls.playLastIcon));
            nextIconProperty = serializedObject.FindProperty(nameof(PlayerControls.nextIcon));
            prevIconProperty = serializedObject.FindProperty(nameof(PlayerControls.prevIcon));
            playlistIconProperty = serializedObject.FindProperty(nameof(PlayerControls.playlistIcon));
            masterIconProperty = serializedObject.FindProperty(nameof(PlayerControls.masterIcon));
            whitelistIconProperty = serializedObject.FindProperty(nameof(PlayerControls.whitelistIcon));

            muteToggleOnProperty = serializedObject.FindProperty(nameof(PlayerControls.muteToggleOn));
            muteToggleOffProperty = serializedObject.FindProperty(nameof(PlayerControls.muteToggleOff));
            audio2DToggleOnProperty = serializedObject.FindProperty(nameof(PlayerControls.audio2DToggleOn));
            audio2DToggleOffProperty = serializedObject.FindProperty(nameof(PlayerControls.audio2DToggleOff));
            volumeSliderProperty = serializedObject.FindProperty(nameof(PlayerControls.volumeSlider));

            statusTextProperty = serializedObject.FindProperty(nameof(PlayerControls.statusText));
            placeholderTextProperty = serializedObject.FindProperty(nameof(PlayerControls.placeholderText));
            urlTextProperty = serializedObject.FindProperty(nameof(PlayerControls.urlText));
            progressSliderProperty = serializedObject.FindProperty(nameof(PlayerControls.progressSlider));
            syncSliderProperty = serializedObject.FindProperty(nameof(PlayerControls.syncSlider));
            modeTextProperty = serializedObject.FindProperty(nameof(PlayerControls.modeText));
            queuedTextProperty = serializedObject.FindProperty(nameof(PlayerControls.queuedText));

            playlistTextProperty = serializedObject.FindProperty(nameof(PlayerControls.playlistText));

            infoPanelProperty = serializedObject.FindProperty(nameof(PlayerControls.infoPanel));
            instanceOwnerTextProperty = serializedObject.FindProperty(nameof(PlayerControls.instanceOwnerText));
            masterTextProperty = serializedObject.FindProperty(nameof(PlayerControls.masterText));
            playerOwnerTextProperty = serializedObject.FindProperty(nameof(PlayerControls.playerOwnerText));
            videoOwnerTextProperty = serializedObject.FindProperty(nameof(PlayerControls.videoOwnerText));
            currentVideoInputProperty = serializedObject.FindProperty(nameof(PlayerControls.currentVideoInput));
            lastVideoInputProperty = serializedObject.FindProperty(nameof(PlayerControls.lastVideoInput));
            currentVideoTextProperty = serializedObject.FindProperty(nameof(PlayerControls.currentVideoText));
            lastVideoTextProperty = serializedObject.FindProperty(nameof(PlayerControls.lastVideoText));

            playlistPanelProperty = serializedObject.FindProperty(nameof(PlayerControls.playlistPanel));
        }

        public override void OnInspectorGUI()
        {
            if (UdonSharpGUI.DrawDefaultUdonSharpBehaviourHeader(target))
                return;

            EditorGUILayout.PropertyField(videoPlayerProperty);
            EditorGUILayout.PropertyField(volumeControllerProperty);
            EditorGUILayout.Space();
            EditorGUILayout.PropertyField(colorProfileProperty);
            if (GUILayout.Button("Apply Color Profile"))
                UpdateColors();

            EditorGUILayout.Space();

            _showObjectFoldout = EditorGUILayout.Foldout(_showObjectFoldout, "Internal Object References");
            if (_showObjectFoldout)
            {
                EditorGUI.indentLevel++;
                EditorGUILayout.Space();
                EditorGUILayout.PropertyField(urlInputProperty);
                EditorGUILayout.PropertyField(volumeSliderControlProperty);
                EditorGUILayout.PropertyField(audio2DControlProperty);
                EditorGUILayout.PropertyField(urlInputControlProperty);
                EditorGUILayout.PropertyField(progressSliderControlProperty);
                EditorGUILayout.PropertyField(syncSliderControlProperty);
                EditorGUILayout.PropertyField(stopIconProperty);
                EditorGUILayout.PropertyField(pauseIconProperty);
                EditorGUILayout.PropertyField(lockedIconProperty);
                EditorGUILayout.PropertyField(unlockedIconProperty);
                EditorGUILayout.PropertyField(loadIconProperty);
                EditorGUILayout.PropertyField(resyncIconProperty);
                EditorGUILayout.PropertyField(repeatIconProperty);
                EditorGUILayout.PropertyField(shuffleIconProperty);
                EditorGUILayout.PropertyField(infoIconProperty);
                EditorGUILayout.PropertyField(playCurrentIconProperty);
                EditorGUILayout.PropertyField(playlastIconProperty);
                EditorGUILayout.PropertyField(nextIconProperty);
                EditorGUILayout.PropertyField(prevIconProperty);
                EditorGUILayout.PropertyField(playlistIconProperty);
                EditorGUILayout.PropertyField(masterIconProperty);
                EditorGUILayout.PropertyField(whitelistIconProperty);
                EditorGUILayout.PropertyField(muteToggleOnProperty);
                EditorGUILayout.PropertyField(muteToggleOffProperty);
                EditorGUILayout.PropertyField(audio2DToggleOnProperty);
                EditorGUILayout.PropertyField(audio2DToggleOffProperty);
                EditorGUILayout.PropertyField(volumeSliderProperty);
                EditorGUILayout.PropertyField(progressSliderProperty);
                EditorGUILayout.PropertyField(syncSliderProperty);
                EditorGUILayout.PropertyField(statusTextProperty);
                EditorGUILayout.PropertyField(urlTextProperty);
                EditorGUILayout.PropertyField(placeholderTextProperty);
                EditorGUILayout.PropertyField(modeTextProperty);
                EditorGUILayout.PropertyField(queuedTextProperty);
                EditorGUILayout.PropertyField(playlistTextProperty);
                EditorGUILayout.PropertyField(infoPanelProperty);
                EditorGUILayout.PropertyField(instanceOwnerTextProperty);
                EditorGUILayout.PropertyField(masterTextProperty);
                EditorGUILayout.PropertyField(playerOwnerTextProperty);
                EditorGUILayout.PropertyField(videoOwnerTextProperty);
                EditorGUILayout.PropertyField(currentVideoInputProperty);
                EditorGUILayout.PropertyField(lastVideoInputProperty);
                EditorGUILayout.PropertyField(currentVideoTextProperty);
                EditorGUILayout.PropertyField(lastVideoTextProperty);
                EditorGUILayout.PropertyField(playlistPanelProperty);
                EditorGUI.indentLevel--;
            }
            EditorGUILayout.Space();

            if (serializedObject.hasModifiedProperties)
                serializedObject.ApplyModifiedProperties();
        }

        void UpdateColors()
        {
            PlayerControls pc = (PlayerControls)serializedObject.targetObject;
            if (pc == null)
            {
                Debug.LogWarning("Could not find gameobject");
                return;
            }

            if (pc.colorProfile == null)
            {
                Debug.LogWarning("No control color profile set");
                return;
            }

            GameObject root = pc.gameObject;

            List<Object> pendingUpdate = new List<Object>();
            CollectObjects<Image>(pendingUpdate, root, backgroundImagePaths);
            CollectObjects<Image>(pendingUpdate, root, backgroundTitleImagePaths);
            CollectObjects<Image>(pendingUpdate, root, buttonBgImagePaths);
            CollectObjects<Image>(pendingUpdate, root, sliderBgImagePaths);
            CollectObjects<Image>(pendingUpdate, root, volumeFillBgPaths);
            CollectObjects<Image>(pendingUpdate, root, volumeHandleBgPaths);
            CollectObjects<Image>(pendingUpdate, root, trackerFillBgPaths);
            CollectObjects<Image>(pendingUpdate, root, trackerHandleBgPaths);
            CollectObjects<Image>(pendingUpdate, root, buttonIconImagePaths);
            CollectObjects<Image>(pendingUpdate, root, subTextIconPaths);
            CollectObjects<Text>(pendingUpdate, root, generalTextPaths);
            CollectObjects<Text>(pendingUpdate, root, mainTextPaths);
            CollectObjects<Text>(pendingUpdate, root, subTextPaths);

            Undo.RecordObjects(pendingUpdate.ToArray(), "Update colors");

            ControlColorProfile colorProfile = pc.colorProfile;

            UpdateImages(root, backgroundImagePaths, colorProfile.backgroundColor);
            UpdateImages(root, backgroundTitleImagePaths, colorProfile.backgroundTitleColor);
            UpdateImages(root, buttonBgImagePaths, colorProfile.buttonBackgroundColor);
            UpdateImages(root, sliderBgImagePaths, colorProfile.sliderBackgroundColor);
            UpdateImages(root, volumeFillBgPaths, colorProfile.volumeFillColor);
            UpdateImages(root, volumeHandleBgPaths, colorProfile.volumeHandleColor);
            UpdateImages(root, trackerFillBgPaths, colorProfile.trackerFillColor);
            UpdateImages(root, trackerHandleBgPaths, colorProfile.trackerHandleColor);
            UpdateImages(root, buttonIconImagePaths, colorProfile.normalColor);
            UpdateImages(root, subTextIconPaths, colorProfile.subTextColor);
            UpdateTexts(root, generalTextPaths, colorProfile.generalTextColor);
            UpdateTexts(root, mainTextPaths, colorProfile.mainTextColor);
            UpdateTexts(root, subTextPaths, colorProfile.subTextColor);

            foreach (Object obj in pendingUpdate)
                PrefabUtility.RecordPrefabInstancePropertyModifications(obj);
        }

        void CollectObjects<T> (List<Object> list, GameObject root, string[] paths) where T : Object
        {
            foreach (string path in paths)
            {
                Transform t = root.transform.Find(path);
                if (t == null)
                    continue;

                T component = t.GetComponent<T>();
                if (component == null)
                    continue;

                list.Add(component);
            }
        }

        void UpdateImages(GameObject root, string[] paths, Color color)
        {
            foreach (string path in paths)
            {
                Transform t = root.transform.Find(path);
                if (t == null)
                    continue;

                Image image = t.GetComponent<Image>();
                if (image == null)
                    continue;

                image.color = color;
            }
        }

        void UpdateTexts(GameObject root, string[] paths, Color color)
        {
            foreach (string path in paths)
            {
                Transform t = root.transform.Find(path);
                if (t == null)
                    continue;

                Text text = t.GetComponent<Text>();
                if (text == null)
                    continue;

                text.color = color;
            }
        }
    }
#endif
}
