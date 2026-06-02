import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ncktv.gui
import QtQuick.Dialogs
import QtMultimedia



ApplicationWindow {
    id: rootWindow
    visible: true
    visibility: Window.Maximized
    width: 1280
    height: 800
    title: "NC-KTV V2 - Premium Karaoke Maker & NLE"

    // Modern Deep Pitch-Black / Charcoal Visual styling variables
    property color colorBgPitch: "#08080A"
    property color colorBgPanel: "#111115"
    property color colorBgCard: "#1B1B22"
    property color colorBorder: "#2A2A35"
    property color colorBorderHighlight: "#4A4A5A"
    property color colorAccentViolet: "#7C4DFF"
    property color colorAccentGreen: "#00E676"
    property color colorTextPrimary: "#F0F0F5"
    property color colorTextSecondary: "#8A8A9E"
    property color colorGlassGlow: "#1F1A30"

    // Active project path tracking
    property string currentProjectPath: ""
    property bool closeRequested: false
    property string pendingAction: ""
    property real timelineTopY: 0

    // Optimized preview rendering cache properties
    property var cachedActiveClip: null
    property var cachedNextClip: null
    property var cachedUpcomingClips: []
    property var cachedActiveVideoClip: null
    property int cachedLyricClipsCount: -1
    property int cachedVideoClipsCount: -1
    property real lastPlayheadTime: -1

    // Source Monitor properties
    property string sourceMonitorFilePath: ""
    property string sourceMonitorFileName: ""
    property string sourceMonitorFileType: ""
    property double sourceMonitorDurationMs: 0
    property double sourceMonitorPlayheadMs: 0
    property double sourceMonitorInPointMs: 0
    property double sourceMonitorOutPointMs: 0
    property bool sourceMonitorIsPlaying: false

    function loadIntoSourceMonitor(path, type, name) {
        sourceMonitorFilePath = path;
        sourceMonitorFileName = name ? name : "";
        sourceMonitorFileType = type ? type : "";
        sourceMonitorPlayheadMs = 0;
        sourceMonitorInPointMs = 0;
        sourceMonitorOutPointMs = 0;
        sourceMonitorIsPlaying = false;
        
        // Load into source player
        sourcePlayer.stop();
        if (path !== "") {
            var resolvedUrl = path;
            if (path.indexOf(":/") === -1 && path.indexOf("qrc:/") === -1 && !path.startsWith("file:///")) {
                resolvedUrl = "file:///" + encodeURI(path);
            }
            sourcePlayer.source = resolvedUrl;
            sourcePlayer.play();
            // Pause immediately after loading to let it buffer and display the first frame
            sourcePlayer.pause();
        }
    }

    property string playbackState: "Stopped"
    property real shuttleSpeed: 0.0

    function startIntroSplash() {
        if (playbackState === "PlayingIntro") {
            bypassIntroSplash();
            return;
        }
        playbackState = "PlayingIntro";
        introSplashScreen.startIntro();
    }

    function bypassIntroSplash() {
        if (playbackState !== "PlayingIntro") return;
        console.log("[INTRO SPLASH] Intro animation bypassed by user. Starting audio playback immediately.");
        introSplashScreen.introAnimationSequence.stop();
        introSplashScreen.opacity = 0.0;
        playbackState = "PlayingAudio";
        audioEngine.play();
    }

    function cancelIntroSplash() {
        console.log("[INTRO SPLASH] Intro animation cancelled by user.");
        introSplashScreen.introAnimationSequence.stop();
        introSplashScreen.opacity = 0.0;
        playbackState = "Stopped";
        audioEngine.stop();
    }

    function startEndingVideoSplash() {
        playbackState = "PlayingOutro";
        var resolvedPath = timelineManager.resolveEndingVideoPath();
        if (resolvedPath === "") {
            console.log("[ENDING VIDEO] Warning: Predefined ending splash screen video is unavailable. Skipping gracefully.");
            stopEndingVideoSplash();
            return;
        }

        console.log("[ENDING VIDEO] Triggered ending splash. Resolved video path: " + resolvedPath);

        // Stop active preview video playback
        videoPlayer.stop();

        var resolvedUrl = resolvedPath;
        if (resolvedPath.indexOf(":/") === -1 && resolvedPath.indexOf("qrc:/") === -1 && !resolvedPath.startsWith("file:///")) {
            resolvedUrl = "file:///" + encodeURI(resolvedPath);
        }

        endingVideoPlayer.source = resolvedUrl;
        endingVideoOverlay.visible = true;
        endingVideoPlayer.play();
    }

    function stopEndingVideoSplash() {
        console.log("[ENDING VIDEO] Ending video splash completed or failed. Returning control back to application.");
        endingVideoPlayer.stop();
        endingVideoOverlay.visible = false;
        playbackState = "Stopped";
        returnToNormalPlayerState();
    }

    function returnToNormalPlayerState() {
        timelineManager.currentPlayheadTime = 0;
        updateCachedClips();
    }

    function updateCachedClips() {
        var time = timelineManager.currentPlayheadTime;
        
        // Find lyric track and video track
        var lyricTrack = null;
        var videoTrack = null;
        for (var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
            var t = timelineManager.trackListModel.tracks()[i];
            if (t) {
                if (t.trackType === 2) {
                    lyricTrack = t;
                } else if (t.trackType === 1) {
                    videoTrack = t;
                }
            }
        }
        
        var currentLyricCount = lyricTrack ? lyricTrack.clips().length : 0;
        var currentVideoCount = videoTrack ? videoTrack.clips().length : 0;
        
        var cacheValid = (lastPlayheadTime !== -1 && 
                          currentLyricCount === cachedLyricClipsCount && 
                          currentVideoCount === cachedVideoClipsCount);
                          
        if (cacheValid) {
            // Check active lyric clip boundaries
            var lyricValid = false;
            if (cachedActiveClip) {
                if (time >= cachedActiveClip.startTime && time < cachedActiveClip.endTime) {
                    lyricValid = true;
                }
            } else {
                if (cachedNextClip) {
                    if (time >= lastPlayheadTime && time < cachedNextClip.startTime) {
                        lyricValid = true;
                    }
                } else {
                    lyricValid = true; // No more clips ahead
                }
            }
            
            // Check active video clip boundaries
            var videoValid = false;
            if (cachedActiveVideoClip) {
                if (time >= cachedActiveVideoClip.startTime && time < cachedActiveVideoClip.endTime) {
                    videoValid = true;
                }
            } else {
                // If there's a video track, make sure we aren't inside any clip
                var hasClipNow = false;
                if (videoTrack) {
                    var vClips = videoTrack.clips();
                    for (var vc = 0; vc < vClips.length; ++vc) {
                        if (time >= vClips[vc].startTime && time < vClips[vc].endTime) {
                            hasClipNow = true;
                            break;
                        }
                    }
                }
                if (!hasClipNow) {
                    videoValid = true;
                }
            }
            
            if (lyricValid && videoValid) {
                lastPlayheadTime = time;
                return; // O(1) Fast-Path Hit!
            }
        }
        
        lastPlayheadTime = time;
        cachedLyricClipsCount = currentLyricCount;
        cachedVideoClipsCount = currentVideoCount;
        
        // 1. Recalculate Lyric Clips
        var activeLyric = null;
        var upcomingLyric = [];
        var nextLyric = null;
        
        if (lyricTrack) {
            var lClips = lyricTrack.clips();
            for (var c = 0; c < lClips.length; ++c) {
                var clip = lClips[c];
                if (time >= clip.startTime && time < clip.endTime) {
                    activeLyric = clip;
                } else if (clip.startTime > time) {
                    upcomingLyric.push(clip);
                }
            }
        }
        
        upcomingLyric.sort(function(a, b) { return a.startTime - b.startTime; });
        if (upcomingLyric.length > 0) {
            nextLyric = upcomingLyric[0];
        }
        
        if (cachedActiveClip !== activeLyric) {
            cachedActiveClip = activeLyric;
        }
        if (cachedNextClip !== nextLyric) {
            cachedNextClip = nextLyric;
        }
        
        var changed = false;
        if (cachedUpcomingClips.length !== upcomingLyric.length) {
            changed = true;
        } else {
            for (var k = 0; k < upcomingLyric.length; ++k) {
                if (cachedUpcomingClips[k] !== upcomingLyric[k]) {
                    changed = true;
                    break;
                }
            }
        }
        if (changed) {
            cachedUpcomingClips = upcomingLyric;
        }
        
        // 2. Recalculate Video Clip
        var activeVideo = null;
        if (videoTrack) {
            var vClips2 = videoTrack.clips();
            for (var vc2 = 0; vc2 < vClips2.length; ++vc2) {
                var vClip = vClips2[vc2];
                if (time >= vClip.startTime && time < vClip.endTime) {
                    activeVideo = vClip;
                    break;
                }
            }
        }
        
        if (cachedActiveVideoClip !== activeVideo) {
            cachedActiveVideoClip = activeVideo;
        }
    }

    function insertSourceClipToTimeline() {
        if (sourceMonitorFilePath === "") return;
        
        var typeStr = sourceMonitorFileType; // "Audio" or "Video"
        var typeInt = (typeStr === "Video") ? 1 : 0;
        var track = propertiesPanel.selectedTrack;
        
        if (!track || track.trackType !== typeInt) {
            track = null;
            for (var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                var t = timelineManager.trackListModel.tracks()[i];
                if (t.trackType === typeInt && !t.isLocked) {
                    track = t;
                    break;
                }
            }
            if (!track) {
                var newTrackId = timelineManager.addTrack(typeInt, typeStr + " Track " + (timelineManager.trackListModel.rowCount() + 1));
                for (var j = 0; j < timelineManager.trackListModel.rowCount(); ++j) {
                    var nt = timelineManager.trackListModel.tracks()[j];
                    if (nt.trackId === newTrackId) {
                        track = nt;
                        break;
                    }
                }
            }
        }
        
        if (track) {
            var clipCount = track.clips().length;
            var clipId = "clip_" + (clipCount + 1);
            var startUs = timelineManager.currentPlayheadTime;
            
            var trimMs = sourceMonitorOutPointMs - sourceMonitorInPointMs;
            if (trimMs <= 0) {
                trimMs = sourceMonitorDurationMs - sourceMonitorInPointMs;
            }
            if (trimMs <= 0) {
                trimMs = 5000;
            }
            var durUs = trimMs * 1000;
            var sourceStartUs = sourceMonitorInPointMs * 1000;
            
            var added = timelineManager.addClipToTrackWithSourceStart(
                track.trackId,
                clipId,
                track.trackType,
                startUs,
                durUs,
                sourceStartUs,
                sourceMonitorFilePath
            );
            
            if (added) {
                propertiesPanel.selectedTrack = track;
                var clips = track.clips();
                for (var c = 0; c < clips.length; ++c) {
                    if (clips[c].clipId === clipId) {
                        propertiesPanel.selectedClip = clips[c];
                        break;
                    }
                }
                console.log("[SOURCE MONITOR] Successfully inserted trimmed clip to timeline");
            }
        }
    }

    onClosing: (close) => {
        if (timelineManager.isDirty) {
            close.accepted = false;
            closeRequested = true;
            pendingAction = "Close";
            unsavedChangesDialog.open();
        }
    }

    property var activeVideoClip: cachedActiveVideoClip

    onActiveVideoClipChanged: {
        console.log("[VIDEO PREVIEW] Active video clip changed: " + (activeVideoClip ? activeVideoClip.clipId : "None") + ", source: " + (activeVideoClip ? activeVideoClip.sourceFile : "None"));
        if (activeVideoClip) {
            var seekPosMs = (timelineManager.currentPlayheadTime - activeVideoClip.startTime + activeVideoClip.sourceStart) / 1000;
            videoPlayer.position = Math.max(0, seekPosMs);
            if (audioEngine.isPlaying) {
                videoPlayer.play();
            } else {
                videoPlayer.pause();
            }
        } else {
            videoPlayer.stop();
        }
    }

    MediaPlayer {
        id: videoPlayer
        audioOutput: AudioOutput {
            muted: true // Muted because C++ AudioEngine plays the mixed audio stream
        }
        videoOutput: videoOutput
        
        source: {
            if (rootWindow.activeVideoClip && rootWindow.activeVideoClip.sourceFile !== "") {
                var path = rootWindow.activeVideoClip.sourceFile;
                if (path.indexOf(":/") !== -1 || path.indexOf("qrc:/") !== -1) {
                    return path;
                }
                if (path.startsWith("file:///")) {
                    return path;
                }
                // Use encodeURI to safely format spaces, quotes, and unicode characters for QUrl
                var resolvedUrl = "file:///" + encodeURI(path);
                console.log("[VIDEO PREVIEW] Loading media source URL: " + resolvedUrl);
                return resolvedUrl;
            }
            return "";
        }
        
        onMediaStatusChanged: {
            console.log("[VIDEO PREVIEW] Media status changed: " + mediaStatus + " (NoMedia=0, Loading=1, Loaded=2, EndOfMedia=6, Invalid=8)");
            if (mediaStatus === MediaPlayer.LoadedMedia) {
                if (rootWindow.activeVideoClip) {
                    var seekPosMs = (timelineManager.currentPlayheadTime - rootWindow.activeVideoClip.startTime) / 1000;
                    position = Math.max(0, seekPosMs);
                }
            }
        }

        onErrorChanged: {
            if (error !== MediaPlayer.NoError) {
                console.log("[VIDEO PREVIEW] MediaPlayer Error (" + error + "): " + errorString);
                playbackErrorDialog.errorMsg = errorString;
                playbackErrorDialog.open();
            }
        }
    }

    MediaPlayer {
        id: sourcePlayer
        audioOutput: AudioOutput {
            volume: masterVolSlider ? masterVolSlider.value : 1.0
        }
        
        onMediaStatusChanged: {
            console.log("[SOURCE MONITOR] Media status changed: " + mediaStatus + " (NoMedia=0, Loaded=2)");
            if (mediaStatus === MediaPlayer.LoadedMedia) {
                rootWindow.sourceMonitorDurationMs = duration;
                rootWindow.sourceMonitorOutPointMs = duration;
            }
        }
        
        onPositionChanged: {
            if (rootWindow.sourceMonitorDurationMs > 0) {
                rootWindow.sourceMonitorPlayheadMs = position;
            }
        }
        
        onErrorChanged: {
            if (error !== MediaPlayer.NoError) {
                console.log("[SOURCE MONITOR] MediaPlayer Error (" + error + "): " + errorString);
                playbackErrorDialog.errorMsg = errorString;
                playbackErrorDialog.open();
            }
        }
    }

    MediaPlayer {
        id: endingVideoPlayer
        audioOutput: AudioOutput {
            volume: masterVolSlider ? masterVolSlider.value : 1.0
        }
        videoOutput: endingVideoOutput
        
        onMediaStatusChanged: {
            console.log("[ENDING VIDEO] Media status: " + mediaStatus + " (NoMedia=0, Loaded=2, EndOfMedia=6, Invalid=8)");
            if (mediaStatus === MediaPlayer.EndOfMedia) {
                rootWindow.stopEndingVideoSplash();
            }
        }
        
        onErrorChanged: {
            if (error !== MediaPlayer.NoError) {
                console.log("[ENDING VIDEO] MediaPlayer Error (" + error + "): " + errorString);
                rootWindow.stopEndingVideoSplash();
                playbackErrorDialog.errorMsg = errorString;
                playbackErrorDialog.open();
            }
        }
    }

    Timer {
        id: scrubSeekTimer
        interval: 50 // Throttle seeks to at most 20 per second
        repeat: false
        running: false
        property real pendingPositionMs: 0
        onTriggered: {
            videoPlayer.position = pendingPositionMs;
        }
    }

    Timer {
        id: lyricsPreviewTimer
        interval: 16 // ~60 fps smooth advancement
        repeat: true
        running: false
        property double lastTimeMs: 0
        
        onTriggered: {
            var now = Date.now();
            var dtMs = now - lastTimeMs;
            lastTimeMs = now;
            
            var newTimeUs = timelineManager.currentPlayheadTime + (dtMs * 1000);
            if (timelineManager.totalDuration > 0 && newTimeUs >= timelineManager.totalDuration) {
                newTimeUs = 0;
                running = false;
                console.log("[LYRICS PREVIEW] Preview completed, stopping simulation.");
                return;
            }
            timelineManager.currentPlayheadTime = newTimeUs;
        }
        
        onRunningChanged: {
            if (running) {
                lastTimeMs = Date.now();
                if (rootWindow.activeVideoClip) {
                    var seekPosMs = (timelineManager.currentPlayheadTime - rootWindow.activeVideoClip.startTime + rootWindow.activeVideoClip.sourceStart) / 1000;
                    videoPlayer.position = Math.max(0, seekPosMs);
                    videoPlayer.play();
                }
            } else {
                videoPlayer.pause();
                if (rootWindow.activeVideoClip) {
                    var seekPosMs = (timelineManager.currentPlayheadTime - rootWindow.activeVideoClip.startTime + rootWindow.activeVideoClip.sourceStart) / 1000;
                    videoPlayer.position = Math.max(0, seekPosMs);
                }
            }
        }
    }

    Timer {
        id: shuttleTimer
        interval: 16
        repeat: true
        running: false
        property double lastTimeMs: 0
        
        onTriggered: {
            var now = Date.now();
            var dtMs = now - lastTimeMs;
            lastTimeMs = now;
            
            if (shuttleSpeed === 0.0) {
                running = false;
                return;
            }
            
            var deltaUs = dtMs * 1000 * shuttleSpeed;
            var newTimeUs = timelineManager.currentPlayheadTime + deltaUs;
            
            if (newTimeUs < 0) {
                newTimeUs = 0;
                shuttleSpeed = 0.0;
                running = false;
                console.log("[SHUTTLE] Reached start of timeline.");
            } else if (timelineManager.totalDuration > 0 && newTimeUs >= timelineManager.totalDuration) {
                newTimeUs = timelineManager.totalDuration;
                shuttleSpeed = 0.0;
                running = false;
                console.log("[SHUTTLE] Reached end of timeline.");
            }
            
            timelineManager.currentPlayheadTime = newTimeUs;
        }
        
        onRunningChanged: {
            if (running) {
                lastTimeMs = Date.now();
            }
        }
    }

    Connections {
        target: audioEngine
        function onIsPlayingChanged() {
            if (audioEngine.isPlaying) {
                rootWindow.shuttleSpeed = 1.0;
                shuttleTimer.running = false;
                if (rootWindow.playbackState !== "PlayingIntro" && rootWindow.playbackState !== "PlayingOutro") {
                    rootWindow.playbackState = "PlayingAudio";
                }
                lyricsPreviewTimer.running = false;
                if (rootWindow.activeVideoClip) {
                    var seekPosMs = (timelineManager.currentPlayheadTime - rootWindow.activeVideoClip.startTime + rootWindow.activeVideoClip.sourceStart) / 1000;
                    videoPlayer.position = Math.max(0, seekPosMs);
                }
                videoPlayer.play();
            } else {
                if (rootWindow.shuttleSpeed > 0 && rootWindow.shuttleSpeed <= 1.0) {
                    rootWindow.shuttleSpeed = 0.0;
                }
                videoPlayer.pause();
                if (rootWindow.activeVideoClip) {
                    var seekPosMs = (timelineManager.currentPlayheadTime - rootWindow.activeVideoClip.startTime + rootWindow.activeVideoClip.sourceStart) / 1000;
                    videoPlayer.position = Math.max(0, seekPosMs);
                }
                if (rootWindow.playbackState !== "PlayingIntro" && rootWindow.playbackState !== "PlayingOutro") {
                    if (timelineManager.currentPlayheadTime === 0) {
                        rootWindow.playbackState = "Stopped";
                    } else {
                        rootWindow.playbackState = "Paused";
                    }
                }
            }
        }
    }

    Connections {
        target: timelineManager
        
        function onCurrentPlayheadTimeChanged() {
            rootWindow.updateCachedClips();
            
            if (!audioEngine.isPlaying && timelineManager.currentPlayheadTime === 0) {
                if (rootWindow.playbackState !== "PlayingIntro" && rootWindow.playbackState !== "PlayingOutro") {
                    rootWindow.playbackState = "Stopped";
                }
            }
            
            // Check if active song reaches the end
            if (audioEngine.isPlaying && timelineManager.totalDuration > 0 && timelineManager.currentPlayheadTime >= timelineManager.totalDuration) {
                console.log("[PLAYBACK] Song reached the end. Stopping playback and triggering ending splash screen.");
                audioEngine.stop();
                rootWindow.startEndingVideoSplash();
                return;
            }
            
            if (rootWindow.activeVideoClip) {
                var seekPosMs = (timelineManager.currentPlayheadTime - rootWindow.activeVideoClip.startTime + rootWindow.activeVideoClip.sourceStart) / 1000;
                if (audioEngine.isPlaying || lyricsPreviewTimer.running) {
                    // Seek video player only when there is a significant jump or drift (e.g. > 1000 ms)
                    if (Math.abs(videoPlayer.position - seekPosMs) > 1000.0) {
                        videoPlayer.position = Math.max(0, seekPosMs);
                    }
                } else {
                    scrubSeekTimer.pendingPositionMs = Math.max(0, seekPosMs);
                    if (!scrubSeekTimer.running) {
                        videoPlayer.position = scrubSeekTimer.pendingPositionMs;
                        scrubSeekTimer.start();
                    }
                }
            }
        }

        function onProjectLoaded() {
            rootWindow.lastPlayheadTime = -1;
            rootWindow.updateCachedClips();
        }

        function onProjectCleared() {
            rootWindow.lastPlayheadTime = -1;
            rootWindow.updateCachedClips();
        }

        function onTimelineChanged() {
            rootWindow.lastPlayheadTime = -1;
            rootWindow.updateCachedClips();
        }
    }

    function executePendingAction() {
        console.log("[PROJECT ACTION] Executing pending project action: " + pendingAction);
        if (pendingAction === "New") {
            timelineManager.clearProject();
            currentProjectPath = "";
            propertiesPanel.selectedTrack = null;
            propertiesPanel.selectedClip = null;
            saveStatusText.text = "New Project Started";
            saveTextAnim.start();
        } else if (pendingAction === "Open") {
            openFileDialog.open();
        } else if (pendingAction === "Close") {
            Qt.quit();
        }
        pendingAction = "";
    }



    // Helper function to register media files in the Media Library browser from outer drag-and-drops
    function importMediaFile(filename, path, type, autoPut) {
        mediaBrowser.addMediaFile(filename, path, type, autoPut);
    }

    // Global Lyric Sweep Progress calculator for syllable sweeps
    function calculateClipSweepProgress(clipData, currentPlayheadTimeUs) {
        if (!clipData || clipData.clipType !== 2 || clipData.syllables.length === 0) {
            return 0.0;
        }
        
        var relativePlayheadUs = currentPlayheadTimeUs - clipData.startTime;
        
        if (relativePlayheadUs <= 0) return 0.0;
        if (relativePlayheadUs >= clipData.duration) return 1.0;
        
        var totalSyllables = clipData.syllables.length;
        var fullText = clipData.lyricText;
        var totalChars = fullText.length;
        if (totalChars === 0) return 0.0;
        
        var charOffsets = [];
        var charCount = 0;
        for (var i = 0; i < totalSyllables; ++i) {
            charOffsets.push(charCount);
            charCount += clipData.syllables[i].text.length;
        }
        
        for (var i = 0; i < totalSyllables; ++i) {
            var syl = clipData.syllables[i];
            var sStart = syl.relativeStart;
            var sDuration = syl.duration;
            var sEnd = sStart + sDuration;
            
            var sylCharOffset = charOffsets[i];
            var sylCharLen = syl.text.length;
            
            if (relativePlayheadUs >= sStart && relativePlayheadUs <= sEnd) {
                var sylProgress = (relativePlayheadUs - sStart) / sDuration;
                var activeChars = sylCharOffset + (sylCharLen * sylProgress);
                return activeChars / totalChars;
            } else if (relativePlayheadUs < sStart) {
                return sylCharOffset / totalChars;
            }
        }
        return 1.0;
    }

    // getUpcomingClips — Now handled by LyricEngine C++ class

    function openMarkerDialog(marker) {
        markerDialog.markerId = marker.id;
        markerDialog.markerName = marker.name;
        markerDialog.markerColor = marker.color;
        markerDialog.markerTimeUs = marker.timeUs;
        markerDialog.open();
    }

    // Keyboard Shortcuts
    Shortcut {
        sequence: "Ctrl+Alt+S"
        onActivated: {
            timelineManager.showSourceMonitor = !timelineManager.showSourceMonitor;
            console.log("[GUI] Source monitor toggled via Ctrl+Alt+S. Visible: " + timelineManager.showSourceMonitor);
        }
    }
    Shortcut {
        sequence: "I"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            rootWindow.sourceMonitorInPointMs = rootWindow.sourceMonitorPlayheadMs;
            console.log("[SOURCE MONITOR] In point set to " + rootWindow.sourceMonitorInPointMs + " ms");
        }
    }
    Shortcut {
        sequence: "O"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            rootWindow.sourceMonitorOutPointMs = rootWindow.sourceMonitorPlayheadMs;
            console.log("[SOURCE MONITOR] Out point set to " + rootWindow.sourceMonitorOutPointMs + " ms");
        }
    }
    Shortcut {
        sequence: "Space"
        onActivated: {
            if (rootWindow.playbackState === "PlayingIntro") {
                rootWindow.bypassIntroSplash();
            } else if (rootWindow.playbackState === "PlayingOutro") {
                rootWindow.stopEndingVideoSplash();
            } else if (audioEngine.isPlaying) {
                audioEngine.pause();
            } else {
                if (timelineManager.currentPlayheadTime === 0) {
                    rootWindow.startIntroSplash();
                } else {
                    audioEngine.play();
                }
            }
        }
    }
    Shortcut {
        sequence: "J"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            if (shuttleSpeed > 0) {
                shuttleSpeed = 0.0;
                audioEngine.pause();
                shuttleTimer.running = false;
            } else if (shuttleSpeed === 0) {
                shuttleSpeed = -1.0;
                shuttleTimer.running = true;
            } else {
                shuttleSpeed = Math.max(-8.0, shuttleSpeed * 2.0);
                shuttleTimer.running = true;
            }
            console.log("[SHUTTLE] Speed set to " + shuttleSpeed + "x");
        }
    }
    Shortcut {
        sequence: "K"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            shuttleSpeed = 0.0;
            audioEngine.pause();
            shuttleTimer.running = false;
            console.log("[SHUTTLE] Playback paused");
        }
    }
    Shortcut {
        sequence: "L"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            if (shuttleSpeed < 0) {
                shuttleSpeed = 0.0;
                shuttleTimer.running = false;
            } else if (shuttleSpeed === 0) {
                shuttleSpeed = 1.0;
                audioEngine.play();
            } else {
                audioEngine.pause();
                shuttleSpeed = Math.min(8.0, shuttleSpeed * 2.0);
                shuttleTimer.running = true;
            }
            console.log("[SHUTTLE] Speed set to " + shuttleSpeed + "x");
        }
    }
    Shortcut {
        sequence: "Home"
        onActivated: timelineManager.currentPlayheadTime = 0
    }
    Shortcut {
        sequence: "End"
        onActivated: timelineManager.currentPlayheadTime = timelineManager.totalDuration
    }
    Shortcut {
        sequence: "Ctrl+S"
        onActivated: {
            if (currentProjectPath !== "") {
                timelineManager.saveProject(currentProjectPath);
                saveStatusText.text = "Project Saved!";
                saveTextAnim.start();
            } else {
                saveFileDialog.open();
            }
        }
    }
    Shortcut {
        sequence: "Ctrl+O"
        onActivated: {
            openFileDialog.open();
        }
    }
    Shortcut {
        sequence: "Delete"
        onActivated: {
            if (propertiesPanel.selectedClip && propertiesPanel.selectedTrack) {
                var deleted = propertiesPanel.selectedTrack.removeClip(propertiesPanel.selectedClip.clipId);
                if (deleted) {
                    propertiesPanel.selectedClip = null;
                }
            }
        }
    }

    Shortcut {
        sequence: "Left"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            var step = 1000000.0 / timelineManager.fps;
            timelineManager.currentPlayheadTime = Math.max(0, timelineManager.currentPlayheadTime - step);
        }
    }
    Shortcut {
        sequence: "Right"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            var step = 1000000.0 / timelineManager.fps;
            timelineManager.currentPlayheadTime = Math.min(timelineManager.totalDuration, timelineManager.currentPlayheadTime + step);
        }
    }
    Shortcut {
        sequence: "Shift+Left"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            timelineManager.currentPlayheadTime = Math.max(0, timelineManager.currentPlayheadTime - 1000000);
        }
    }
    Shortcut {
        sequence: "Shift+Right"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            timelineManager.currentPlayheadTime = Math.min(timelineManager.totalDuration, timelineManager.currentPlayheadTime + 1000000);
        }
    }
    Shortcut {
        sequence: "Up"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            var time = timelineManager.currentPlayheadTime;
            var boundaries = [0];
            var tracks = [];
            if (propertiesPanel.selectedTrack) {
                tracks.push(propertiesPanel.selectedTrack);
            } else {
                for (var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                    tracks.push(timelineManager.trackListModel.tracks()[i]);
                }
            }
            for (var t = 0; t < tracks.length; ++t) {
                var track = tracks[t];
                if (track) {
                    var clips = track.clips();
                    for (var c = 0; c < clips.length; ++c) {
                        var clip = clips[c];
                        boundaries.push(clip.startTime);
                        boundaries.push(clip.endTime);
                    }
                }
            }
            boundaries.sort(function(a, b) { return a - b; });
            var target = 0;
            for (var b = boundaries.length - 1; b >= 0; --b) {
                if (boundaries[b] < time - 50000) { // 50ms tolerance
                    target = boundaries[b];
                    break;
                }
            }
            timelineManager.currentPlayheadTime = target;
        }
    }
    Shortcut {
        sequence: "Down"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            var time = timelineManager.currentPlayheadTime;
            var boundaries = [];
            var tracks = [];
            if (propertiesPanel.selectedTrack) {
                tracks.push(propertiesPanel.selectedTrack);
            } else {
                for (var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                    tracks.push(timelineManager.trackListModel.tracks()[i]);
                }
            }
            for (var t = 0; t < tracks.length; ++t) {
                var track = tracks[t];
                if (track) {
                    var clips = track.clips();
                    for (var c = 0; c < clips.length; ++c) {
                        var clip = clips[c];
                        boundaries.push(clip.startTime);
                        boundaries.push(clip.endTime);
                    }
                }
            }
            boundaries.push(timelineManager.totalDuration);
            boundaries.sort(function(a, b) { return a - b; });
            var target = timelineManager.totalDuration;
            for (var b = 0; b < boundaries.length; ++b) {
                if (boundaries[b] > time + 50000) { // 50ms tolerance
                    target = boundaries[b];
                    break;
                }
            }
            timelineManager.currentPlayheadTime = target;
        }
    }
    Shortcut {
        sequence: "Ctrl+K"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            var time = timelineManager.currentPlayheadTime;
            if (propertiesPanel.selectedTrack) {
                var clips = propertiesPanel.selectedTrack.clips();
                for (var c = 0; c < clips.length; ++c) {
                    var clip = clips[c];
                    if (time > clip.startTime && time < clip.endTime) {
                        timelineManager.splitClip(propertiesPanel.selectedTrack.trackId, clip.clipId, time);
                        break;
                    }
                }
            } else {
                for (var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                    var track = timelineManager.trackListModel.tracks()[i];
                    if (track) {
                        var clips = track.clips();
                        for (var c = 0; c < clips.length; ++c) {
                            var clip = clips[c];
                            if (time > clip.startTime && time < clip.endTime) {
                                timelineManager.splitClip(track.trackId, clip.clipId, time);
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
    Shortcut {
        sequence: "C"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            var time = timelineManager.currentPlayheadTime;
            if (propertiesPanel.selectedTrack) {
                var clips = propertiesPanel.selectedTrack.clips();
                for (var c = 0; c < clips.length; ++c) {
                    var clip = clips[c];
                    if (time > clip.startTime && time < clip.endTime) {
                        timelineManager.splitClip(propertiesPanel.selectedTrack.trackId, clip.clipId, time);
                        break;
                    }
                }
            } else {
                for (var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                    var track = timelineManager.trackListModel.tracks()[i];
                    if (track) {
                        var clips = track.clips();
                        for (var c = 0; c < clips.length; ++c) {
                            var clip = clips[c];
                            if (time > clip.startTime && time < clip.endTime) {
                                timelineManager.splitClip(track.trackId, clip.clipId, time);
                                break;
                            }
                        }
                    }
                }
            }
        }
    }
    Shortcut {
        sequence: "M"
        enabled: !activeFocusItem || !(activeFocusItem.hasOwnProperty("textSelectionStart") || activeFocusItem.textSelectionStart !== undefined)
        onActivated: {
            var time = timelineManager.currentPlayheadTime;
            var markers = timelineManager.markers;
            var found = null;
            for (var i = 0; i < markers.length; ++i) {
                var m = markers[i];
                if (Math.abs(m.timeUs - time) < 500000) {
                    found = m;
                    break;
                }
            }
            if (found) {
                rootWindow.openMarkerDialog(found);
            } else {
                timelineManager.addMarker(time, "Marker " + (markers.length + 1), "green");
                var updatedMarkers = timelineManager.markers;
                var newMarker = null;
                for (var j = 0; j < updatedMarkers.length; ++j) {
                    if (updatedMarkers[j].timeUs === time) {
                        newMarker = updatedMarkers[j];
                        break;
                    }
                }
                if (newMarker) {
                    rootWindow.openMarkerDialog(newMarker);
                }
            }
        }
    }

    background: Rectangle {
        color: rootWindow.colorBgPitch
        
        // Dynamic futuristic gradient overlay for the visual WOW factor
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: rootWindow.colorBgPitch }
                GradientStop { position: 1.0; color: "#0B0912" }
            }
        }
    }

    // Top-level layout container
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Dynamic Glassmorphic Top Menu / Header / Transport Bar
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: rootWindow.colorBgPanel
            border.color: rootWindow.colorBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 20

                // App Branding
                RowLayout {
                    spacing: 8
                    Rectangle {
                        width: 12
                        height: 12
                        radius: 6
                        color: rootWindow.colorAccentViolet
                        opacity: 0.7
                    }
                    Label {
                        text: "NC-KTV"
                        font.pixelSize: 25
                        font.bold: true
                        font.family: "Outfit"
                        color: rootWindow.colorTextPrimary
                    }
                    Label {
                        text: "v2.0 Professional"
                        font.pixelSize: 15
                        color: rootWindow.colorAccentViolet
                        Layout.alignment: Qt.AlignBottom
                        Layout.bottomMargin: 4
                    }
                }

                // Divider
                Rectangle {
                    width: 1
                    height: 30
                    color: rootWindow.colorBorder
                }

                // Audio Playback / Clock Transport Interface
                RowLayout {
                    Layout.alignment: Qt.AlignCenter
                    spacing: 12

                    // Skip to Start (|<)
                    Button {
                        id: btnPrev
                        flat: true
                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: timelineManager.currentPlayheadTime = 0
                        contentItem: Text {
                            text: "|<"
                            color: btnPrev.hovered ? rootWindow.colorAccentViolet : rootWindow.colorTextPrimary
                            font.pixelSize: 19
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnPrev.hovered ? "#222" : "transparent"
                            radius: 4
                        }
                    }
                    // Stop (■)
                    Button {
                        id: btnStop
                        flat: true
                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: {
                            if (rootWindow.playbackState === "PlayingIntro") {
                                rootWindow.cancelIntroSplash();
                            } else if (rootWindow.playbackState === "PlayingOutro") {
                                rootWindow.stopEndingVideoSplash();
                            } else {
                                audioEngine.stop();
                            }
                        }
                        contentItem: Text {
                            text: "■"
                            color: btnStop.hovered ? rootWindow.colorAccentViolet : rootWindow.colorTextPrimary
                            font.pixelSize: 19
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnStop.hovered ? "#222" : "transparent"
                            radius: 4
                        }
                    }

                    // Play/Pause (▶ / ‖)
                    Button {
                        id: btnPlay
                        flat: true
                        implicitWidth: 40
                        implicitHeight: 40
                        onClicked: {
                            if (rootWindow.playbackState === "PlayingIntro") {
                                rootWindow.bypassIntroSplash();
                            } else if (rootWindow.playbackState === "PlayingOutro") {
                                rootWindow.stopEndingVideoSplash();
                            } else if (audioEngine.isPlaying) {
                                audioEngine.pause();
                            } else {
                                if (timelineManager.currentPlayheadTime === 0) {
                                    rootWindow.startIntroSplash();
                                } else {
                                    audioEngine.play();
                                }
                            }
                        }
                        contentItem: Text {
                            text: (rootWindow.playbackState === "PlayingIntro" || rootWindow.playbackState === "PlayingAudio") ? "‖" : "▶"
                            color: rootWindow.colorAccentGreen
                            font.pixelSize: 21
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnPlay.hovered ? "#1F352E" : "#14241F"
                            border.color: rootWindow.colorAccentGreen
                            border.width: btnPlay.hovered ? 1.5 : 1
                            radius: 20
                        }
                    }

                    // Skip to End (>|)
                    Button {
                        id: btnNext
                        flat: true
                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: timelineManager.currentPlayheadTime = timelineManager.totalDuration
                        contentItem: Text {
                            text: ">|"
                            color: btnNext.hovered ? rootWindow.colorAccentViolet : rootWindow.colorTextPrimary
                            font.pixelSize: 19
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnNext.hovered ? "#222" : "transparent"
                            radius: 4
                        }
                    }

                    // SMPTE Timecode visual display read from timelineManager
                    Rectangle {
                        color: "#050507"
                        border.color: rootWindow.colorBorder
                        radius: 6
                        width: 130
                        height: 32

                        Label {
                            anchors.centerIn: parent
                            text: timelineManager.formatTimecode(timelineManager.currentPlayheadTime)
                            color: rootWindow.colorAccentGreen
                            font.pixelSize: 17
                            font.family: "Courier New"
                            font.bold: true
                            font.letterSpacing: 1.5
                        }
                    }

                    // Master Volume Controller Slider
                    RowLayout {
                        spacing: 4
                        Layout.leftMargin: 10
                        
                        Label {
                            text: "🔊"
                            font.pixelSize: 16
                            color: rootWindow.colorTextSecondary
                        }
                        
                        Slider {
                            id: masterVolSlider
                            implicitWidth: 100
                            from: 0.0
                            to: 1.0
                            value: audioEngine.masterVolume
                            onMoved: audioEngine.masterVolume = value
                            
                            background: Rectangle {
                                implicitHeight: 4
                                color: "#222"
                                radius: 2
                                Rectangle {
                                    width: masterVolSlider.visualPosition * parent.width
                                    height: parent.height
                                    color: rootWindow.colorAccentViolet
                                    radius: 2
                                }
                            }
                            handle: Rectangle {
                                x: masterVolSlider.visualPosition * (masterVolSlider.width - width)
                                y: (masterVolSlider.height - height) / 2
                                width: 10
                                height: 10
                                radius: 5
                                color: masterVolSlider.hovered ? "#FFF" : rootWindow.colorAccentViolet
                            }
                        }
                    }
                }

                Layout.alignment: Qt.AlignVCenter
                // Right side System status and action buttons
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 12

                    Button {
                        id: btnToggleSourceMonitor
                        text: timelineManager.showSourceMonitor ? "Hide Source Monitor" : "Show Source Monitor"
                        implicitHeight: 28
                        implicitWidth: 130
                        onClicked: {
                            timelineManager.showSourceMonitor = !timelineManager.showSourceMonitor;
                        }
                        contentItem: Text {
                            text: btnToggleSourceMonitor.text
                            color: rootWindow.colorTextPrimary
                            font.bold: true
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnToggleSourceMonitor.hovered ? rootWindow.colorAccentViolet : "#1B1B22"
                            radius: 4
                            border.color: rootWindow.colorBorder
                            border.width: 1
                        }
                    }

                    Button {
                        id: btnHelp
                        text: "?"
                        implicitWidth: 28
                        implicitHeight: 28
                        onClicked: shortcutsPopup.open()
                        contentItem: Text {
                            text: btnHelp.text
                            color: rootWindow.colorTextSecondary
                            font.bold: true
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnHelp.hovered ? "#2C2C35" : "#1B1B22"
                            radius: 14
                            border.color: btnHelp.hovered ? rootWindow.colorTextSecondary : rootWindow.colorBorder
                            border.width: 1
                        }
                    }

                    Button {
                        id: btnNew
                        text: "New Project"
                        onClicked: {
                            if (timelineManager.isDirty) {
                                pendingAction = "New";
                                unsavedChangesDialog.open();
                            } else {
                                timelineManager.clearProject();
                                currentProjectPath = "";
                                propertiesPanel.selectedTrack = null;
                                propertiesPanel.selectedClip = null;
                                saveStatusText.text = "New Project Started";
                                saveTextAnim.start();
                            }
                        }
                        contentItem: Text {
                            text: btnNew.text
                            color: rootWindow.colorTextPrimary
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnNew.hovered ? rootWindow.colorAccentViolet : "#1B1B22"
                            radius: 4
                            border.color: rootWindow.colorBorder
                            border.width: 1
                        }
                    }

                    Button {
                        id: btnSave
                        text: "Save Project"
                        onClicked: {
                            if (currentProjectPath !== "") {
                                timelineManager.saveProject(currentProjectPath);
                                saveStatusText.text = "Project Saved!";
                                saveTextAnim.start();
                            } else {
                                saveFileDialog.open();
                            }
                        }
                        contentItem: Text {
                            text: btnSave.text
                            color: rootWindow.colorTextPrimary
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnSave.hovered ? rootWindow.colorAccentViolet : "#2D264A"
                            radius: 4
                            border.color: rootWindow.colorAccentViolet
                            border.width: 1
                        }
                    }

                    Button {
                        id: btnLoad
                        text: "Load Project"
                        onClicked: {
                            if (timelineManager.isDirty) {
                                pendingAction = "Open";
                                unsavedChangesDialog.open();
                            } else {
                                openFileDialog.open();
                            }
                        }
                        contentItem: Text {
                            text: btnLoad.text
                            color: rootWindow.colorTextPrimary
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnLoad.hovered ? rootWindow.colorAccentViolet : "#1B1B22"
                            radius: 4
                            border.color: rootWindow.colorBorder
                            border.width: 1
                        }
                    }

                    Button {
                        id: btnExport
                        text: "Export Video"
                        onClicked: exportDialog.open()
                        contentItem: Text {
                            text: btnExport.text
                            color: rootWindow.colorTextPrimary
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnExport.hovered ? rootWindow.colorAccentGreen : "#0E3A2F"
                            radius: 4
                            border.color: rootWindow.colorAccentGreen
                            border.width: 1
                        }
                    }

                    Text {
                        id: saveStatusText
                        text: "Project Saved!"
                        color: rootWindow.colorAccentGreen
                        font.pixelSize: 15
                        opacity: 0.0
                        
                        SequentialAnimation on opacity {
                            id: saveTextAnim
                            NumberAnimation { to: 1.0; duration: 200 }
                            PauseAnimation { duration: 1500 }
                            NumberAnimation { to: 0.0; duration: 500 }
                        }
                    }
                }
            }
        }

        // 2. Middle workspace splitter: Media browser, timeline workspace, and Clip properties inspector
        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Vertical

            // Top Pane: Media Library / Inspector Panel Split
            SplitView {
                SplitView.fillHeight: true
                orientation: Qt.Horizontal

                // Media Library
                MediaBrowser {
                    id: mediaBrowser
                    height: parent.height
                    SplitView.preferredWidth: 420
                    SplitView.minimumWidth: 250
                }

                // Center split monitors containing Source Monitor and Program Monitor
                SplitView {
                    id: monitorsSplitView
                    SplitView.fillWidth: true
                    orientation: Qt.Horizontal

                    // Source Monitor (Left Panel)
                    Rectangle {
                        id: sourceMonitorContainer
                        visible: timelineManager.showSourceMonitor
                        SplitView.preferredWidth: parent.width / 2
                        color: rootWindow.colorBgPitch
                        border.color: rootWindow.colorBorder
                        border.width: 1

                        // Video Output for Source Player
                        VideoOutput {
                            id: sourceVideoOutput
                            anchors.fill: parent
                            anchors.bottomMargin: 80
                            visible: rootWindow.sourceMonitorFilePath !== "" && rootWindow.sourceMonitorFileType === "Video"
                            fillMode: VideoOutput.PreserveAspectFit
                            
                            Component.onCompleted: {
                                sourcePlayer.videoOutput = sourceVideoOutput;
                            }
                        }

                        // Audio Visualizer for source audio-only clips
                        Canvas {
                            id: sourceVisualizerCanvas
                            anchors.fill: parent
                            anchors.bottomMargin: 80
                            visible: rootWindow.sourceMonitorFilePath !== "" && rootWindow.sourceMonitorFileType === "Audio"
                            
                            property double timePhase: 0.0
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                
                                ctx.strokeStyle = rootWindow.sourceMonitorIsPlaying ? rootWindow.colorAccentGreen : "#3A2B5E";
                                ctx.lineWidth = 2;
                                ctx.beginPath();
                                var centerY = height / 2;
                                ctx.moveTo(0, centerY);
                                for (var i = 0; i < width; i += 4) {
                                    var amp = rootWindow.sourceMonitorIsPlaying ? 40 : 15;
                                    var wave = Math.sin(i * 0.05 + timePhase) * Math.cos(i * 0.02 + timePhase * 0.7) * amp;
                                    ctx.lineTo(i, centerY + wave);
                                }
                                ctx.stroke();
                            }

                            Timer {
                                interval: 50
                                running: rootWindow.sourceMonitorIsPlaying && sourceVisualizerCanvas.visible
                                repeat: true
                                onTriggered: {
                                    sourceVisualizerCanvas.timePhase += 0.2;
                                    sourceVisualizerCanvas.requestPaint();
                                }
                            }
                        }

                        // Loading / Empty Status Placeholder
                        Column {
                            anchors.centerIn: parent
                            visible: rootWindow.sourceMonitorFilePath === ""
                            spacing: 10
                            width: parent.width - 40
                            
                            Label {
                                text: "🎬 Source Monitor"
                                font.bold: true
                                font.pixelSize: 17
                                color: rootWindow.colorTextSecondary
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                            Label {
                                text: "Double-click an asset in the Media Browser to load it here"
                                font.pixelSize: 13
                                color: "#5A5A6E"
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                            }
                        }

                        // Watermark / Guide Title
                        Label {
                            anchors.top: parent.top
                            anchors.topMargin: 15
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: parent.width - 40
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                            text: rootWindow.sourceMonitorFileName !== "" ? "SOURCE: " + rootWindow.sourceMonitorFileName.toUpperCase() : "SOURCE MONITOR"
                            font.pixelSize: 14
                            font.bold: true
                            font.letterSpacing: 2
                            color: rootWindow.colorAccentGreen
                            opacity: 0.7
                        }

                        // Scrubber bar & Trim indicators (In/Out)
                        Rectangle {
                            id: sourceScrubberContainer
                            anchors.bottom: sourceControlsRow.top
                            anchors.bottomMargin: 10
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 15
                            height: 18
                            color: "#111115"
                            border.color: rootWindow.colorBorder
                            border.width: 1
                            radius: 3
                            visible: rootWindow.sourceMonitorFilePath !== ""

                            // Highlighted Trimmed Range (In to Out)
                            Rectangle {
                                id: trimRangeRect
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.topMargin: 1
                                anchors.bottomMargin: 1
                                property double startX: rootWindow.sourceMonitorDurationMs > 0 ? (rootWindow.sourceMonitorInPointMs / rootWindow.sourceMonitorDurationMs) * parent.width : 0
                                property double endX: rootWindow.sourceMonitorDurationMs > 0 ? (rootWindow.sourceMonitorOutPointMs / rootWindow.sourceMonitorDurationMs) * parent.width : parent.width
                                x: startX
                                width: Math.max(2, endX - startX)
                                color: Qt.rgba(0.0, 0.9, 0.46, 0.15)
                                border.color: rootWindow.colorAccentGreen
                                border.width: 1
                            }

                            // In Point Bracket [
                            Label {
                                text: "["
                                font.bold: true
                                font.pixelSize: 17
                                color: rootWindow.colorAccentGreen
                                x: trimRangeRect.x - 2
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Out Point Bracket ]
                            Label {
                                text: "]"
                                font.bold: true
                                font.pixelSize: 17
                                color: rootWindow.colorAccentGreen
                                x: trimRangeRect.x + trimRangeRect.width - 6
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // Current Playhead Marker inside Source Scrubber
                            Rectangle {
                                id: sourcePlayheadMarker
                                width: 2
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                color: "#FFF"
                                x: rootWindow.sourceMonitorDurationMs > 0 ? (rootWindow.sourceMonitorPlayheadMs / rootWindow.sourceMonitorDurationMs) * (parent.width - 2) : 0
                            }

                            MouseArea {
                                anchors.fill: parent
                                property bool isDragging: false
                                
                                function updatePosition(mouseX) {
                                    if (rootWindow.sourceMonitorDurationMs <= 0) return;
                                    var pct = Math.max(0.0, Math.min(1.0, mouseX / width));
                                    var targetPosMs = pct * rootWindow.sourceMonitorDurationMs;
                                    rootWindow.sourceMonitorPlayheadMs = targetPosMs;
                                    sourcePlayer.position = targetPosMs;
                                }

                                onPressed: {
                                    isDragging = true;
                                    updatePosition(mouse.x);
                                }
                                onPositionChanged: {
                                    if (isDragging) {
                                        updatePosition(mouse.x);
                                    }
                                }
                                onReleased: {
                                    isDragging = false;
                                }
                            }
                        }

                        // Timecode indicators
                        RowLayout {
                            anchors.bottom: sourceScrubberContainer.top
                            anchors.bottomMargin: 4
                            anchors.left: sourceScrubberContainer.left
                            anchors.right: sourceScrubberContainer.right
                            spacing: 10
                            
                            Label {
                                text: timelineManager.formatTimecode(rootWindow.sourceMonitorPlayheadMs * 1000)
                                color: "#FFF"
                                font.pixelSize: 13
                                font.bold: true
                            }
                            Label {
                                text: "In: " + timelineManager.formatTimecode(rootWindow.sourceMonitorInPointMs * 1000) + "  Out: " + timelineManager.formatTimecode(rootWindow.sourceMonitorOutPointMs * 1000)
                                color: rootWindow.colorTextSecondary
                                font.pixelSize: 13
                            }
                            Item { Layout.fillWidth: true }
                            Label {
                                text: timelineManager.formatTimecode(rootWindow.sourceMonitorDurationMs * 1000)
                                color: rootWindow.colorTextSecondary
                                font.pixelSize: 13
                            }
                        }

                        // Controls Row (Mark In/Out, Play/Pause, Insert)
                        RowLayout {
                            id: sourceControlsRow
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 15
                            anchors.rightMargin: 15
                            spacing: 8
                            visible: rootWindow.sourceMonitorFilePath !== ""

                            Button {
                                text: "MARK IN [I]"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 70
                                Layout.minimumWidth: 40
                                implicitHeight: 24
                                onClicked: {
                                    rootWindow.sourceMonitorInPointMs = rootWindow.sourceMonitorPlayheadMs;
                                }
                                background: Rectangle {
                                    color: "#222"
                                    radius: 3
                                    border.color: rootWindow.colorBorder
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "#FFF"
                                    font.pixelSize: parent.width > 60 ? 13 : 11
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }

                            Button {
                                text: rootWindow.sourceMonitorIsPlaying ? "PAUSE" : "PLAY"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 60
                                Layout.minimumWidth: 40
                                implicitHeight: 24
                                onClicked: {
                                    if (rootWindow.sourceMonitorIsPlaying) {
                                        sourcePlayer.pause();
                                        rootWindow.sourceMonitorIsPlaying = false;
                                    } else {
                                        sourcePlayer.play();
                                        rootWindow.sourceMonitorIsPlaying = true;
                                    }
                                }
                                background: Rectangle {
                                    color: rootWindow.colorAccentGreen
                                    radius: 3
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "#000"
                                    font.pixelSize: parent.width > 60 ? 13 : 11
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }

                            Button {
                                text: "MARK OUT [O]"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 75
                                Layout.minimumWidth: 40
                                implicitHeight: 24
                                onClicked: {
                                    rootWindow.sourceMonitorOutPointMs = rootWindow.sourceMonitorPlayheadMs;
                                }
                                background: Rectangle {
                                    color: "#222"
                                    radius: 3
                                    border.color: rootWindow.colorBorder
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "#FFF"
                                    font.pixelSize: parent.width > 60 ? 13 : 11
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }

                            Button {
                                text: "INSERT ⬇"
                                Layout.fillWidth: true
                                Layout.preferredWidth: 70
                                Layout.minimumWidth: 40
                                implicitHeight: 24
                                onClicked: {
                                    rootWindow.insertSourceClipToTimeline();
                                }
                                background: Rectangle {
                                    color: rootWindow.colorAccentViolet
                                    radius: 3
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: "#FFF"
                                    font.pixelSize: parent.width > 60 ? 13 : 11
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }

                    // Program Monitor (Right Panel - the original previewContainer!)
                    Rectangle {
                        id: previewContainer
                        SplitView.preferredWidth: parent.width / 2
                        color: rootWindow.colorBgPitch
                        border.color: rootWindow.colorBorder
                        border.width: 1

                        VideoOutput {
                            id: videoOutput
                            anchors.fill: parent
                            visible: timelineManager.showVideoBackground && rootWindow.activeVideoClip !== null
                            fillMode: VideoOutput.PreserveAspectFit
                        }

                        // Animated Live Audio Visualizer
                        Timer {
                            id: visualizerTimer
                            interval: 33 // ~30 fps
                            running: audioEngine.isPlaying
                            repeat: true
                            onTriggered: visualizerCanvas.requestPaint()
                        }

                        Canvas {
                            id: visualizerCanvas
                            anchors.fill: parent
                            opacity: (rootWindow.activeVideoClip !== null) ? 0.0 : (audioEngine.isPlaying ? 0.35 : 0.08)
                            Behavior on opacity { NumberAnimation { duration: 500 } }
                            
                            property double timeVar: 0.0
                            property bool gridPainted: false
                            
                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);
                                
                                if (audioEngine.isPlaying) {
                                    timeVar += 0.15;
                                    gridPainted = false;
                                } else {
                                    // Draw a beautiful grid design when stopped (only once)
                                    ctx.strokeStyle = "#1A1A26";
                                    ctx.lineWidth = 1;
                                    var size = 20;
                                    for(var x = 0; x < width; x += size) {
                                        ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                                    }
                                    for(var y = 0; y < height; y += size) {
                                        ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                                    }
                                    gridPainted = true;
                                    return;
                                }
                                
                                // Neon wave drawing — deterministic (no Math.random)
                                var gradient = ctx.createLinearGradient(0, 0, width, 0);
                                gradient.addColorStop(0.0, rootWindow.colorAccentViolet);
                                gradient.addColorStop(0.5, "#00E5FF");
                                gradient.addColorStop(1.0, rootWindow.colorAccentGreen);
                                
                                ctx.strokeStyle = gradient;
                                ctx.lineWidth = 3;
                                ctx.lineCap = "round";
                                ctx.beginPath();
                                
                                var centerY = height / 2;
                                for (var i = 0; i < width; i += 5) {
                                    var angle = (i / width) * Math.PI * 4 + timeVar;
                                    var waveVal = Math.sin(angle) * Math.cos(angle * 0.5) * 45;
                                    waveVal += Math.sin(angle * 3.7 + timeVar * 2.3) * 2;
                                    
                                    if (i === 0) {
                                        ctx.moveTo(i, centerY + waveVal);
                                    } else {
                                        ctx.lineTo(i, centerY + waveVal);
                                    }
                                }
                                ctx.stroke();
                            }
                        }

                        // Glassmorphic Top Controls Bar for Live Preview Mode
                        Rectangle {
                            id: previewControlsBar
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 40
                            color: "#161622"
                            opacity: 0.9
                            border.color: "#2C2C3E"
                            border.width: 1
                            z: 10

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 15
                                anchors.rightMargin: 15
                                spacing: 10

                                Label {
                                    text: "LIVE MASTER MONITOR"
                                    font.pixelSize: 14
                                    font.bold: true
                                    font.letterSpacing: 1.5
                                    color: rootWindow.colorAccentViolet
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                // Background Toggle Button (Video vs Lyrics Only)
                                Row {
                                    spacing: 5
                                    Layout.alignment: Qt.AlignVCenter
                                    
                                    Button {
                                        id: btnVideoBg
                                        text: "Video + Lyrics"
                                        implicitHeight: 24
                                        implicitWidth: 90
                                        checkable: true
                                        checked: timelineManager.showVideoBackground
                                        onClicked: {
                                            timelineManager.showVideoBackground = true;
                                        }
                                        background: Rectangle {
                                            color: parent.checked ? rootWindow.colorAccentViolet : "#1E1E2C"
                                            radius: 4
                                            border.color: parent.checked ? rootWindow.colorAccentViolet : "#3E3E5C"
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: parent.checked ? "#FFF" : "#8A8A9E"
                                            font.pixelSize: 13
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }

                                    Button {
                                        id: btnLyricsOnlyBg
                                        text: "Lyrics Only"
                                        implicitHeight: 24
                                        implicitWidth: 80
                                        checkable: true
                                        checked: !timelineManager.showVideoBackground
                                        onClicked: {
                                            timelineManager.showVideoBackground = false;
                                        }
                                        background: Rectangle {
                                            color: parent.checked ? rootWindow.colorAccentViolet : "#1E1E2C"
                                            radius: 4
                                            border.color: parent.checked ? rootWindow.colorAccentViolet : "#3E3E5C"
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            color: parent.checked ? "#FFF" : "#8A8A9E"
                                            font.pixelSize: 13
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                // Separator
                                Rectangle {
                                    width: 1
                                    height: 16
                                    color: "#2C2C3E"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Lyrics Layout Mode Selector (4 modes)
                                Row {
                                    spacing: 3
                                    Layout.alignment: Qt.AlignVCenter

                                    Repeater {
                                        model: [
                                            { label: "Bottom", mode: 0 },
                                            { label: "Queue", mode: 1 },
                                            { label: "Bounce", mode: 2 },
                                            { label: "Cinema", mode: 3 }
                                        ]
                                        delegate: Button {
                                            text: modelData.label
                                            implicitHeight: 24
                                            implicitWidth: 58
                                            checkable: true
                                            checked: timelineManager.lyricDisplayMode === modelData.mode
                                            onClicked: {
                                                timelineManager.lyricDisplayMode = modelData.mode;
                                            }
                                            background: Rectangle {
                                                color: parent.checked ? rootWindow.colorAccentGreen : "#1E1E2C"
                                                radius: 4
                                                border.color: parent.checked ? rootWindow.colorAccentGreen : "#3E3E5C"
                                            }
                                            contentItem: Text {
                                                text: parent.text
                                                color: parent.checked ? "#000" : "#8A8A9E"
                                                font.pixelSize: 12
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                }

                                // Separator
                                Rectangle {
                                    width: 1
                                    height: 16
                                    color: "#2C2C3E"
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Preview Lyrics Toggle Button
                                Button {
                                    id: btnPreviewLyrics
                                    text: lyricsPreviewTimer.running ? "⏹ STOP PREVIEW" : "🎬 PREVIEW LYRICS"
                                    implicitHeight: 24
                                    implicitWidth: 110
                                    checkable: true
                                    checked: lyricsPreviewTimer.running
                                    onClicked: {
                                        if (lyricsPreviewTimer.running) {
                                            lyricsPreviewTimer.running = false;
                                        } else {
                                            if (audioEngine.isPlaying) {
                                                audioEngine.pause();
                                            }
                                            lyricsPreviewTimer.running = true;
                                        }
                                    }
                                    background: Rectangle {
                                        color: parent.checked ? "#FF5252" : "#1E1E2C"
                                        radius: 4
                                        border.color: parent.checked ? "#FF5252" : "#3E3E5C"
                                    }
                                    contentItem: Text {
                                        text: parent.text
                                        color: parent.checked ? "#FFF" : rootWindow.colorAccentGreen
                                        font.pixelSize: 12
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }

                        // ── Karaoke Lyric Rendering Component ─────────────
                        KaraokeLyricView {
                            id: karaokeLyricView
                            anchors.fill: parent
                            lyricEngine: timelineManager.lyricEngine
                            fontFamily: timelineManager.subtitleFontFamily
                            fontSize: timelineManager.subtitleFontSize
                            fillColor: timelineManager.subtitleFillColor
                            activeColor: timelineManager.subtitleActiveColor
                            outlineColor: timelineManager.subtitleOutlineColor
                            outlineWidth: timelineManager.subtitleOutlineWidth
                            currentPlayheadTime: timelineManager.currentPlayheadTime
                        }


                        // Song Intro Splash Overlay
                        Item {
                            id: introSplashScreen
                            anchors.fill: parent
                            z: 100
                            visible: opacity > 0.0
                            opacity: 0.0

                            property alias introAnimationSequence: introAnimationSequence

                            property color colorBg: "#08080A"
                            property color colorTextPrimary: "#F0F0F5"
                            property color colorTextSecondary: "#8A8A9E"
                            property color colorAccentViolet: "#7C4DFF"
                            property color colorAccentGreen: "#00E676"

                            // Bypass click handler for background
                            MouseArea {
                                anchors.fill: parent
                                onClicked: rootWindow.bypassIntroSplash()
                            }

                            // Breathing glow ambient effect
                            Rectangle {
                                anchors.fill: parent
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#050508" }
                                    GradientStop { position: 0.5; color: "#0F0B1E" }
                                    GradientStop { position: 1.0; color: "#050508" }
                                }
                                
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.width, parent.height) * 0.8
                                    height: width
                                    radius: width / 2
                                    color: "#7C4DFF"
                                    opacity: 0.05
                                }
                            }

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 18
                                width: Math.min(parent.width - 80, 600)

                                Label {
                                    id: brandingLabel
                                    text: "NOW PLAYING"
                                    font.pixelSize: 15
                                    font.bold: true
                                    font.letterSpacing: 4
                                    color: introSplashScreen.colorAccentGreen
                                    Layout.alignment: Qt.AlignCenter
                                    opacity: 0.0
                                    scale: 0.8
                                }

                                Label {
                                    id: titleLabel
                                    text: timelineManager.songTitle !== "" ? timelineManager.songTitle : "Untitled Song"
                                    font.pixelSize: Math.max(30, Math.min(parent.width / 14, 48))
                                    font.bold: true
                                    font.family: "Outfit"
                                    color: introSplashScreen.colorTextPrimary
                                    Layout.alignment: Qt.AlignCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                    opacity: 0.0
                                    
                                    style: Text.Outline
                                    styleColor: Qt.rgba(124/255, 77/255, 255/255, 0.25)
                                    
                                    transform: Translate { y: introSplashScreen.titleYOffset }
                                }

                                Rectangle {
                                    id: dividerLine
                                    height: 1
                                    color: introSplashScreen.colorAccentViolet
                                    Layout.alignment: Qt.AlignCenter
                                    Layout.preferredWidth: 0
                                    opacity: 0.0
                                }

                                Label {
                                    id: artistLabel
                                    text: timelineManager.artistName !== "" ? timelineManager.artistName : "Unknown Artist"
                                    font.pixelSize: Math.max(18, Math.min(parent.width / 22, 25))
                                    font.family: "Outfit"
                                    color: introSplashScreen.colorTextSecondary
                                    Layout.alignment: Qt.AlignCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                    opacity: 0.0
                                    
                                    transform: Translate { y: introSplashScreen.artistYOffset }
                                }
                            }

                            // Interactive SKIP INTRO button
                            Label {
                                id: skipIntroLabel
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.rightMargin: 24
                                anchors.bottomMargin: 24
                                text: "SKIP INTRO (Space)"
                                font.pixelSize: 16
                                font.family: "Outfit"
                                font.bold: true
                                color: introSplashScreen.colorTextSecondary
                                opacity: 0.6
                                z: 10
                                
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onEntered: skipIntroLabel.opacity = 1.0
                                    onExited: skipIntroLabel.opacity = 0.6
                                    onClicked: rootWindow.bypassIntroSplash()
                                }
                            }

                            property real titleYOffset: 30
                            property real artistYOffset: 20

                            ParallelAnimation {
                                id: introAnimationSequence
                                
                                NumberAnimation {
                                    target: introSplashScreen
                                    property: "opacity"
                                    from: 0.0
                                    to: 1.0
                                    duration: 500
                                    easing.type: Easing.OutQuad
                                }

                                SequentialAnimation {
                                    PauseAnimation { duration: 150 }
                                    ParallelAnimation {
                                        NumberAnimation { target: brandingLabel; property: "opacity"; from: 0.0; to: 0.8; duration: 350; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: brandingLabel; property: "scale"; from: 0.8; to: 1.0; duration: 350; easing.type: Easing.OutBack }
                                    }
                                }

                                SequentialAnimation {
                                    PauseAnimation { duration: 300 }
                                    ParallelAnimation {
                                        NumberAnimation { target: titleLabel; property: "opacity"; from: 0.0; to: 1.0; duration: 600; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: introSplashScreen; property: "titleYOffset"; from: 30; to: 0; duration: 600; easing.type: Easing.OutCubic }
                                    }
                                }

                                SequentialAnimation {
                                    PauseAnimation { duration: 450 }
                                    ParallelAnimation {
                                        NumberAnimation { target: dividerLine; property: "opacity"; from: 0.0; to: 0.7; duration: 250 }
                                        NumberAnimation { target: dividerLine; property: "Layout.preferredWidth"; from: 0; to: 140; duration: 500; easing.type: Easing.OutQuint }
                                    }
                                }

                                SequentialAnimation {
                                    PauseAnimation { duration: 600 }
                                    ParallelAnimation {
                                        NumberAnimation { target: artistLabel; property: "opacity"; from: 0.0; to: 1.0; duration: 500; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: introSplashScreen; property: "artistYOffset"; from: 20; to: 0; duration: 500; easing.type: Easing.OutCubic }
                                    }
                                }

                                SequentialAnimation {
                                    PauseAnimation {
                                        duration: Math.max(1000, timelineManager.introSplashDuration - 1100)
                                    }
                                    ParallelAnimation {
                                        NumberAnimation { target: introSplashScreen; property: "opacity"; to: 0.0; duration: 500; easing.type: Easing.InOutQuad }
                                    }
                                    ScriptAction {
                                        script: {
                                            console.log("[INTRO SPLASH] Intro animation completed. Automatically starting song playback.");
                                            rootWindow.playbackState = "PlayingAudio";
                                            audioEngine.play();
                                        }
                                    }
                                }
                            }

                            function startIntro() {
                                introAnimationSequence.stop();
                                titleLabel.text = timelineManager.songTitle !== "" ? timelineManager.songTitle : "Untitled Song";
                                artistLabel.text = timelineManager.artistName !== "" ? timelineManager.artistName : "Unknown Artist";
                                brandingLabel.opacity = 0.0;
                                brandingLabel.scale = 0.8;
                                titleLabel.opacity = 0.0;
                                titleYOffset = 30;
                                dividerLine.opacity = 0.0;
                                dividerLine.Layout.preferredWidth = 0;
                                artistLabel.opacity = 0.0;
                                artistYOffset = 20;
                                introSplashScreen.opacity = 0.0;
                                
                                console.log("[INTRO SPLASH] Launching intro splash overlay.");
                                introAnimationSequence.start();
                            }
                        }

                        // Song Ending Video Splash Overlay
                        Rectangle {
                            id: endingVideoOverlay
                            anchors.fill: parent
                            color: "#000000"
                            z: 101
                            visible: false

                            VideoOutput {
                                id: endingVideoOutput
                                anchors.fill: parent
                                fillMode: VideoOutput.PreserveAspectFit
                            }
                        }
                    }
                }

                // Properties Panel Inspector
                PropertiesPanel {
                    id: propertiesPanel
                    height: parent.height
                    SplitView.preferredWidth: 420
                    SplitView.minimumWidth: 250
                }
            }

            // Bottom Pane: Timeline Editor
            TimelineView {
                id: timelineView
                SplitView.preferredHeight: 300
                SplitView.minimumHeight: 180

                onYChanged: {
                    var pt = mapToItem(rootWindow.contentItem, 0, 0);
                    rootWindow.timelineTopY = pt ? pt.y : 0;
                }
                Component.onCompleted: {
                    var pt = mapToItem(rootWindow.contentItem, 0, 0);
                    rootWindow.timelineTopY = pt ? pt.y : 0;
                }
            }
        }
    }

    ExportDialog {
        id: exportDialog
    }

    FileDialog {
        id: saveFileDialog
        title: "Save Project As"
        fileMode: FileDialog.SaveFile
        nameFilters: ["NC-KTV Project files (*.nctv)"]
        defaultSuffix: "nctv"
        onAccepted: {
            var path = selectedFile.toString();
            if (path.startsWith("file:///")) {
                path = path.substring(8);
            }
            if (path.charAt(0) === '/' && path.charAt(2) === ':') {
                path = path.substring(1);
            }
            path = decodeURIComponent(path);
            if (!path.endsWith(".nctv")) {
                path += ".nctv";
            }
            if (timelineManager.saveProject(path)) {
                currentProjectPath = path;
                saveStatusText.text = "Project Saved!";
                if (closeRequested || pendingAction !== "") {
                    executePendingAction();
                }
            } else {
                saveStatusText.text = "Save Failed";
                closeRequested = false;
                pendingAction = "";
            }
            saveTextAnim.start();
        }
        onRejected: {
            closeRequested = false;
            pendingAction = "";
        }
    }

    Dialog {
        id: markerDialog
        title: "Edit Sequence Marker"
        modal: true
        anchors.centerIn: parent
        width: 350
        standardButtons: Dialog.NoButton

        background: Rectangle {
            color: rootWindow.colorBgPanel
            border.color: rootWindow.colorAccentViolet
            border.width: 2
            radius: 8
        }

        header: Rectangle {
            color: rootWindow.colorBgCard
            height: 40
            width: parent.width
            radius: 8
            
            Label {
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                text: "SEQUENCE MARKER EDITOR"
                font.bold: true
                font.pixelSize: 16
                color: rootWindow.colorAccentViolet
            }
        }

        property string markerId: ""
        property string markerName: ""
        property string markerColor: "green"
        property double markerTimeUs: 0
        property string selectedColor: "green"

        onOpened: {
            markerNameField.text = markerName;
            selectedColor = markerColor;
        }

        contentItem: ColumnLayout {
            spacing: 15
            anchors.margins: 15

            Label {
                text: "Timecode: " + timelineManager.formatTimecode(markerDialog.markerTimeUs)
                color: rootWindow.colorTextSecondary
                font.pixelSize: 15
            }

            ColumnLayout {
                spacing: 5
                Layout.fillWidth: true
                Label {
                    text: "Name"
                    color: rootWindow.colorTextPrimary
                    font.bold: true
                    font.pixelSize: 15
                }
                TextField {
                    id: markerNameField
                    Layout.fillWidth: true
                    placeholderText: "Marker Name"
                    color: rootWindow.colorTextPrimary
                    background: Rectangle {
                        color: "#16161D"
                        border.color: markerNameField.activeFocus ? rootWindow.colorAccentViolet : rootWindow.colorBorder
                        border.width: 1
                        radius: 4
                    }
                }
            }

            ColumnLayout {
                spacing: 5
                Layout.fillWidth: true
                Label {
                    text: "Color"
                    color: rootWindow.colorTextPrimary
                    font.bold: true
                    font.pixelSize: 15
                }
                RowLayout {
                    spacing: 10
                    Layout.fillWidth: true

                    Repeater {
                        model: [
                            { name: "green", hex: "#00E676" },
                            { name: "red", hex: "#FF5252" },
                            { name: "blue", hex: "#29B6F6" },
                            { name: "yellow", hex: "#FFCA28" }
                        ]

                        delegate: Rectangle {
                            width: 28
                            height: 28
                            radius: 14
                            color: modelData.hex
                            border.color: markerDialog.selectedColor === modelData.name ? "#FFF" : "transparent"
                            border.width: 2

                            MouseArea {
                                anchors.fill: parent
                                onClicked: markerDialog.selectedColor = modelData.name
                            }

                            scale: markerDialog.selectedColor === modelData.name ? 1.15 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100 } }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Button {
                    id: btnDeleteMarker
                    text: "DELETE"
                    implicitHeight: 28
                    Layout.fillWidth: true
                    onClicked: {
                        timelineManager.removeMarker(markerDialog.markerId);
                        markerDialog.close();
                    }
                    background: Rectangle {
                        color: btnDeleteMarker.hovered ? "#EF5350" : "#C62828"
                        radius: 4
                    }
                    contentItem: Text {
                        text: btnDeleteMarker.text
                        font.bold: true
                        font.pixelSize: 14
                        color: "#FFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: btnSaveMarker
                    text: "OK"
                    implicitHeight: 28
                    Layout.fillWidth: true
                    onClicked: {
                        timelineManager.updateMarker(markerDialog.markerId, markerNameField.text, markerDialog.selectedColor);
                        markerDialog.close();
                    }
                    background: Rectangle {
                        color: btnSaveMarker.hovered ? rootWindow.colorAccentGreen : "#00A354"
                        radius: 4
                    }
                    contentItem: Text {
                        text: btnSaveMarker.text
                        font.bold: true
                        font.pixelSize: 14
                        color: "#000"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: btnCancelMarker
                    text: "CANCEL"
                    implicitHeight: 28
                    Layout.fillWidth: true
                    onClicked: {
                        markerDialog.close();
                    }
                    background: Rectangle {
                        color: btnCancelMarker.hovered ? "#3E3E4D" : "#2C2C35"
                        radius: 4
                        border.color: rootWindow.colorBorder
                    }
                    contentItem: Text {
                        text: btnCancelMarker.text
                        font.bold: true
                        font.pixelSize: 14
                        color: rootWindow.colorTextSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    Dialog {
        id: unsavedChangesDialog
        title: "Unsaved Changes"
        modal: true
        anchors.centerIn: parent
        width: 400
        standardButtons: Dialog.NoButton

        background: Rectangle {
            color: rootWindow.colorBgPanel
            border.color: rootWindow.colorAccentViolet
            border.width: 2
            radius: 8
        }

        header: Rectangle {
            color: rootWindow.colorBgCard
            height: 40
            width: parent.width
            radius: 8
            
            Label {
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                text: "UNSAVED CHANGES"
                font.bold: true
                font.pixelSize: 16
                color: rootWindow.colorAccentViolet
            }
        }

        contentItem: ColumnLayout {
            spacing: 15
            anchors.margins: 15

            Label {
                text: {
                    if (pendingAction === "New") {
                        return "You have unsaved changes in your project. Do you want to save them before starting a new project?";
                    } else if (pendingAction === "Open") {
                        return "You have unsaved changes in your project. Do you want to save them before loading another project?";
                    } else {
                        return "You have unsaved changes in your project. Do you want to save them before closing?";
                    }
                }
                color: rootWindow.colorTextPrimary
                font.pixelSize: 16
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10

                Button {
                    id: btnSaveUnsaved
                    text: "SAVE"
                    implicitWidth: 80
                    implicitHeight: 28
                    onClicked: {
                        unsavedChangesDialog.close();
                        if (currentProjectPath !== "") {
                            if (timelineManager.saveProject(currentProjectPath)) {
                                executePendingAction();
                            }
                        } else {
                            saveFileDialog.open();
                        }
                    }
                    background: Rectangle {
                        color: btnSaveUnsaved.hovered ? rootWindow.colorAccentGreen : "#00A354"
                        radius: 4
                    }
                    contentItem: Text {
                        text: btnSaveUnsaved.text
                        font.bold: true
                        font.pixelSize: 14
                        color: "#000"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: btnDiscardUnsaved
                    text: "DON'T SAVE"
                    implicitWidth: 90
                    implicitHeight: 28
                    onClicked: {
                        unsavedChangesDialog.close();
                        timelineManager.setDirty(false);
                        executePendingAction();
                    }
                    background: Rectangle {
                        color: btnDiscardUnsaved.hovered ? "#EF5350" : "#C62828"
                        radius: 4
                    }
                    contentItem: Text {
                        text: btnDiscardUnsaved.text
                        font.bold: true
                        font.pixelSize: 14
                        color: "#FFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: btnCancelUnsaved
                    text: "CANCEL"
                    implicitWidth: 80
                    implicitHeight: 28
                    onClicked: {
                        unsavedChangesDialog.close();
                        closeRequested = false;
                        pendingAction = "";
                    }
                    background: Rectangle {
                        color: btnCancelUnsaved.hovered ? "#3E3E4D" : "#2C2C35"
                        radius: 4
                        border.color: rootWindow.colorBorder
                    }
                    contentItem: Text {
                        text: btnCancelUnsaved.text
                        font.bold: true
                        font.pixelSize: 14
                        color: rootWindow.colorTextSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    FileDialog {
        id: openFileDialog
        title: "Open Project"
        fileMode: FileDialog.OpenFile
        nameFilters: ["NC-KTV Project files (*.nctv)"]
        onAccepted: {
            var path = selectedFile.toString();
            if (path.startsWith("file:///")) {
                path = path.substring(8);
            }
            if (path.charAt(0) === '/' && path.charAt(2) === ':') {
                path = path.substring(1);
            }
            path = decodeURIComponent(path);
            if (timelineManager.loadProject(path)) {
                currentProjectPath = path;
                saveStatusText.text = "Project Loaded!";
            } else {
                saveStatusText.text = "Load Failed";
            }
            saveTextAnim.start();
        }
    }

    FileDialog {
        id: lyricFileDialog
        title: "Import Timed Lyrics File"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Lyrics files (*.srt *.lrc)", "SubRip Subtitles (*.srt)", "LRC Synced Lyrics (*.lrc)"]
        property string targetTrackId: ""
        onAccepted: {
            var path = selectedFile.toString();
            if (path.startsWith("file:///")) {
                path = path.substring(8);
            }
            path = decodeURIComponent(path);
            if (targetTrackId !== "") {
                timelineManager.importLyricsFromFile(targetTrackId, path);
            } else {
                var firstLyricTrackId = "";
                for (var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                    var track = timelineManager.trackListModel.tracks()[i];
                    if (track && track.trackType === 2) {
                        firstLyricTrackId = track.trackId;
                        break;
                    }
                }
                if (firstLyricTrackId !== "") {
                    timelineManager.importLyricsFromFile(firstLyricTrackId, path);
                }
            }
        }
    }

    FileDialog {
        id: mediaFileDialog
        title: "Import Audio/Video Media"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Media files (*.wav *.mp3 *.mp4 *.mov *.m4a)", "Audio Files (*.wav *.mp3 *.m4a)", "Video Files (*.mp4 *.mov)"]
        onAccepted: {
            var path = selectedFile.toString();
            if (path.startsWith("file:///")) {
                path = path.substring(8);
            }
            path = decodeURIComponent(path);
            
            var filename = path.substring(path.lastIndexOf('/') + 1);
            var lastDotIdx = filename.lastIndexOf('.');
            var extension = lastDotIdx !== -1 ? filename.substring(lastDotIdx + 1).toLowerCase() : "";
            var isVideo = (extension === "mp4" || extension === "mov");
            
            mediaBrowser.addMediaFile(filename, path, isVideo ? "Video" : "Audio", true);
        }
    }

    FileDialog {
        id: modelFileDialog
        title: "Select ONNX Stem Separation Model"
        fileMode: FileDialog.OpenFile
        nameFilters: ["ONNX Model Files (*.onnx)"]
        onAccepted: {
            var path = selectedFile.toString();
            if (path.startsWith("file:///")) {
                path = path.substring(8);
            }
            // Remove leading slash on Windows if present
            if (Qt.platform.os === "windows" && path.charAt(0) === '/' && path.charAt(2) === ':') {
                path = path.substring(1);
            }
            path = decodeURIComponent(path);
            timelineManager.modelPath = path;
        }
    }

    FolderDialog {
        id: modelFolderDialog
        title: "Select ONNX Models Directory"
        onAccepted: {
            var path = selectedFolder.toString();
            if (path.startsWith("file:///")) {
                path = path.substring(8);
            }
            // Remove leading slash on Windows if present
            if (Qt.platform.os === "windows" && path.charAt(0) === '/' && path.charAt(2) === ':') {
                path = path.substring(1);
            }
            path = decodeURIComponent(path);
            timelineManager.modelsDirPath = path;
        }
    }

    Popup {
        id: modelSelectionPopup
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        width: 460
        height: 250

        background: Rectangle {
            color: "#111115"
            border.color: "#2A2A35"
            border.width: 2
            radius: 12
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: "transparent"
                border.color: "#3A3A4A"
                border.width: 1
                radius: 11
            }
        }

        property string pendingClipId: ""
        property string pendingFilePath: ""

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                spacing: 10
                Rectangle {
                    width: 8
                    height: 20
                    color: rootWindow.colorAccentViolet
                    radius: 2
                }
                Label {
                    text: "ONNX Separation Model Required"
                    font.pixelSize: 18
                    font.bold: true
                    font.family: "Outfit"
                    color: "#F0F0F5"
                }
            }

            Label {
                text: "No AI stem separation model (.onnx) is currently selected. Select your Ultimate Vocal Remover 'models' folder to dynamically list all models, browse for a single model file, or proceed with real-time center-channel DSP extraction."
                font.pixelSize: 15
                color: "#8A8A9E"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                Layout.topMargin: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: btnDialogSelectFolder
                        Layout.fillWidth: true
                        implicitHeight: 32
                        text: "Select Models Folder..."
                        onClicked: {
                            modelSelectionPopup.close();
                            modelFolderDialog.open();
                        }
                        contentItem: Text {
                            text: btnDialogSelectFolder.text
                            color: "#FFF"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 15
                        }
                        background: Rectangle {
                            color: btnDialogSelectFolder.hovered ? "#8E5CFF" : rootWindow.colorAccentViolet
                            border.color: "#A27FFF"
                            border.width: 1
                            radius: 6
                        }
                    }

                    Button {
                        id: btnDialogSelectModel
                        Layout.fillWidth: true
                        implicitHeight: 32
                        text: "Select Single File..."
                        onClicked: {
                            modelSelectionPopup.close();
                            modelFileDialog.open();
                        }
                        contentItem: Text {
                            text: btnDialogSelectModel.text
                            color: "#F0F0F5"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 15
                        }
                        background: Rectangle {
                            color: btnDialogSelectModel.hovered ? "#2D264A" : "#1B1B22"
                            border.color: rootWindow.colorAccentViolet
                            border.width: 1
                            radius: 6
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Button {
                        id: btnDialogDsp
                        Layout.fillWidth: true
                        implicitHeight: 32
                        text: "Use DSP Fallback"
                        onClicked: {
                            modelSelectionPopup.close();
                            if (modelSelectionPopup.pendingClipId !== "") {
                                timelineManager.separateStems(modelSelectionPopup.pendingClipId);
                            } else if (modelSelectionPopup.pendingFilePath !== "") {
                                timelineManager.separateStemsForFile(modelSelectionPopup.pendingFilePath);
                            }
                        }
                        contentItem: Text {
                            text: btnDialogDsp.text
                            color: "#F0F0F5"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 15
                        }
                        background: Rectangle {
                            color: btnDialogDsp.hovered ? "#2B2B38" : "#1B1B22"
                            border.color: "#2A2A35"
                            border.width: 1
                            radius: 6
                        }
                    }

                    Button {
                        id: btnDialogCancel
                        Layout.preferredWidth: 100
                        implicitHeight: 32
                        text: "Cancel"
                        onClicked: modelSelectionPopup.close()
                        contentItem: Text {
                            text: btnDialogCancel.text
                            color: "#8A8A9E"
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 15
                        }
                        background: Rectangle {
                            color: btnDialogCancel.hovered ? "#222" : "#15151A"
                            border.color: "#2A2A35"
                            border.width: 1
                            radius: 6
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: shortcutsPopup
        modal: true
        focus: true
        anchors.centerIn: Overlay.overlay
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        width: 380
        height: 280

        background: Rectangle {
            color: "#111115"
            border.color: "#2A2A35"
            border.width: 2
            radius: 12
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                color: "transparent"
                border.color: "#3A3A4A"
                border.width: 1
                radius: 11
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                spacing: 10
                Rectangle {
                    width: 8
                    height: 20
                    color: rootWindow.colorAccentViolet
                    radius: 2
                }
                Label {
                    text: "Keyboard Shortcuts Guide"
                    font.pixelSize: 18
                    font.bold: true
                    font.family: "Outfit"
                    color: "#F0F0F5"
                }
            }

            GridLayout {
                columns: 2
                rowSpacing: 8
                columnSpacing: 15
                Layout.fillWidth: true
                Layout.fillHeight: true

                Label { text: "Spacebar"; font.bold: true; color: rootWindow.colorAccentGreen }
                Label { text: "Play / Pause Audio"; color: rootWindow.colorTextPrimary }

                Label { text: "Ctrl + S"; font.bold: true; color: rootWindow.colorAccentGreen }
                Label { text: "Save Active Project"; color: rootWindow.colorTextPrimary }

                Label { text: "Home / End"; font.bold: true; color: rootWindow.colorAccentGreen }
                Label { text: "Go to Project Start / End"; color: rootWindow.colorTextPrimary }

                Label { text: "Delete"; font.bold: true; color: rootWindow.colorAccentGreen }
                Label { text: "Delete Selected Timeline Clip"; color: rootWindow.colorTextPrimary }

                Label { text: "Drag Clip"; font.bold: true; color: rootWindow.colorAccentGreen }
                Label { text: "Move clip (Snaps to bounds)"; color: rootWindow.colorTextPrimary }

                Label { text: "Clip Ends"; font.bold: true; color: rootWindow.colorAccentGreen }
                Label { text: "Resize left/right clip boundary"; color: rootWindow.colorTextPrimary }
            }

            Button {
                id: btnCloseShortcuts
                Layout.fillWidth: true
                implicitHeight: 30
                text: "Got It"
                onClicked: shortcutsPopup.close()
                contentItem: Text {
                    text: btnCloseShortcuts.text
                    color: "#F0F0F5"
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 15
                }
                background: Rectangle {
                    color: btnCloseShortcuts.hovered ? "#8E5CFF" : rootWindow.colorAccentViolet
                    radius: 6
                }
            }
        }
    }

    // Global Drag & Drop support to import media files directly into the project library
    DropArea {
        id: globalDropArea
        anchors.top: parent.top
        height: rootWindow.timelineTopY
        anchors.left: parent.left
        anchors.right: parent.right
        keys: ["text/uri-list"]
        onEntered: (drag) => {
            if (drag.hasUrls) {
                drag.accepted = true;
            }
        }
        onDropped: (drop) => {
            if (drop.hasUrls) {
                drop.accepted = true;
                for (var i = 0; i < drop.urls.length; ++i) {
                    var url = drop.urls[i].toString();
                    if (url.startsWith("file:///")) {
                        url = url.substring(8);
                    }
                    if (url.charAt(0) === '/' && url.charAt(2) === ':') {
                        url = url.substring(1);
                    }
                    url = decodeURIComponent(url);
                    
                    var filename = url.substring(url.lastIndexOf('/') + 1);
                    var lastDotIdx = filename.lastIndexOf('.');
                    var extension = lastDotIdx !== -1 ? filename.substring(lastDotIdx + 1).toLowerCase() : "";
                    
                    var trackTypeName = "";
                    if (extension === "srt" || extension === "lrc") {
                        trackTypeName = "Lyrics";
                    } else if (extension === "mp4" || extension === "mov" || extension === "avi" || extension === "mkv") {
                        trackTypeName = "Video";
                    } else if (extension === "wav" || extension === "mp3" || extension === "m4a" || extension === "ogg" || extension === "flac") {
                        trackTypeName = "Audio";
                    }
                    
                    if (trackTypeName !== "") {
                        rootWindow.importMediaFile(filename, url, trackTypeName, false);
                    }
                }
            }
        }
    }

    // Glassmorphic drop overlay visual cue
    Rectangle {
        anchors.top: parent.top
        height: rootWindow.timelineTopY
        anchors.left: parent.left
        anchors.right: parent.right
        color: "#E6090710"
        border.color: rootWindow.colorAccentViolet
        border.width: 3
        z: 99999
        visible: globalDropArea.containsDrag
        
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 15
            Label {
                text: "📥"
                font.pixelSize: 48
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                text: "Drop media files to import into project library"
                font.bold: true
                font.pixelSize: 20
                color: "#FFF"
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // User-friendly Playback Error & Format Incompatibility Dialog
    Dialog {
        id: playbackErrorDialog
        title: "Playback Error"
        modal: true
        anchors.centerIn: parent
        width: 420
        standardButtons: Dialog.NoButton
        
        property string errorMsg: ""

        background: Rectangle {
            color: rootWindow.colorBgPanel
            border.color: "#FF5252"
            border.width: 2
            radius: 8
        }

        header: Rectangle {
            color: rootWindow.colorBgCard
            height: 40
            width: parent.width
            radius: 8
            
            Label {
                anchors.left: parent.left
                anchors.leftMargin: 15
                anchors.verticalCenter: parent.verticalCenter
                text: "⚠️ PLAYBACK ERROR / INCOMPATIBILITY WARNING"
                font.bold: true
                font.pixelSize: 13
                color: "#FF5252"
            }
        }

        contentItem: ColumnLayout {
            spacing: 12
            Layout.margins: 15

            Label {
                text: "The application encountered a playback error: "
                color: rootWindow.colorTextPrimary
                font.bold: true
                font.pixelSize: 13
            }

            Label {
                text: playbackErrorDialog.errorMsg
                color: "#FF8A80"
                font.family: "Courier New"
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Label {
                text: "This usually occurs if the file resolution is too high (e.g. 4K, 2K) or uses the AV1/VP9 codecs, which your system's hardware decoder does not support natively. For seamless real-time NLE editing, we highly recommend downloading or converting your files to standard H.264 (AVC) and AAC audio in 1080p resolution."
                color: rootWindow.colorTextSecondary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10
                Layout.fillWidth: true

                Button {
                    id: btnSwitchToSoftware
                    text: "Switch to Software Decoding & Restart"
                    implicitHeight: 28
                    Layout.fillWidth: true
                    visible: !timelineManager.disableHwDecoding
                    onClicked: {
                        playbackErrorDialog.close();
                        timelineManager.setDisableHwDecoding(true);
                        timelineManager.restartApplication();
                    }
                    background: Rectangle {
                        color: btnSwitchToSoftware.hovered ? rootWindow.colorAccentViolet : "#2D264A"
                        radius: 4
                        border.color: rootWindow.colorAccentViolet
                    }
                    contentItem: Text {
                        text: btnSwitchToSoftware.text
                        font.bold: true
                        font.pixelSize: 12
                        color: "#FFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: btnDismissError
                    text: "Dismiss"
                    Layout.preferredWidth: 90
                    implicitHeight: 28
                    onClicked: playbackErrorDialog.close()
                    background: Rectangle {
                        color: btnDismissError.hovered ? "#FF5252" : "#222"
                        radius: 4
                        border.color: btnDismissError.hovered ? "#FF5252" : rootWindow.colorBorder
                    }
                    contentItem: Text {
                        text: btnDismissError.text
                        font.bold: true
                        font.pixelSize: 12
                        color: btnDismissError.hovered ? "#FFF" : rootWindow.colorTextSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}


