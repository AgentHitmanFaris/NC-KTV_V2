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

                    // Stop
                    Button {
                        id: btnStop
                        flat: true
                        implicitWidth: 36
                        implicitHeight: 36
                        onClicked: audioEngine.stop()
                        contentItem: Text {
                            text: "■"
                            color: btnStop.hovered ? rootWindow.colorAccentViolet : rootWindow.colorTextPrimary
                            font.pixelSize: 18
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnStop.hovered ? "#222" : "transparent"
                            radius: 4
                        }
                    }

                    // Play/Pause
                    Button {
                        id: btnPlay
                        flat: true
                        implicitWidth: 44
                        implicitHeight: 44
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
                            font.pixelSize: 20
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: btnPlay.hovered ? "#1F352E" : "#14241F"
                            border.color: rootWindow.colorAccentGreen
                            border.width: btnPlay.hovered ? 1.5 : 1
                            radius: 22
                        }
                    }

                    // SMPTE Timecode visual display read from timelineManager
                    Rectangle {
                        color: "#050507"
                        border.color: rootWindow.colorBorder
                        radius: 6
                        width: 150
                        height: 36

                        Label {
                            anchors.centerIn: parent
                            text: timelineManager.formatTimecode(timelineManager.currentPlayheadTime)
                            color: rootWindow.colorAccentGreen
                            font.pixelSize: 16
                            font.family: "Courier New"
                            font.bold: true
                            font.letterSpacing: 1.5
                        }
                    }
                }

                Layout.alignment: Qt.AlignVCenter
                // Right side System status and action buttons
                RowLayout {
                    Layout.alignment: Qt.AlignRight
                    spacing: 12

                    Button {
                        id: btnSave
                        text: "Save Project"
                        onClicked: {
                            // Saving nctv project format
                            var filePath = "D:/Document/NC-Project/NC-KTV/NC-KTV_V2/project.nctv";
                            timelineManager.saveProject(filePath);
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
                    color: rootWindow.colorBgPitch
                    border.color: rootWindow.colorBorder
                    border.width: 1
                    SplitView.fillWidth: true

                    Label {
                        anchors.centerIn: parent
                        text: "Visual Preview / Live Lyrics Overlay"
                        font.pixelSize: 18
                        color: rootWindow.colorTextSecondary
                        font.family: "Inter"
                    }

                    // Simulated live scrolling subtitle overlay
                    Label {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 40
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            // Find active lyrics clip under the current playhead
                            var activeText = "";
                            var time = timelineManager.currentPlayheadTime;
                            
                            // Check tracks for active text
                            for(var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                                var track = timelineManager.trackListModel.tracks()[i];
                                if (track && track.trackType === 2) { // Lyrics Type
                                    for(var c = 0; c < track.clips().length; ++c) {
                                        var clip = track.clips()[c];
                                        if (time >= clip.startTime && time <= clip.endTime) {
                                            activeText = clip.lyricText;
                                            break;
                                        }
                                    }
                                }
                            }
                            return activeText !== "" ? activeText : "(Waiting for lyric cues)";
                        }
                        font.pixelSize: 26
                        font.bold: true
                        color: rootWindow.colorAccentGreen
                        style: Text.Outline
                        styleColor: "#000"
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
            
            mediaBrowser.addMediaFile(filename, path, isVideo ? "Video" : "Audio");
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
}

