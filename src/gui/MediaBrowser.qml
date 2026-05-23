import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: mediaBrowserRoot
    color: rootWindow.colorBgPanel
    border.color: rootWindow.colorBorder
    border.width: 1

    property int selectedMediaIdx: -1

    Connections {
        target: timelineManager
        function onMediaSeparationCompleted(vocalsPath, instPath) {
            var vocalsName = vocalsPath.substring(Math.max(vocalsPath.lastIndexOf('/'), vocalsPath.lastIndexOf('\\')) + 1);
            var instName = instPath.substring(Math.max(instPath.lastIndexOf('/'), instPath.lastIndexOf('\\')) + 1);
            mediaBrowserRoot.addMediaFile(vocalsName, vocalsPath, "Audio");
            mediaBrowserRoot.addMediaFile(instName, instPath, "Audio");
        }
    }

    function addMediaFile(name, path, type) {
        mockFilesModel.append({
            "name": name,
            "path": path,
            "type": type,
            "durationMs": 180000
        });
        selectedMediaIdx = mockFilesModel.count - 1;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Label {
                text: "MEDIA LIBRARY"
                font.bold: true
                font.pixelSize: 13
                color: rootWindow.colorTextPrimary
                Layout.fillWidth: true
            }

            Button {
                id: btnImportMedia
                text: "IMPORT MEDIA..."
                implicitWidth: 100
                implicitHeight: 24
                onClicked: mediaFileDialog.open()
                background: Rectangle {
                    color: btnImportMedia.hovered ? rootWindow.colorAccentViolet : "#222"
                    radius: 3
                    border.color: rootWindow.colorBorder
                }
                contentItem: Text {
                    text: btnImportMedia.text
                    font.bold: true
                    font.pixelSize: 9
                    color: "#FFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Mock files library list
        ListModel {
            id: mockFilesModel
        }

        // Empty State Placeholder
        Rectangle {
            id: emptyStateRect
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"
            visible: mockFilesModel.count === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 12
                width: parent.width - 40

                Label {
                    text: "📁"
                    font.pixelSize: 32
                    Layout.alignment: Qt.AlignCenter
                }

                Label {
                    text: "Media Library is Empty"
                    font.bold: true
                    font.pixelSize: 13
                    color: rootWindow.colorTextPrimary
                    Layout.alignment: Qt.AlignCenter
                }

                Label {
                    text: "Import audio backing tracks, vocals, or video guides to begin crafting your karaoke project."
                    font.pixelSize: 10
                    color: rootWindow.colorTextSecondary
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }

        ListView {
            id: fileListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: mockFilesModel
            clip: true
            spacing: 6
            visible: mockFilesModel.count > 0

            delegate: Rectangle {
                id: fileDelegate
                width: fileListView.width
                height: 52
                color: (mediaBrowserRoot.selectedMediaIdx === index) ? "#211B35" : (delegateHover.hovered ? rootWindow.colorBgCard : "#15151D")
                border.color: (mediaBrowserRoot.selectedMediaIdx === index) ? rootWindow.colorAccentGreen : (delegateHover.hovered ? rootWindow.colorAccentViolet : rootWindow.colorBorder)
                border.width: (mediaBrowserRoot.selectedMediaIdx === index) ? 2 : 1
                radius: 4

                HoverHandler { id: delegateHover }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 10

                    // Waveform/video indicator icon mock
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 4
                        color: type === "Audio" ? "#2C1E3A" : "#3A291E"
                        Label {
                            anchors.centerIn: parent
                            text: type === "Audio" ? "♫" : "🎬"
                            font.pixelSize: 14
                            color: type === "Audio" ? rootWindow.colorAccentViolet : "#FFAB40"
                        }
                    }

                    ColumnLayout {
                        spacing: 2
                        Label {
                            text: name
                            font.bold: true
                            font.pixelSize: 11
                            color: rootWindow.colorTextPrimary
                        }
                        Label {
                            text: (type === "Audio" ? "Audio" : "Video") + " - " + (durationMs ? (Math.floor(durationMs / 60000) + ":" + ("0" + Math.floor((durationMs % 60000) / 1000)).slice(-2)) : "3:00")
                            font.pixelSize: 9
                            color: rootWindow.colorTextSecondary
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Add Button
                    Button {
                        id: btnInsertClip
                        text: "ADD"
                        implicitWidth: 46
                        implicitHeight: 24
                        onClicked: {
                            // Find currently selected track in the properties panel
                            var track = propertiesPanel.selectedTrack;
                            if (!track) {
                                // Smart fallback: find first compatible track automatically
                                for (var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                                    var t = timelineManager.trackListModel.tracks()[i];
                                    if (type === "Video" || type === "Audio") {
                                        if (t.trackType === 0) { // Audio track
                                            track = t;
                                            break;
                                        }
                                    } else if (type === "Lyrics") {
                                        if (t.trackType === 2) { // Lyrics track
                                            track = t;
                                            break;
                                        }
                                    }
                                }

                                // Dynamic creation: if still no compatible track exists, create one!
                                if (!track) {
                                    if (type === "Video" || type === "Audio") {
                                        var newTrackId = timelineManager.addTrack(0, "Audio Track " + (timelineManager.trackListModel.rowCount() + 1));
                                        for (var j = 0; j < timelineManager.trackListModel.rowCount(); ++j) {
                                            var nt = timelineManager.trackListModel.tracks()[j];
                                            if (nt.trackId === newTrackId) {
                                                track = nt;
                                                break;
                                            }
                                        }
                                    } else if (type === "Lyrics") {
                                        var newLyrTrackId = timelineManager.addTrack(2, "Lyrics Track " + (timelineManager.trackListModel.rowCount() + 1));
                                        for (var k = 0; k < timelineManager.trackListModel.rowCount(); ++k) {
                                            var nlt = timelineManager.trackListModel.tracks()[k];
                                            if (nlt.trackId === newLyrTrackId) {
                                                track = nlt;
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                            if (track) {
                                var clipCount = track.clips().length;
                                var clipId = "clip_" + (clipCount + 1);
                                
                                // Insert clip at current playhead
                                var startUs = timelineManager.currentPlayheadTime;
                                var durUs = (track.trackType === 2) ? 4000000 : 0; // 0 lets C++ auto-detect the file length
                                
                                var added = timelineManager.addClipToTrack(
                                    track.trackId, 
                                    clipId, 
                                    track.trackType, 
                                    startUs, 
                                    durUs, 
                                    path, 
                                    track.trackType === 2 ? "New subtitle cue line" : ""
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
                                }
                            }
                        }
                        background: Rectangle {
                            color: btnInsertClip.hovered ? rootWindow.colorAccentViolet : "#222"
                            radius: 3
                            border.color: rootWindow.colorBorder
                        }
                        contentItem: Text {
                            text: btnInsertClip.text
                            font.bold: true
                            font.pixelSize: 9
                            color: "#FFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                MouseArea {
                    id: fileMouse
                    anchors.fill: parent
                    onClicked: {
                        mediaBrowserRoot.selectedMediaIdx = index;
                    }
                }
            }
        }

        // Sleek Premium AI Stem Separation interface card
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 175
            color: "#161224"
            border.color: rootWindow.colorAccentViolet
            border.width: 1
            radius: 6

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Label {
                    text: "AI STEM SEPARATION (ONNX)"
                    font.bold: true
                    font.pixelSize: 11
                    color: rootWindow.colorAccentViolet
                }

                Label {
                    text: "Separate audio into vocals & instrumentals instantly using ONNX GPU model acceleration."
                    font.pixelSize: 9
                    color: rootWindow.colorTextSecondary
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Label {
                        Layout.fillWidth: true
                        text: "Folder: " + (timelineManager.modelsDirPath !== "" ? 
                              (timelineManager.modelsDirPath.length > 25 ? "..." + timelineManager.modelsDirPath.substring(timelineManager.modelsDirPath.length - 22) : timelineManager.modelsDirPath) 
                              : "None")
                        font.pixelSize: 9
                        color: rootWindow.colorTextSecondary
                        elide: Text.ElideMiddle
                    }

                    Button {
                        id: btnSelectFolderMedia
                        text: "Folder..."
                        implicitWidth: 60
                        implicitHeight: 20
                        onClicked: modelFolderDialog.open()
                        background: Rectangle {
                            color: btnSelectFolderMedia.hovered ? "#2D264A" : "#1B1B22"
                            radius: 3
                            border.color: rootWindow.colorAccentViolet
                            border.width: 1
                        }
                        contentItem: Text {
                            text: btnSelectFolderMedia.text
                            font.bold: true
                            font.pixelSize: 8
                            color: "#FFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: timelineManager.discoveredModels.length > 0

                    Label {
                        text: "Model:"
                        font.pixelSize: 9
                        font.bold: true
                        color: rootWindow.colorTextSecondary
                        Layout.alignment: Qt.AlignVCenter
                    }

                    ComboBox {
                        id: modelComboMedia
                        Layout.fillWidth: true
                        model: timelineManager.discoveredModels
                        currentIndex: {
                            var idx = timelineManager.discoveredModelPaths.indexOf(timelineManager.modelPath);
                            return idx !== -1 ? idx : 0;
                        }
                        onActivated: (index) => {
                            timelineManager.modelPath = timelineManager.discoveredModelPaths[index];
                        }
                        
                        delegate: ItemDelegate {
                            width: modelComboMedia.width
                            contentItem: Text {
                                text: modelData
                                color: highlighted ? "#FFF" : "#8A8A9E"
                                font.bold: highlighted
                                font.pixelSize: 9
                                font.family: "Outfit"
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                color: highlighted ? "#2D264A" : "#111115"
                            }
                        }

                        contentItem: Text {
                            leftPadding: 6
                            rightPadding: 20
                            text: modelComboMedia.currentText
                            font.pixelSize: 9
                            font.bold: true
                            font.family: "Outfit"
                            color: rootWindow.colorAccentGreen
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideMiddle
                        }

                        background: Rectangle {
                            implicitHeight: 22
                            color: "#16161C"
                            border.color: "#2C2C3A"
                            border.width: 1
                            radius: 4
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: timelineManager.discoveredModels.length === 0

                    Label {
                        Layout.fillWidth: true
                        text: "No models found (DSP Fallback)"
                        font.pixelSize: 9
                        font.bold: true
                        color: "#E57373"
                        elide: Text.ElideMiddle
                    }

                    Button {
                        id: btnSelectFileMedia
                        text: "File..."
                        implicitWidth: 60
                        implicitHeight: 20
                        onClicked: modelFileDialog.open()
                        background: Rectangle {
                            color: btnSelectFileMedia.hovered ? "#2D264A" : "#1B1B22"
                            radius: 3
                            border.color: rootWindow.colorAccentViolet
                            border.width: 1
                        }
                        contentItem: Text {
                            text: btnSelectFileMedia.text
                            font.bold: true
                            font.pixelSize: 8
                            color: "#FFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Button {
                    id: btnProcessAI
                    text: {
                        if (timelineManager.isSeparating) {
                            return "SEPARATING STEMS...";
                        }
                        if (propertiesPanel.selectedClip && propertiesPanel.selectedClip.clipType === 0) {
                            return "PROCESS SELECTED TIMELINE CLIP";
                        }
                        if (mediaBrowserRoot.selectedMediaIdx !== -1) {
                            return "PROCESS SELECTED MEDIA";
                        }
                        return "PROCESS SELECTED CLIP";
                    }
                    Layout.fillWidth: true
                    implicitHeight: 32
                    enabled: !timelineManager.isSeparating && (
                        (propertiesPanel.selectedClip && propertiesPanel.selectedClip.clipType === 0) ||
                        (mediaBrowserRoot.selectedMediaIdx !== -1)
                    )
                    onClicked: {
                        if (propertiesPanel.selectedClip && propertiesPanel.selectedClip.clipType === 0) {
                            if (timelineManager.modelPath === "") {
                                modelSelectionPopup.pendingClipId = propertiesPanel.selectedClip.clipId;
                                modelSelectionPopup.pendingFilePath = "";
                                modelSelectionPopup.open();
                            } else {
                                timelineManager.separateStems(propertiesPanel.selectedClip.clipId);
                            }
                        } else if (mediaBrowserRoot.selectedMediaIdx !== -1) {
                            var path = mockFilesModel.get(mediaBrowserRoot.selectedMediaIdx).path;
                            if (timelineManager.modelPath === "") {
                                modelSelectionPopup.pendingClipId = "";
                                modelSelectionPopup.pendingFilePath = path;
                                modelSelectionPopup.open();
                            } else {
                                timelineManager.separateStemsForFile(path);
                            }
                        }
                    }
                    background: Rectangle {
                        color: btnProcessAI.enabled ? (btnProcessAI.hovered ? rootWindow.colorAccentViolet : "#7C4DFF") : "#333"
                        radius: 4
                        border.color: btnProcessAI.enabled ? "#A27FFF" : "#222"
                    }
                    contentItem: Text {
                        text: btnProcessAI.text
                        font.bold: true
                        font.pixelSize: 10
                        color: btnProcessAI.enabled ? "#FFF" : "#666"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                ProgressBar {
                    id: aiProgress
                    Layout.fillWidth: true
                    implicitHeight: 4
                    value: timelineManager.separationProgress
                    visible: timelineManager.isSeparating || timelineManager.separationProgress > 0

                    background: Rectangle {
                        color: "#2C203E"
                        radius: 2
                    }
                    contentItem: Item {
                        Rectangle {
                            width: aiProgress.visualPosition * parent.width
                            height: parent.height
                            radius: 2
                            color: rootWindow.colorAccentGreen
                        }
                    }
                }
            }
        }
    }
}
