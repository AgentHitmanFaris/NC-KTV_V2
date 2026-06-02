import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ncktv.core 1.0

Rectangle {
    id: trackLaneRoot
    width: parent ? parent.width : 1000
    height: 90
    color: (propertiesPanel.selectedTrack === trackLaneRoot.trackData) ? "#14141E" : rootWindow.colorBgPanel
    border.color: (propertiesPanel.selectedTrack === trackLaneRoot.trackData) ? rootWindow.colorAccentViolet : rootWindow.colorBorder
    border.width: (propertiesPanel.selectedTrack === trackLaneRoot.trackData) ? 2 : 1

    MouseArea {
        anchors.fill: parent
        z: -2
        onPressed: {
            propertiesPanel.selectedTrack = trackLaneRoot.trackData;
            propertiesPanel.selectedClip = null;
        }
    }

    property var trackData: null // C++ Track* pointer passed from parent
    property string trackName: ""
    property int trackType: 0 // 0 = Audio, 1 = Video, 2 = Lyrics
    property bool trackMuted: false
    property bool trackLocked: false
    property double zoom: 120.0
    property real scrollX: 0.0

    // ClipListModel bound specifically to this trackData
    ClipListModel {
        id: clipListModel
        track: trackLaneRoot.trackData
    }

        // 1. Left Track Header Controls Area (Stationary horizontally)
        Rectangle {
            id: trackHeader
            x: trackLaneRoot.scrollX
            y: 0
            width: 180
            height: parent.height
            z: 5
            color: rootWindow.colorBgCard
            border.color: rootWindow.colorBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: trackLaneRoot.height >= 70 ? 8 : 4
                spacing: trackLaneRoot.height >= 70 ? 4 : 1

                // Track Name Label
                RowLayout {
                    spacing: 4
                    Rectangle {
                        width: 4
                        height: 12
                        radius: 2
                        color: trackType === 0 ? rootWindow.colorAccentViolet : (trackType === 1 ? "#FFAB40" : rootWindow.colorAccentGreen)
                    }
                    Label {
                        text: trackName
                        font.bold: true
                        font.pixelSize: trackLaneRoot.height >= 70 ? 16 : 13
                        color: rootWindow.colorTextPrimary
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                // Track Type Tag
                Label {
                    text: trackType === 0 ? "AUDIO TRACK" : (trackType === 1 ? "VIDEO TRACK" : "LYRIC CUES")
                    font.pixelSize: 13
                    color: trackType === 0 ? rootWindow.colorTextSecondary : (trackType === 1 ? "#FFAB40" : rootWindow.colorAccentGreen)
                    visible: trackLaneRoot.height >= 70
                }

                RowLayout {
                    visible: trackType === 2 && trackLaneRoot.height >= 70
                    spacing: 6
                    Layout.fillWidth: true

                    Button {
                        id: btnAddCue
                        text: "+ CUE"
                        Layout.fillWidth: true
                        implicitHeight: 20
                        onClicked: {
                            if (trackData) {
                                var clipCount = trackData.clips().length;
                                var clipId = "clip_lyr_" + (clipCount + 1);
                                var startUs = timelineManager.currentPlayheadTime;
                                var durUs = 4000000; // 4 seconds default
                                var added = timelineManager.addClipToTrack(
                                    trackData.trackId,
                                    clipId,
                                    2, // Lyrics
                                    startUs,
                                    durUs,
                                    "",
                                    "New lyric cue line"
                                );
                                if (added) {
                                    propertiesPanel.selectedTrack = trackData;
                                    var clips = trackData.clips();
                                    for (var i = 0; i < clips.length; ++i) {
                                        if (clips[i].clipId === clipId) {
                                            propertiesPanel.selectedClip = clips[i];
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                        background: Rectangle {
                            color: btnAddCue.hovered ? "#1F352E" : "#14241F"
                            radius: 3
                            border.color: rootWindow.colorAccentGreen
                        }
                        contentItem: Text {
                            text: btnAddCue.text
                            font.bold: true
                            font.pixelSize: 13
                            color: rootWindow.colorAccentGreen
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        id: btnImportSrtLrc
                        text: "IMPORT"
                        Layout.fillWidth: true
                        implicitHeight: 20
                        onClicked: {
                            lyricFileDialog.targetTrackId = trackData.trackId;
                            lyricFileDialog.open();
                        }
                        background: Rectangle {
                            color: btnImportSrtLrc.hovered ? "#2C1E3A" : "#1B1324"
                            radius: 3
                            border.color: rootWindow.colorAccentViolet
                        }
                        contentItem: Text {
                            text: btnImportSrtLrc.text
                            font.bold: true
                            font.pixelSize: 13
                            color: rootWindow.colorAccentViolet
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                // Volume Slider (only for Audio track and if height is not compact)
                RowLayout {
                    visible: trackType === 0 && trackLaneRoot.height >= 65
                    spacing: 6
                    Layout.fillWidth: true
                    Label {
                        text: "Vol:"
                        font.pixelSize: 13
                        color: rootWindow.colorTextSecondary
                    }
                    Slider {
                        id: volSlider
                        Layout.fillWidth: true
                        from: 0.0
                        to: 1.0
                        value: trackData ? trackData.volume : 1.0
                        onMoved: {
                            if (trackData) {
                                trackData.volume = value;
                            }
                        }
                        background: Rectangle {
                            implicitHeight: 3
                            color: "#1B1B22"
                            radius: 1.5
                            Rectangle {
                                width: volSlider.visualPosition * parent.width
                                height: parent.height
                                color: rootWindow.colorAccentViolet
                                radius: 1.5
                            }
                        }
                        handle: Rectangle {
                            x: volSlider.visualPosition * (volSlider.width - width)
                            y: (volSlider.height - height) / 2
                            width: 8
                            height: 8
                            radius: 4
                            color: volSlider.hovered ? "#FFF" : rootWindow.colorAccentViolet
                        }
                    }
                }

                // Buttons: Mute / Lock / Delete
                RowLayout {
                    visible: trackLaneRoot.height >= 55
                    spacing: 6

                    // Mute Toggle Button
                    Button {
                        id: btnMute
                        implicitWidth: 32
                        implicitHeight: 22
                        checkable: true
                        checked: trackMuted
                        onClicked: {
                            if (trackData) {
                                trackData.isMuted = !trackData.isMuted;
                            }
                        }
                        background: Rectangle {
                            color: btnMute.checked ? "#EF5350" : "#2C2C35"
                            radius: 3
                            border.color: btnMute.checked ? "#E53935" : rootWindow.colorBorder
                        }
                        contentItem: Text {
                            text: "M"
                            font.bold: true
                            font.pixelSize: 13
                            color: btnMute.checked ? "#FFF" : rootWindow.colorTextSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Lock Toggle Button
                    Button {
                        id: btnLock
                        implicitWidth: 32
                        implicitHeight: 22
                        checkable: true
                        checked: trackLocked
                        onClicked: {
                            if (trackData) {
                                trackData.isLocked = !trackData.isLocked;
                            }
                        }
                        background: Rectangle {
                            color: btnLock.checked ? "#FFB74D" : "#2C2C35"
                            radius: 3
                            border.color: btnLock.checked ? "#F57C00" : rootWindow.colorBorder
                        }
                        contentItem: Text {
                            text: "L"
                            font.bold: true
                            font.pixelSize: 13
                            color: btnLock.checked ? "#000" : rootWindow.colorTextSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    // Delete Track Button
                    Button {
                        id: btnDelete
                        implicitWidth: 32
                        implicitHeight: 22
                        onClicked: {
                            if (trackData) {
                                timelineManager.removeTrack(trackData.trackId);
                            }
                        }
                        background: Rectangle {
                            color: btnDelete.hovered ? "#C62828" : "#2C2C35"
                            radius: 3
                            border.color: rootWindow.colorBorder
                        }
                        contentItem: Text {
                            text: "X"
                            font.bold: true
                            font.pixelSize: 13
                            color: btnDelete.hovered ? "#FFF" : rootWindow.colorTextSecondary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        // 2. Right Canvas Area: Render visual draggable clips (Scrolls horizontally)
        Item {
            id: trackGridArea
            x: 180
            y: 0
            width: Math.max(parent.width - 180, 0)
            height: parent.height
            clip: true

            // Grid guides rendering inside track
            Canvas {
                anchors.fill: parent
                z: -1
                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = "#1A1A22";
                    ctx.lineWidth = 0.5;

                    // Draw vertical guides matching seconds
                    var interval = zoom;
                    for (var x = 0; x < width; x += interval) {
                        ctx.beginPath();
                        ctx.moveTo(x, 0);
                        ctx.lineTo(x, height);
                        ctx.stroke();
                    }
                }
            }

            // Clips Repeater driven by ClipListModel
            Repeater {
                model: clipListModel
                delegate: ClipItem {
                    // Passed from ClipListModel:
                    // clipObject, clipId, clipType, clipStartTime, clipDuration, clipEndTime, clipSourceFile, clipLyricText
                    clipData: model.clipObject
                    parentTrack: trackLaneRoot.trackData
                    zoomFactor: trackLaneRoot.zoom
                }
            }
        }
    }
