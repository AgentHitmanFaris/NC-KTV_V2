import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: propsPanelRoot
    color: rootWindow.colorBgPanel
    border.color: rootWindow.colorBorder
    border.width: 1

    property var selectedClip: null // C++ Clip* pointer
    property var selectedTrack: null // C++ Track* pointer

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        Label {
            text: "PROPERTIES INSPECTOR"
            font.bold: true
            font.pixelSize: 13
            color: rootWindow.colorTextPrimary
        }

        // State 1: No Clip selected
        Rectangle {
            visible: propsPanelRoot.selectedClip === null
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "transparent"

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10
                Label {
                    text: "No clip selected"
                    font.pixelSize: 14
                    color: rootWindow.colorTextSecondary
                    horizontalAlignment: Text.AlignHCenter
                }
                Label {
                    text: "Select any clip on the timeline lanes\nto edit parameters, trim durations,\nor synchronize lyrics cues."
                    font.pixelSize: 10
                    color: "#555565"
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // State 2: Clip details active
        ScrollView {
            visible: propsPanelRoot.selectedClip !== null
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ColumnLayout {
                width: parent.width - 15
                spacing: 16

                // Clip Basics Info Card
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 90
                    color: rootWindow.colorBgCard
                    border.color: rootWindow.colorBorder
                    radius: 4

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Label {
                            text: "CLIP ID: " + (selectedClip ? selectedClip.clipId : "")
                            font.bold: true
                            font.pixelSize: 11
                            color: rootWindow.colorAccentViolet
                        }

                        Label {
                            text: "TYPE: " + (selectedClip ? (selectedClip.clipType === 0 ? "Audio Clip" : "Lyric subtitle") : "")
                            font.pixelSize: 10
                            color: rootWindow.colorTextSecondary
                        }

                        Label {
                            text: "TRACK ID: " + (selectedTrack ? selectedTrack.trackId : "")
                            font.pixelSize: 10
                            color: rootWindow.colorTextSecondary
                        }
                    }
                }

                // Timing Trimmers Section
                Label {
                    text: "TIMING COORDINATES"
                    font.bold: true
                    font.pixelSize: 10
                    color: rootWindow.colorTextSecondary
                }

                RowLayout {
                    spacing: 10
                    Label { text: "Start:"; font.pixelSize: 11; color: rootWindow.colorTextPrimary; Layout.preferredWidth: 60 }
                    Label {
                        text: selectedClip ? timelineManager.formatTimecode(selectedClip.startTime) : "00:00:00:00"
                        font.pixelSize: 11
                        font.bold: true
                        color: rootWindow.colorAccentGreen
                        font.family: "Courier New"
                    }
                }

                RowLayout {
                    spacing: 10
                    Label { text: "Duration:"; font.pixelSize: 11; color: rootWindow.colorTextPrimary; Layout.preferredWidth: 60 }
                    Label {
                        text: selectedClip ? timelineManager.formatTimecode(selectedClip.duration) : "00:00:00:00"
                        font.pixelSize: 11
                        font.bold: true
                        color: rootWindow.colorAccentGreen
                        font.family: "Courier New"
                    }
                }

                RowLayout {
                    spacing: 10
                    Label { text: "End:"; font.pixelSize: 11; color: rootWindow.colorTextPrimary; Layout.preferredWidth: 60 }
                    Label {
                        text: selectedClip ? timelineManager.formatTimecode(selectedClip.endTime) : "00:00:00:00"
                        font.pixelSize: 11
                        font.bold: true
                        color: rootWindow.colorAccentGreen
                        font.family: "Courier New"
                    }
                }

                // Lyric sync editor block (only visible for lyrics type clips)
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: selectedClip ? selectedClip.clipType === 2 : false
                    spacing: 8

                    Label {
                        text: "LYRICS TEXT CUE"
                        font.bold: true
                        font.pixelSize: 10
                        color: rootWindow.colorTextSecondary
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 80
                        color: rootWindow.colorBgCard
                        border.color: rootWindow.colorBorder
                        radius: 4

                        TextArea {
                            id: txtLyricField
                            anchors.fill: parent
                            anchors.margins: 6
                            text: selectedClip ? selectedClip.lyricText : ""
                            color: rootWindow.colorTextPrimary
                            font.pixelSize: 12
                            wrapMode: TextArea.Wrap
                            placeholderText: "Enter lyric line text..."
                            placeholderTextColor: "#444"
                            background: null

                            onTextEdited: {
                                if (selectedClip) {
                                    selectedClip.lyricText = text;
                                }
                            }
                        }
                    }

                    Label {
                        text: "💡 Timing tip: Type standard text to auto-distribute syllable timings, or enter LRC tags (e.g. '<0:05.20>Hello <0:06.10>World') for precision glowing sweeps."
                        font.pixelSize: 8
                        color: "#8A8A9E"
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }

                // Syllable Timing Inspector (only visible for lyrics type clips)
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: selectedClip ? selectedClip.clipType === 2 : false
                    spacing: 8

                    Label {
                        text: "SYLLABLE TIMING TUNER"
                        font.bold: true
                        font.pixelSize: 10
                        color: rootWindow.colorTextSecondary
                    }

                    // Syllable List container
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 180
                        color: rootWindow.colorBgCard
                        border.color: rootWindow.colorBorder
                        radius: 4
                        
                        ListView {
                            id: sylListView
                            anchors.fill: parent
                            anchors.margins: 6
                            model: selectedClip ? selectedClip.syllables : []
                            clip: true
                            spacing: 4
                            
                            delegate: Rectangle {
                                width: sylListView.width - 12
                                height: 36
                                color: "#16161D"
                                border.color: rootWindow.colorBorder
                                radius: 4
                                
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 8
                                    
                                    // Word Text
                                    Label {
                                        text: modelData.text.trim()
                                        font.bold: true
                                        font.pixelSize: 11
                                        color: "#FFF"
                                        Layout.preferredWidth: 80
                                        elide: Text.ElideRight
                                    }
                                    
                                    // Offset display
                                    Label {
                                        text: (modelData.relativeStart / 1000000.0).toFixed(2) + "s"
                                        font.pixelSize: 9
                                        color: rootWindow.colorAccentGreen
                                        font.family: "Courier New"
                                        Layout.preferredWidth: 40
                                    }
                                    
                                    // Shift Start buttons
                                    RowLayout {
                                        spacing: 2
                                        Button {
                                            text: "Start -"
                                            implicitWidth: 38
                                            implicitHeight: 18
                                            onClicked: {
                                                var newStart = Math.max(0, modelData.relativeStart - 50000); // shift 50ms earlier
                                                selectedClip.updateSyllable(index, newStart, modelData.duration);
                                            }
                                            background: Rectangle { color: "#222"; radius: 2 }
                                            contentItem: Text { text: "-50ms"; font.pixelSize: 7; color: "#F0F0F5"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        }
                                        Button {
                                            text: "Start +"
                                            implicitWidth: 38
                                            implicitHeight: 18
                                            onClicked: {
                                                var newStart = modelData.relativeStart + 50000; // shift 50ms later
                                                selectedClip.updateSyllable(index, newStart, modelData.duration);
                                            }
                                            background: Rectangle { color: "#222"; radius: 2 }
                                            contentItem: Text { text: "+50ms"; font.pixelSize: 7; color: "#F0F0F5"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        }
                                    }
                                    
                                    // Duration display
                                    Label {
                                        text: (modelData.duration / 1000000.0).toFixed(2) + "s"
                                        font.pixelSize: 9
                                        color: rootWindow.colorAccentGreen
                                        font.family: "Courier New"
                                        Layout.preferredWidth: 40
                                    }

                                    // Duration Adjust buttons
                                    RowLayout {
                                        spacing: 2
                                        Button {
                                            text: "Dur -"
                                            implicitWidth: 38
                                            implicitHeight: 18
                                            onClicked: {
                                                var newDur = Math.max(100000, modelData.duration - 50000); // decrease 50ms
                                                selectedClip.updateSyllable(index, modelData.relativeStart, newDur);
                                            }
                                            background: Rectangle { color: "#222"; radius: 2 }
                                            contentItem: Text { text: "-50ms"; font.pixelSize: 7; color: "#F0F0F5"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        }
                                        Button {
                                            text: "Dur +"
                                            implicitWidth: 38
                                            implicitHeight: 18
                                            onClicked: {
                                                var newDur = modelData.duration + 50000; // increase 50ms
                                                selectedClip.updateSyllable(index, modelData.relativeStart, newDur);
                                            }
                                            background: Rectangle { color: "#222"; radius: 2 }
                                            contentItem: Text { text: "+50ms"; font.pixelSize: 7; color: "#F0F0F5"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Audio source file info
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: selectedClip ? selectedClip.clipType === 0 : false
                    spacing: 6

                    Label {
                        text: "AUDIO SOURCE FILE"
                        font.bold: true
                        font.pixelSize: 10
                        color: rootWindow.colorTextSecondary
                    }

                    Label {
                        text: selectedClip ? selectedClip.sourceFile : ""
                        font.pixelSize: 9
                        color: rootWindow.colorTextSecondary
                        wrapMode: Text.WrapAnywhere
                        Layout.fillWidth: true
                    }
                }

                // AI Stem Separation Action Block
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: selectedClip ? selectedClip.clipType === 0 : false
                    spacing: 10

                    Label {
                        text: "AI STEM SEPARATION"
                        font.bold: true
                        font.pixelSize: 10
                        color: rootWindow.colorTextSecondary
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
                            id: btnSelectFolderProp
                            text: "Folder..."
                            implicitWidth: 60
                            implicitHeight: 20
                            onClicked: modelFolderDialog.open()
                            background: Rectangle {
                                color: btnSelectFolderProp.hovered ? "#2D264A" : "#1B1B22"
                                radius: 3
                                border.color: rootWindow.colorAccentViolet
                                border.width: 1
                            }
                            contentItem: Text {
                                text: btnSelectFolderProp.text
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
                            id: modelComboProp
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
                                width: modelComboProp.width
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
                                text: modelComboProp.currentText
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
                            id: btnSelectFileProp
                            text: "File..."
                            implicitWidth: 60
                            implicitHeight: 20
                            onClicked: modelFileDialog.open()
                            background: Rectangle {
                                color: btnSelectFileProp.hovered ? "#2D264A" : "#1B1B22"
                                radius: 3
                                border.color: rootWindow.colorAccentViolet
                                border.width: 1
                            }
                            contentItem: Text {
                                text: btnSelectFileProp.text
                                font.bold: true
                                font.pixelSize: 8
                                color: "#FFF"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    Button {
                        id: btnSeparateStems
                        text: timelineManager.isSeparating ? "SEPARATING STEMS..." : "SEPARATE VOCAL & INSTRUMENTAL"
                        Layout.fillWidth: true
                        implicitHeight: 36
                        enabled: selectedClip && !timelineManager.isSeparating
                        onClicked: {
                            if (selectedClip) {
                                if (timelineManager.modelPath === "") {
                                    modelSelectionPopup.pendingClipId = selectedClip.clipId;
                                    modelSelectionPopup.pendingFilePath = "";
                                    modelSelectionPopup.open();
                                } else {
                                    timelineManager.separateStems(selectedClip.clipId);
                                }
                            }
                        }
                        background: Rectangle {
                            color: btnSeparateStems.enabled ? 
                                   (btnSeparateStems.hovered ? "#3F51B5" : "#1A237E") : 
                                   "#111"
                            radius: 4
                            border.color: btnSeparateStems.enabled ? "#3F51B5" : "#222"
                        }
                        contentItem: Text {
                            text: btnSeparateStems.text
                            font.bold: true
                            font.pixelSize: 9
                            color: btnSeparateStems.enabled ? "#FFF" : "#666"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Separation Progress UI
                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: timelineManager.isSeparating || timelineManager.separationProgress > 0
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: timelineManager.separationStatusText
                                font.pixelSize: 9
                                color: rootWindow.colorTextSecondary
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                            }
                            Label {
                                text: Math.round(timelineManager.separationProgress * 100) + "%"
                                font.pixelSize: 9
                                font.bold: true
                                color: rootWindow.colorAccentGreen
                            }
                        }

                        // Premium Shimmering Progress Bar
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 6
                            color: "#1A1A24"
                            radius: 3
                            clip: true

                            Rectangle {
                                id: progressBarFill
                                width: parent.width * timelineManager.separationProgress
                                height: parent.height
                                radius: 3

                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: rootWindow.colorAccentViolet }
                                    GradientStop { position: 0.5; color: "#00E5FF" }
                                    GradientStop { position: 1.0; color: rootWindow.colorAccentGreen }
                                }
                            }
                        }
                    }
                }

                // Actions: Split & Delete
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    // Split
                    Button {
                        id: btnSplitClip
                        text: "SPLIT CLIP AT PLAYHEAD"
                        Layout.fillWidth: true
                        implicitHeight: 32
                        enabled: selectedClip ? timelineManager.currentPlayheadTime > selectedClip.startTime && timelineManager.currentPlayheadTime < selectedClip.endTime : false
                        onClicked: {
                            if (selectedTrack && selectedClip) {
                                var splitTime = timelineManager.currentPlayheadTime;
                                var success = timelineManager.splitClip(selectedTrack.trackId, selectedClip.clipId, splitTime);
                                if (success) {
                                    // Reset selected
                                    propsPanelRoot.selectedClip = null;
                                }
                            }
                        }
                        background: Rectangle {
                            color: btnSplitClip.enabled ? (btnSplitClip.hovered ? rootWindow.colorAccentViolet : "#3A335E") : "#222"
                            radius: 4
                            border.color: btnSplitClip.enabled ? rootWindow.colorAccentViolet : "#333"
                        }
                        contentItem: Text {
                            text: btnSplitClip.text
                            font.bold: true
                            font.pixelSize: 9
                            color: btnSplitClip.enabled ? "#FFF" : "#555"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Delete
                    Button {
                        id: btnDeleteClip
                        text: "DELETE SELECTED CLIP"
                        Layout.fillWidth: true
                        implicitHeight: 32
                        onClicked: {
                            if (selectedTrack && selectedClip) {
                                var deleted = selectedTrack.removeClip(selectedClip.clipId);
                                if (deleted) {
                                    propsPanelRoot.selectedClip = null;
                                }
                            }
                        }
                        background: Rectangle {
                            color: btnDeleteClip.hovered ? "#C62828" : "#2D2222"
                            radius: 4
                            border.color: "#C62828"
                        }
                        contentItem: Text {
                            text: btnDeleteClip.text
                            font.bold: true
                            font.pixelSize: 9
                            color: "#EF5350"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
