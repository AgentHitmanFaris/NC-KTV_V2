import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ncktv.gui
import QtQuick.Dialogs


ApplicationWindow {
    id: rootWindow
    visible: true
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

    // Keyboard Shortcuts
    Shortcut {
        sequence: "Space"
        onActivated: {
            if (audioEngine.isPlaying) {
                audioEngine.pause();
            } else {
                audioEngine.play();
            }
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
            var filePath = "D:/Document/NC-Project/NC-KTV/NC-KTV_V2/project.nctv";
            timelineManager.saveProject(filePath);
            saveStatusText.text = "Project Saved!";
            saveTextAnim.start();
        }
    }
    Shortcut {
        sequence: "Ctrl+O"
        onActivated: {
            var filePath = "D:/Document/NC-Project/NC-KTV/NC-KTV_V2/project.nctv";
            if (timelineManager.loadProject(filePath)) {
                saveStatusText.text = "Project Loaded!";
            } else {
                saveStatusText.text = "Load Failed (no saved project)";
            }
            saveTextAnim.start();
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
                        
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { from: 1.0; to: 0.4; duration: 1500; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 0.4; to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
                        }
                    }
                    Label {
                        text: "NC-KTV"
                        font.pixelSize: 22
                        font.bold: true
                        font.family: "Outfit"
                        color: rootWindow.colorTextPrimary
                    }
                    Label {
                        text: "v2.0 Professional"
                        font.pixelSize: 11
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

                    // Skip to Start (⏮)
                    Button {
                        id: btnPrev
                        flat: true
                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: timelineManager.currentPlayheadTime = 0
                        contentItem: Text {
                            text: "⏮"
                            color: btnPrev.hovered ? rootWindow.colorAccentViolet : rootWindow.colorTextPrimary
                            font.pixelSize: 16
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
                        onClicked: audioEngine.stop()
                        contentItem: Text {
                            text: "■"
                            color: btnStop.hovered ? rootWindow.colorAccentViolet : rootWindow.colorTextPrimary
                            font.pixelSize: 16
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
                            if (audioEngine.isPlaying) {
                                audioEngine.pause();
                            } else {
                                audioEngine.play();
                            }
                        }
                        contentItem: Text {
                            text: audioEngine.isPlaying ? "‖" : "▶"
                            color: rootWindow.colorAccentGreen
                            font.pixelSize: 18
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

                    // Skip to End (⏭)
                    Button {
                        id: btnNext
                        flat: true
                        implicitWidth: 32
                        implicitHeight: 32
                        onClicked: timelineManager.currentPlayheadTime = timelineManager.totalDuration
                        contentItem: Text {
                            text: "⏭"
                            color: btnNext.hovered ? rootWindow.colorAccentViolet : rootWindow.colorTextPrimary
                            font.pixelSize: 16
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
                            font.pixelSize: 14
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
                            font.pixelSize: 12
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
                        id: btnHelp
                        text: "?"
                        implicitWidth: 28
                        implicitHeight: 28
                        onClicked: shortcutsPopup.open()
                        contentItem: Text {
                            text: btnHelp.text
                            color: rootWindow.colorTextSecondary
                            font.bold: true
                            font.pixelSize: 12
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
                        id: btnSave
                        text: "Save Project"
                        onClicked: {
                            // Saving nctv project format
                            var filePath = "D:/Document/NC-Project/NC-KTV/NC-KTV_V2/project.nctv";
                            timelineManager.saveProject(filePath);
                            saveStatusText.text = "Project Saved!";
                            saveTextAnim.start();
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
                            var filePath = "D:/Document/NC-Project/NC-KTV/NC-KTV_V2/project.nctv";
                            if (timelineManager.loadProject(filePath)) {
                                saveStatusText.text = "Project Loaded!";
                            } else {
                                saveStatusText.text = "Load Failed (no saved project)";
                            }
                            saveTextAnim.start();
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
                        font.pixelSize: 11
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
                SplitView.preferredHeight: 320
                orientation: Qt.Horizontal

                // Media Library
                MediaBrowser {
                    id: mediaBrowser
                    SplitView.preferredWidth: 320
                    SplitView.minimumWidth: 200
                }

                // Center main timeline container / Preview Card
                Rectangle {
                    id: previewContainer
                    color: rootWindow.colorBgPitch
                    border.color: rootWindow.colorBorder
                    border.width: 1
                    SplitView.fillWidth: true

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
                        opacity: audioEngine.isPlaying ? 0.35 : 0.08
                        Behavior on opacity { NumberAnimation { duration: 500 } }
                        
                        property double timeVar: 0.0
                        
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            
                            if (audioEngine.isPlaying) {
                                timeVar += 0.15;
                            } else {
                                // Draw a beautiful grid design when stopped
                                ctx.strokeStyle = "#1A1A26";
                                ctx.lineWidth = 1;
                                var size = 20;
                                for(var x = 0; x < width; x += size) {
                                    ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, height); ctx.stroke();
                                }
                                for(var y = 0; y < height; y += size) {
                                    ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(width, y); ctx.stroke();
                                }
                                return;
                            }
                            
                            // Neon wave drawing
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
                                waveVal += (Math.random() - 0.5) * 4;
                                
                                if (i === 0) {
                                    ctx.moveTo(i, centerY + waveVal);
                                } else {
                                    ctx.lineTo(i, centerY + waveVal);
                                }
                            }
                            ctx.stroke();
                        }
                    }

                    // Watermark / Guide Text
                    Label {
                        anchors.top: parent.top
                        anchors.topMargin: 15
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "LIVE MASTER MONITOR"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 2
                        color: rootWindow.colorAccentViolet
                        opacity: 0.5
                    }

                    // Simulated live scrolling subtitle overlay
                    Column {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 25
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width - 40
                        spacing: 8

                        // Row 1: Active lyrics line
                        Item {
                            id: activeLineWrapper
                            width: parent.width
                            height: 36
                            
                            property var activeClip: {
                                var time = timelineManager.currentPlayheadTime;
                                for (var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                                    var track = timelineManager.trackListModel.tracks()[i];
                                    if (track && track.trackType === 2) { // Lyrics Track
                                        var clips = track.clips();
                                        for (var c = 0; c < clips.length; ++c) {
                                            var clip = clips[c];
                                            if (time >= clip.startTime && time <= clip.endTime) {
                                                return clip;
                                            }
                                        }
                                    }
                                }
                                return null;
                            }

                            property var nextClip: {
                                var time = timelineManager.currentPlayheadTime;
                                var bestClip = null;
                                for (var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                                    var track = timelineManager.trackListModel.tracks()[i];
                                    if (track && track.trackType === 2) { // Lyrics Track
                                        var clips = track.clips();
                                        for (var c = 0; c < clips.length; ++c) {
                                            var clip = clips[c];
                                            if (clip.startTime > time) {
                                                if (!bestClip || clip.startTime < bestClip.startTime) {
                                                    bestClip = clip;
                                                }
                                            }
                                        }
                                    }
                                }
                                return bestClip;
                            }

                            property double sweepProgress: {
                                if (!activeClip) return 0.0;
                                return rootWindow.calculateClipSweepProgress(activeClip, timelineManager.currentPlayheadTime);
                            }

                            // Base Inactive Text (Slate color)
                            Label {
                                id: baseTextLabel
                                text: activeLineWrapper.activeClip ? activeLineWrapper.activeClip.lyricText : (activeLineWrapper.nextClip ? "" : "(Waiting for lyric cues)")
                                font.pixelSize: 22
                                font.bold: true
                                color: "#4A4A5A"
                                style: Text.Outline
                                styleColor: "#08080A"
                                font.family: "Outfit"
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                            }

                            // Overlay glowing sweep text
                            Item {
                                anchors.left: baseTextLabel.left
                                anchors.top: baseTextLabel.top
                                height: baseTextLabel.height
                                width: activeLineWrapper.sweepProgress * baseTextLabel.width
                                clip: true

                                Label {
                                    text: baseTextLabel.text
                                    font.pixelSize: 22
                                    font.bold: true
                                    color: rootWindow.colorAccentGreen
                                    style: Text.Outline
                                    styleColor: "#08080A"
                                    font.family: "Outfit"
                                    width: baseTextLabel.width
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                }
                            }
                        }

                        // Row 2: Upcoming lookahead lyrics line (faint/smaller)
                        Label {
                            text: {
                                var nc = activeLineWrapper.nextClip;
                                return nc ? nc.lyricText : "";
                            }
                            font.pixelSize: 15
                            font.bold: true
                            color: "#8A8A9E"
                            opacity: activeLineWrapper.nextClip ? 0.4 : 0.0
                            style: Text.Outline
                            styleColor: "#08080A"
                            font.family: "Outfit"
                            anchors.horizontalCenter: parent.horizontalCenter
                            horizontalAlignment: Text.AlignHCenter
                            
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                        }
                    }
                }

                // Properties Panel Inspector
                PropertiesPanel {
                    id: propertiesPanel
                    SplitView.preferredWidth: 350
                    SplitView.minimumWidth: 200
                }
            }

            // Bottom Pane: Timeline Editor
            TimelineView {
                id: timelineView
                SplitView.fillHeight: true
                SplitView.minimumHeight: 200
            }
        }
    }

    ExportDialog {
        id: exportDialog
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
                    font.pixelSize: 15
                    font.bold: true
                    font.family: "Outfit"
                    color: "#F0F0F5"
                }
            }

            Label {
                text: "No AI stem separation model (.onnx) is currently selected. Select your Ultimate Vocal Remover 'models' folder to dynamically list all models, browse for a single model file, or proceed with real-time center-channel DSP extraction."
                font.pixelSize: 11
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
                            font.pixelSize: 11
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
                            font.pixelSize: 11
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
                            font.pixelSize: 11
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
                            font.pixelSize: 11
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
                    font.pixelSize: 15
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
                    font.pixelSize: 11
                }
                background: Rectangle {
                    color: btnCloseShortcuts.hovered ? "#8E5CFF" : rootWindow.colorAccentViolet
                    radius: 6
                }
            }
        }
    }
}


