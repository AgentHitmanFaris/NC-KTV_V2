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
    property int trackHeight: 90
    onTrackHeightChanged: compactTracks = (trackHeight <= 60)
    
    // Snapping configuration
    property bool snappingEnabled: true
    property double snapThresholdMs: 100.0 // 100 milliseconds threshold

    property real scrollX: timelineScroll.contentItem ? timelineScroll.contentItem.contentX : 0.0
    property real scrollY: timelineScroll.contentItem ? timelineScroll.contentItem.contentY : 0.0


    // Microsecond timing coordinates mapper (converted to rounded integer for qlonglong matching)
    function xToTime(x) {
        return Math.round((x / zoomFactor) * 1000000.0);
    }

    function timeToX(timeUs) {
        return (timeUs / 1000000.0) * zoomFactor;
    }

    Connections {
        target: timelineManager
        function onCurrentPlayheadTimeChanged() {
            if (audioEngine.isPlaying && timelineScroll.contentItem) {
                var playheadX = 180 + timeToX(timelineManager.currentPlayheadTime);
                var viewX = timelineScroll.contentItem.contentX;
                var viewW = timelineScroll.width;
                
                if (viewW > 180) {
                    // Scroll forward if playhead is near the right edge of viewport
                    if (playheadX > viewX + viewW - 50) {
                        var trackAreaWidth = viewW - 180;
                        var targetContentX = playheadX - 180 - (trackAreaWidth * 0.25);
                        var maxContentX = timelineScroll.contentItem.contentWidth - viewW;
                        timelineScroll.contentItem.contentX = Math.max(0, Math.min(targetContentX, maxContentX));
                    }
                    // Scroll backward if playhead is behind the visible tracks area (e.g. wrapped around or skipped back)
                    else if (playheadX < viewX + 180) {
                        var trackAreaWidth = viewW - 180;
                        var targetContentX = playheadX - 180 - (trackAreaWidth * 0.25);
                        var maxContentX = timelineScroll.contentItem.contentWidth - viewW;
                        timelineScroll.contentItem.contentX = Math.max(0, Math.min(targetContentX, maxContentX));
                    }
                }
            }
        }
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
                    font.pixelSize: 15
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
                        font.pixelSize: 13
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
                        font.pixelSize: 13
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
                        font.pixelSize: 13
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
                        font.pixelSize: 13
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
                        font.pixelSize: 13
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
                    onClicked: {
                        if (timelineRoot.trackHeight <= 60) {
                            timelineRoot.trackHeight = 90;
                        } else {
                            timelineRoot.trackHeight = 60;
                        }
                    }
                    background: Rectangle {
                        color: timelineRoot.compactTracks ? "#2D264A" : rootWindow.colorBgCard
                        radius: 3
                        border.color: timelineRoot.compactTracks ? rootWindow.colorAccentViolet : rootWindow.colorBorder
                    }
                    contentItem: Text {
                        text: btnCompactToggle.text
                        font.pixelSize: 13
                        font.bold: true
                        color: timelineRoot.compactTracks ? "#FFF" : rootWindow.colorTextSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                // Timeline Height Zoom Controls
                RowLayout {
                    spacing: 4
                    Label {
                        text: "Height"
                        color: rootWindow.colorTextSecondary
                        font.pixelSize: 15
                    }
                    
                    // Height Out Button
                    Button {
                        id: btnHeightOut
                        text: "-"
                        implicitWidth: 20
                        implicitHeight: 20
                        onClicked: timelineRoot.trackHeight = Math.max(40, timelineRoot.trackHeight - 10)
                        background: Rectangle {
                            color: btnHeightOut.hovered ? "#222" : "transparent"
                            radius: 3
                        }
                        contentItem: Text {
                            text: btnHeightOut.text
                            font.pixelSize: 12
                            color: "#FFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Slider {
                        id: heightSlider
                        from: 40
                        to: 200
                        value: timelineRoot.trackHeight
                        implicitWidth: 110
                        onMoved: timelineRoot.trackHeight = value
                    }

                    // Height In Button
                    Button {
                        id: btnHeightIn
                        text: "+"
                        implicitWidth: 20
                        implicitHeight: 20
                        onClicked: timelineRoot.trackHeight = Math.min(200, timelineRoot.trackHeight + 10)
                        background: Rectangle {
                            color: btnHeightIn.hovered ? "#222" : "transparent"
                            radius: 3
                        }
                        contentItem: Text {
                            text: btnHeightIn.text
                            font.pixelSize: 12
                            color: "#FFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                // Timeline Zoom Controls
                RowLayout {
                    spacing: 4
                    Label {
                        text: "Zoom"
                        color: rootWindow.colorTextSecondary
                        font.pixelSize: 15
                    }
                    
                    // Zoom Out Button
                    Button {
                        id: btnZoomOut
                        text: "-"
                        implicitWidth: 20
                        implicitHeight: 20
                        onClicked: zoomFactor = Math.max(20.0, zoomFactor - 20.0)
                        background: Rectangle {
                            color: btnZoomOut.hovered ? "#222" : "transparent"
                            radius: 3
                        }
                        contentItem: Text {
                            text: btnZoomOut.text
                            font.pixelSize: 12
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
                        text: "+"
                        implicitWidth: 20
                        implicitHeight: 20
                        onClicked: zoomFactor = Math.min(500.0, zoomFactor + 20.0)
                        background: Rectangle {
                            color: btnZoomIn.hovered ? "#222" : "transparent"
                            radius: 3
                        }
                        contentItem: Text {
                            text: btnZoomIn.text
                            font.pixelSize: 12
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

            WheelHandler {
                id: altWheelHandler
                acceptedModifiers: Qt.AltModifier
                onWheel: (event) => {
                    if (event.angleDelta.y > 0) {
                        timelineRoot.zoomFactor = Math.min(500.0, timelineRoot.zoomFactor + 20.0);
                    } else {
                        timelineRoot.zoomFactor = Math.max(20.0, timelineRoot.zoomFactor - 20.0);
                    }
                }
            }
            WheelHandler {
                id: ctrlWheelHandler
                acceptedModifiers: Qt.ControlModifier
                onWheel: (event) => {
                    if (event.angleDelta.y > 0) {
                        timelineRoot.trackHeight = Math.min(200, timelineRoot.trackHeight + 10);
                    } else {
                        timelineRoot.trackHeight = Math.max(40, timelineRoot.trackHeight - 10);
                    }
                }
            }
            WheelHandler {
                id: shiftWheelHandler
                acceptedModifiers: Qt.ShiftModifier
                onWheel: (event) => {
                    if (event.angleDelta.y > 0) {
                        timelineRoot.trackHeight = Math.min(200, timelineRoot.trackHeight + 10);
                    } else {
                        timelineRoot.trackHeight = Math.max(40, timelineRoot.trackHeight - 10);
                    }
                }
            }

            // Wrap inside clip area
            Item {
                implicitWidth: Math.max(timelineScroll.width, 180 + timeToX(timelineManager.totalDuration) + 300)
                implicitHeight: tracksColumn.implicitHeight + timeRuler.height + 50

                // Ruler Click / Scrub Canvas Area
                Rectangle {
                    id: timeRuler
                    width: parent.width
                    height: 28
                    y: timelineRoot.scrollY
                    z: 8
                    color: "#0D0D11"
                    border.color: rootWindow.colorBorder
                    border.width: 1


                    // Draw ruler second markers dynamically using Canvas
                    Canvas {
                        id: rulerCanvas
                        anchors.fill: parent
                        
                        // Repaint when zoom level changes
                        Connections {
                            target: timelineRoot
                            function onZoomFactorChanged() { rulerCanvas.requestPaint(); }
                        }
                        
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
                            font.pixelSize: 14
                            color: rootWindow.colorTextSecondary
                        }
                    }

                    // Click or Drag gesture on the time ruler to scrub playhead (clamped to starting at x = 180 + contentX)
                    MouseArea {
                        id: rulerScrubArea
                        anchors.fill: parent
                        preventStealing: true
                        hoverEnabled: true
                        cursorShape: containsPress ? Qt.ClosedHandCursor : (mouseX >= 180 + timelineRoot.scrollX ? Qt.PointingHandCursor : Qt.ArrowCursor)

                        property bool isDragging: false

                        onPressed: (mouse) => {
                            if (mouse.x < 180 + timelineRoot.scrollX) {
                                mouse.accepted = false;
                                return;
                            }
                            isDragging = true;
                            mouse.accepted = true;
                            scrub(mouse.x);
                        }
                        onPositionChanged: (mouse) => {
                            if (isDragging) {
                                scrub(mouse.x);
                            }
                        }
                        onReleased: {
                            isDragging = false;
                        }
                        onCanceled: {
                            isDragging = false;
                        }

                        function scrub(mouseX) {
                            var posX = Math.max(180 + timelineRoot.scrollX, mouseX);
                            var timeUs = xToTime(posX - 180);
                            timelineManager.currentPlayheadTime = Math.max(0, timeUs);
                        }
                    }

                    // Sequence Markers Overlay
                    Repeater {
                        model: timelineManager.markers
                        delegate: Item {
                            width: 14
                            height: 16
                            x: 180 + timeToX(modelData.timeUs) - width / 2
                            y: 0
                            z: 12

                            // Triangle flag rotated 45 degrees
                            Rectangle {
                                width: 10
                                height: 10
                                color: {
                                    if (modelData.color === "green") return "#00E676";
                                    if (modelData.color === "red") return "#FF5252";
                                    if (modelData.color === "blue") return "#29B6F6";
                                    if (modelData.color === "yellow") return "#FFCA28";
                                    return "#00E676";
                                }
                                rotation: 45
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: 1
                                border.color: "#FFF"
                                border.width: 1
                            }

                            // Little stem pointing down to tick
                            Rectangle {
                                width: 2
                                height: 6
                                color: "#FFF"
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                id: markerMouseArea

                                ToolTip.visible: containsMouse
                                ToolTip.text: modelData.name + " (" + timelineManager.formatTimecode(modelData.timeUs) + ")"
                                ToolTip.delay: 200

                                onClicked: {
                                    timelineManager.currentPlayheadTime = modelData.timeUs;
                                }
                                onDoubleClicked: {
                                    rootWindow.openMarkerDialog(modelData);
                                }
                            }
                        }
                    }
                }

                // Track Lanes vertical stack
                Column {
                    id: tracksColumn
                    y: 28
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
                            height: timelineRoot.trackHeight
                            scrollX: timelineRoot.scrollX
                        }
                    }
                }

                DropArea {
                    id: timelineDropArea
                    anchors.fill: tracksColumn
                    keys: ["text/uri-list"]
                    
                    onEntered: (drag) => {
                        if (drag.hasUrls) {
                            drag.accepted = true;
                        }
                    }
                    
                    onDropped: (drop) => {
                        if (drop.hasUrls) {
                            drop.accepted = true;
                            
                            var trackHeight = timelineRoot.trackHeight;
                            var spacing = 1;
                            var trackIdx = Math.floor(drop.y / (trackHeight + spacing));
                            
                            var trackCount = timelineManager.trackListModel.rowCount();
                            if (trackIdx < 0) trackIdx = 0;
                            if (trackIdx >= trackCount) trackIdx = trackCount - 1;
                            
                            var dropTimeUs = Math.max(0, xToTime(drop.x - 180));
                            
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
                                
                                var clipType = -1;
                                var trackTypeName = "";
                                if (extension === "srt" || extension === "lrc") {
                                    clipType = 2;
                                    trackTypeName = "Lyrics";
                                } else if (extension === "mp4" || extension === "mov" || extension === "avi" || extension === "mkv") {
                                    clipType = 1;
                                    trackTypeName = "Video";
                                } else if (extension === "wav" || extension === "mp3" || extension === "m4a" || extension === "ogg" || extension === "flac") {
                                    clipType = 0;
                                    trackTypeName = "Audio";
                                }
                                
                                if (clipType !== -1) {
                                    var targetTrack = null;
                                    if (trackIdx >= 0 && trackIdx < trackCount) {
                                        var t = timelineManager.trackListModel.tracks()[trackIdx];
                                        if (t && t.trackType === clipType) {
                                            targetTrack = t;
                                        }
                                    }
                                    
                                    if (!targetTrack) {
                                        for (var j = 0; j < trackCount; ++j) {
                                            var t = timelineManager.trackListModel.tracks()[j];
                                            if (t && t.trackType === clipType) {
                                                targetTrack = t;
                                                break;
                                            }
                                        }
                                    }
                                    
                                    var finalTrackId = "";
                                    if (targetTrack) {
                                        finalTrackId = targetTrack.trackId;
                                    } else {
                                        var newName = trackTypeName + " " + (trackCount + 1);
                                        finalTrackId = timelineManager.addTrack(clipType, newName);
                                    }
                                    
                                    if (finalTrackId !== "") {
                                        if (clipType === 2) {
                                            timelineManager.importLyricsFromFile(finalTrackId, url);
                                        } else {
                                            timelineManager.addClipToTrack(finalTrackId, "", clipType, dropTimeUs, 0, url);
                                        }
                                        rootWindow.importMediaFile(filename, url, trackTypeName, false);
                                    }
                                }
                            }
                        }
                    }
                }
                
                Rectangle {
                    anchors.fill: tracksColumn
                    color: "transparent"
                    border.color: rootWindow.colorAccentViolet
                    border.width: 2
                    opacity: timelineDropArea.containsDrag ? 0.8 : 0.0
                    z: 10
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }


                // Visual Playhead Line Indicator with smooth glide rendering
                Rectangle {
                    id: playheadLine
                    x: 180 + timeToX(timelineManager.currentPlayheadTime)
                    y: timelineRoot.scrollY
                    width: 2
                    height: timelineScroll.height
                    color: rootWindow.colorAccentGreen
                    z: 9
                    visible: x >= 180 + timelineRoot.scrollX


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
