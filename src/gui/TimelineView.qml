import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: timelineRoot
    color: rootWindow.colorBgPitch
    border.color: rootWindow.colorBorder
    border.width: 1

    // Global timeline zoom configuration (pixels per millisecond / microsecond)
    // Zoom factor: width in pixels of 1 second (1,000,000 microseconds)
    property double zoomFactor: 120.0 
    property bool compactTracks: false
    
    // Snapping configuration
    property bool snappingEnabled: true
    property double snapThresholdMs: 100.0 // 100 milliseconds threshold

    property real scrollX: timelineScroll.contentItem ? timelineScroll.contentItem.contentX : 0.0

    // Microsecond timing coordinates mapper (converted to rounded integer for qlonglong matching)
    function xToTime(x) {
        return Math.round((x / zoomFactor) * 1000000.0);
    }

    function timeToX(timeUs) {
        return (timeUs / 1000000.0) * zoomFactor;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Timeline Top Controls & Time ruler
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: rootWindow.colorBgPanel
            border.color: rootWindow.colorBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                spacing: 15

                Label {
                    text: "TRACKS TIMELINE"
                    font.bold: true
                    font.pixelSize: 11
                    color: rootWindow.colorTextSecondary
                }

                // Snap switch button
                Button {
                    id: btnSnapToggle
                    text: timelineRoot.snappingEnabled ? "SNAP ON" : "SNAP OFF"
                    implicitWidth: 80
                    implicitHeight: 22
                    onClicked: timelineRoot.snappingEnabled = !timelineRoot.snappingEnabled
                    background: Rectangle {
                        color: timelineRoot.snappingEnabled ? "#1F3320" : "#331F20"
                        radius: 3
                        border.color: timelineRoot.snappingEnabled ? rootWindow.colorAccentGreen : "#FF5252"
                    }
                    contentItem: Text {
                        text: btnSnapToggle.text
                        font.pixelSize: 9
                        font.bold: true
                        color: timelineRoot.snappingEnabled ? rootWindow.colorAccentGreen : "#FF5252"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Add Track operations
                Button {
                    id: btnAddAudio
                    text: "+ AUDIO TRACK"
                    implicitWidth: 100
                    implicitHeight: 22
                    onClicked: timelineManager.addTrack(0, "Audio " + (timelineManager.trackListModel.rowCount() + 1))
                    background: Rectangle {
                        color: btnAddAudio.hovered ? rootWindow.colorAccentViolet : rootWindow.colorBgCard
                        radius: 3
                        border.color: rootWindow.colorBorder
                    }
                    contentItem: Text {
                        text: btnAddAudio.text
                        font.pixelSize: 9
                        font.bold: true
                        color: rootWindow.colorTextPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: btnAddVideo
                    text: "+ VIDEO TRACK"
                    implicitWidth: 100
                    implicitHeight: 22
                    onClicked: timelineManager.addTrack(1, "Video " + (timelineManager.trackListModel.rowCount() + 1))
                    background: Rectangle {
                        color: btnAddVideo.hovered ? rootWindow.colorAccentViolet : rootWindow.colorBgCard
                        radius: 3
                        border.color: rootWindow.colorBorder
                    }
                    contentItem: Text {
                        text: btnAddVideo.text
                        font.pixelSize: 9
                        font.bold: true
                        color: rootWindow.colorTextPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: btnAddLyrics
                    text: "+ LYRICS TRACK"
                    implicitWidth: 100
                    implicitHeight: 22
                    onClicked: timelineManager.addTrack(2, "Lyrics " + (timelineManager.trackListModel.rowCount() + 1))
                    background: Rectangle {
                        color: btnAddLyrics.hovered ? rootWindow.colorAccentViolet : rootWindow.colorBgCard
                        radius: 3
                        border.color: rootWindow.colorBorder
                    }
                    contentItem: Text {
                        text: btnAddLyrics.text
                        font.pixelSize: 9
                        font.bold: true
                        color: rootWindow.colorTextPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    id: btnImportGlobalSrtLrc
                    text: "IMPORT SRT/LRC..."
                    implicitWidth: 110
                    implicitHeight: 22
                    onClicked: {
                        lyricFileDialog.targetTrackId = "";
                        lyricFileDialog.open();
                    }
                    background: Rectangle {
                        color: btnImportGlobalSrtLrc.hovered ? rootWindow.colorAccentViolet : rootWindow.colorBgCard
                        radius: 3
                        border.color: rootWindow.colorBorder
                    }
                    contentItem: Text {
                        text: btnImportGlobalSrtLrc.text
                        font.pixelSize: 9
                        font.bold: true
                        color: rootWindow.colorTextPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Spacer
                Item { Layout.fillWidth: true }

                // Compact track height toggle
                Button {
                    id: btnCompactToggle
                    text: timelineRoot.compactTracks ? "COMPACT LAYOUT" : "STANDARD LAYOUT"
                    implicitWidth: 110
                    implicitHeight: 22
                    onClicked: timelineRoot.compactTracks = !timelineRoot.compactTracks
                    background: Rectangle {
                        color: timelineRoot.compactTracks ? "#2D264A" : rootWindow.colorBgCard
                        radius: 3
                        border.color: timelineRoot.compactTracks ? rootWindow.colorAccentViolet : rootWindow.colorBorder
                    }
                    contentItem: Text {
                        text: btnCompactToggle.text
                        font.pixelSize: 9
                        font.bold: true
                        color: timelineRoot.compactTracks ? "#FFF" : rootWindow.colorTextSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Timeline Zoom Controls
                RowLayout {
                    spacing: 4
                    Label {
                        text: "Zoom"
                        color: rootWindow.colorTextSecondary
                        font.pixelSize: 11
                    }
                    
                    // Zoom Out Button
                    Button {
                        id: btnZoomOut
                        text: "➖"
                        implicitWidth: 20
                        implicitHeight: 20
                        onClicked: zoomFactor = Math.max(20.0, zoomFactor - 20.0)
                        background: Rectangle {
                            color: btnZoomOut.hovered ? "#222" : "transparent"
                            radius: 3
                        }
                        contentItem: Text {
                            text: btnZoomOut.text
                            font.pixelSize: 8
                            color: "#FFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Slider {
                        id: zoomSlider
                        from: 20
                        to: 500
                        value: zoomFactor
                        implicitWidth: 110
                        onMoved: zoomFactor = value
                    }

                    // Zoom In Button
                    Button {
                        id: btnZoomIn
                        text: "➕"
                        implicitWidth: 20
                        implicitHeight: 20
                        onClicked: zoomFactor = Math.min(500.0, zoomFactor + 20.0)
                        background: Rectangle {
                            color: btnZoomIn.hovered ? "#222" : "transparent"
                            radius: 3
                        }
                        contentItem: Text {
                            text: btnZoomIn.text
                            font.pixelSize: 8
                            color: "#FFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        // Main Scrolling Workspace
        ScrollView {
            id: timelineScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOn

            // Wrap inside clip area
            Item {
                implicitWidth: Math.max(timelineScroll.width, 180 + timeToX(timelineManager.totalDuration) + 300)
                implicitHeight: tracksColumn.implicitHeight + timeRuler.height + 50

                // Ruler Click / Scrub Canvas Area
                Rectangle {
                    id: timeRuler
                    width: parent.width
                    height: 28
                    color: "#0D0D11"
                    border.color: rootWindow.colorBorder
                    border.width: 1

                    // Draw ruler second markers dynamically using Canvas
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            // Draw solid background for the left track header area
                            ctx.fillStyle = rootWindow.colorBgCard;
                            ctx.fillRect(0, 0, 180, height);

                            ctx.strokeStyle = rootWindow.colorBorder;
                            ctx.fillStyle = rootWindow.colorTextSecondary;
                            ctx.font = "8px sans-serif";
                            ctx.lineWidth = 1;

                            // Draw a vertical divider separating the header block from the time ruler grid
                            ctx.beginPath();
                            ctx.moveTo(180, 0);
                            ctx.lineTo(180, height);
                            ctx.stroke();

                            // Draw seconds ticks starting at x = 180
                            var totalWidth = width;
                            var interval = zoomFactor; // 1 second intervals in pixels
                            
                            // Decide step size based on zoom level to prevent clutter
                            var step = 1;
                            if (zoomFactor < 40) step = 5;
                            else if (zoomFactor < 80) step = 2;

                            for (var x = 180; x < totalWidth; x += interval * step) {
                                var sec = Math.round((x - 180) / zoomFactor);
                                ctx.beginPath();
                                ctx.moveTo(x, 15);
                                ctx.lineTo(x, 28);
                                ctx.stroke();
                                ctx.fillText(sec + "s", x + 4, 25);
                            }
                        }
                    }

                    // Header cover for the ruler (stationary horizontally)
                    Rectangle {
                        x: timelineRoot.scrollX
                        y: 0
                        width: 180
                        height: parent.height
                        color: rootWindow.colorBgCard
                        border.color: rootWindow.colorBorder
                        border.width: 1
                        z: 6

                        Label {
                            anchors.centerIn: parent
                            text: "TRACKS"
                            font.bold: true
                            font.pixelSize: 10
                            color: rootWindow.colorTextSecondary
                        }
                    }

                    // Click or Drag gesture on the time ruler to scrub playhead (clamped to starting at x = 180 + contentX)
                    MouseArea {
                        anchors.fill: parent
                        onPressed: (mouse) => {
                            var posX = Math.max(180 + timelineRoot.scrollX, mouse.x);
                            var timeUs = xToTime(posX - 180);
                            timelineManager.currentPlayheadTime = Math.max(0, timeUs);
                        }
                        onPositionChanged: (mouse) => {
                            var posX = Math.max(180 + timelineRoot.scrollX, mouse.x);
                            var timeUs = xToTime(posX - 180);
                            timelineManager.currentPlayheadTime = Math.max(0, timeUs);
                        }
                    }
                }

                // Track Lanes vertical stack
                Column {
                    id: tracksColumn
                    anchors.top: timeRuler.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 1

                    Repeater {
                        model: timelineManager.trackListModel
                        delegate: TrackLane {
                            // Passed implicitly:
                            // trackObject role mapping the actual ncktv::Track C++ pointer
                            trackData: model.trackObject
                            trackName: model.trackName
                            trackType: model.trackType
                            trackMuted: model.trackMuted
                            trackLocked: model.trackLocked
                            zoom: zoomFactor
                            height: timelineRoot.compactTracks ? 60 : 90
                            scrollX: timelineRoot.scrollX
                        }
                    }
                }

                // Visual Playhead Line Indicator with smooth glide rendering
                Rectangle {
                    id: playheadLine
                    x: 180 + timeToX(timelineManager.currentPlayheadTime)
                    y: 0
                    width: 2
                    height: parent.height
                    color: rootWindow.colorAccentGreen
                    z: 4 // Render on top of clips (default z:0) but behind track headers (z:5) and ruler cover (z:6)

                    // Neon triangle cap
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        width: 10
                        height: 10
                        color: rootWindow.colorAccentGreen
                        rotation: 45
                    }
                }
            }
        }
    }
}
