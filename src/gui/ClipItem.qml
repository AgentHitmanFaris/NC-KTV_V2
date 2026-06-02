import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ncktv.core 1.0

Rectangle {
    id: clipItemRoot
    
    // Position and size calculations based on microsecond properties
    x: (clipData ? clipData.startTime / 1000000.0 : 0.0) * zoomFactor
    width: (clipData ? clipData.duration / 1000000.0 : 1.0) * zoomFactor
    height: parent ? parent.height - 16 : 74
    anchors.verticalCenter: parent.verticalCenter
    radius: 6

    // Model properties
    property var clipData: null // C++ Clip* pointer passed from parent track lane
    property var parentTrack: null // C++ Track* pointer passed from parent
    property double zoomFactor: 120.0

    // Design states
    property bool isSelected: propertiesPanel.selectedClip === clipItemRoot.clipData
    property bool isActiveManipulating: dragArea.isDragging || dragLeftArea.pressed || dragRightArea.pressed
    
    color: {
        if (!clipData) return "#2A2A35";
        if (isSelected) {
            return clipData.clipType === 0 ? "#25183E" : "#302210";
        }
        return clipData.clipType === 0 ? "#0E0A18" : "#121216";
    }
    opacity: clipItemRoot.hovered || isSelected ? 0.95 : 0.75
    border.color: {
        if (isSelected) return "#FFFFFF";
        return clipData && clipData.clipType === 0 ? "#7C4DFF" : "#FFB300";
    }
    border.width: isSelected ? 2 : 1

    Behavior on opacity { NumberAnimation { duration: 100 } }

    // Hover effect
    property bool hovered: false
    HoverHandler {
        onHoveredChanged: clipItemRoot.hovered = hovered
    }

    // Custom C++ Waveform Renderer for Audio Tracks (clipType = 0)
    WaveformRenderer {
        id: audioWaveform
        anchors.fill: parent
        anchors.margins: 4
        sourceFile: clipData && clipData.clipType === 0 ? clipData.sourceFile : ""
        sourceStart: clipData && clipData.clipType === 0 ? clipData.sourceStart : 0
        duration: clipData && clipData.clipType === 0 ? clipData.duration : 0
        visible: clipData && clipData.clipType === 0
        opacity: 0.8
    }

    // Progressive Syllable-Level Karaoke Sweep for Lyric Tracks (clipType = 2)
    // Only compute when the playhead is actually inside this clip's time range
    property double sweepProgress: {
        if (!clipData || clipData.clipType !== 2) return 0.0;
        var t = timelineManager.currentPlayheadTime;
        if (t < clipData.startTime || t >= clipData.endTime) {
            return t >= clipData.endTime ? 1.0 : 0.0;
        }
        return rootWindow.calculateClipSweepProgress(clipData, t);
    }

    // Clip label details and UI Layout
    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 2

        Label {
            text: clipData ? clipData.clipId : ""
            font.bold: true
            font.pixelSize: 14
            color: "#8E8E9E"
            elide: Text.ElideRight
            width: parent.width
        }

        // Display Source File name if Audio, else dynamic dual-text sweep if Lyrics
        Item {
            width: parent.width
            height: 40

            // 1. Audio Layout: Render File Name Label
            Label {
                text: {
                    if (!clipData || clipData.clipType !== 0) return "";
                    var path = clipData.sourceFile;
                    return path.substring(path.lastIndexOf("/") + 1);
                }
                visible: clipData && clipData.clipType === 0
                font.pixelSize: 14
                font.bold: true
                color: "#FFFFFF"
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
            }

            // 2. Lyrics Layout: Flagship Progressive sweep text overlay
            Item {
                id: lyricsContainer
                anchors.fill: parent
                visible: clipData && clipData.clipType === 2

                // Background Inactive Subtitles (Slate Gray)
                Label {
                    id: bgLyricLabel
                    text: clipData && clipData.clipType === 2 ? clipData.lyricText : ""
                    font.pixelSize: 17
                    font.bold: true
                    color: "#5A5A6C"
                    elide: Text.ElideRight
                    anchors.centerIn: parent
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                }

                // Clipping Foreground overlay container (Neon Green active sweep)
                Item {
                    id: foregroundClippingContainer
                    anchors.left: bgLyricLabel.left
                    anchors.top: bgLyricLabel.top
                    height: bgLyricLabel.height
                    width: clipItemRoot.sweepProgress * bgLyricLabel.width
                    clip: true

                    Label {
                        text: bgLyricLabel.text
                        font.pixelSize: 17
                        font.bold: true
                        color: "#00E676" // Fluent active Karaoke neon green
                        width: bgLyricLabel.width
                        anchors.left: parent.left
                        anchors.top: parent.top
                    }
                }
            }
        }
    }

    // Selection handled by dragArea onPressed below

    // Horizontal dragging with snap & collision checks (offloaded to QML's native drag target for 60fps performance)
    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        cursorShape: Qt.SizeAll

        drag.target: clipItemRoot
        drag.axis: Drag.XAxis

        onPressed: (mouse) => {
            if (parentTrack && parentTrack.isLocked) {
                mouse.accepted = false;
                return;
            }
            propertiesPanel.selectedClip = clipItemRoot.clipData;
            propertiesPanel.selectedTrack = clipItemRoot.parentTrack;
        }

        onReleased: {
            if (!clipData) return;
            
            // Calculate target start time from the final drag position
            var targetStartTimeUs = (clipItemRoot.x / zoomFactor) * 1000000.0;
            if (targetStartTimeUs < 0) targetStartTimeUs = 0;

            // 1. Snapping engine calculations
            if (timelineView.snappingEnabled) {
                var thresholdUs = timelineView.snapThresholdMs * 1000.0;
                targetStartTimeUs = timelineManager.checkSnapping(clipData.clipId, targetStartTimeUs, thresholdUs);
            }

            // 2. Overlap/Collision blocking
            if (parentTrack) {
                targetStartTimeUs = timelineManager.checkCollisions(parentTrack.trackId, clipData.clipId, targetStartTimeUs);
            }

            // Write change back to C++ model (triggers track update)
            clipData.startTime = Math.round(targetStartTimeUs);
            timelineManager.setDirty();
            
            // Restore coordinate binding to sync future updates automatically
            clipItemRoot.x = Qt.binding(function() { 
                return (clipData ? clipData.startTime / 1000000.0 : 0.0) * zoomFactor; 
            });
        }
    }

    // Left Resizing Trimmer Handle
    Rectangle {
        width: 6
        height: parent.height
        anchors.left: parent.left
        color: dragLeftArea.pressed ? "#FFF" : Qt.darker(border.color, 1.3)
        radius: 3
        visible: parentTrack ? !parentTrack.isLocked : true

        MouseArea {
            id: dragLeftArea
            anchors.fill: parent
            anchors.margins: -4
            drag.target: null
            cursorShape: Qt.SizeHorCursor

            property real startMouseX: 0
            property real originalX: 0
            property real originalWidth: 0

            onPressed: (mouse) => {
                var parentPos = mapToItem(clipItemRoot.parent, mouse.x, mouse.y);
                startMouseX = parentPos.x;
                originalX = clipItemRoot.x;
                originalWidth = clipItemRoot.width;
            }

            onPositionChanged: (mouse) => {
                if (!clipData) return;
                var parentPos = mapToItem(clipItemRoot.parent, mouse.x, mouse.y);
                var dx = parentPos.x - startMouseX;
                
                var targetX = originalX + dx;
                var targetW = originalWidth - dx;
                
                var minWidthPx = 0.1 * zoomFactor; // 100ms minimum width
                if (targetX >= 0 && targetW >= minWidthPx) {
                    clipItemRoot.x = targetX;
                    clipItemRoot.width = targetW;
                }
            }

            onReleased: {
                if (!clipData) return;
                
                var originalEndTimeUs = clipData.startTime + clipData.duration;
                var targetStartTimeUs = (clipItemRoot.x / zoomFactor) * 1000000.0;
                var targetDurationUs = originalEndTimeUs - targetStartTimeUs;
                
                // Calculate sourceStart shift: how much the timeline start moved
                var deltaStartUs = targetStartTimeUs - clipData.startTime;
                var newSourceStartUs = clipData.sourceStart + deltaStartUs;
                
                // Clamp sourceStart at 0 (cannot reveal content before the source file begins)
                if (newSourceStartUs < 0) {
                    newSourceStartUs = 0;
                    targetStartTimeUs = clipData.startTime - clipData.sourceStart;
                    targetDurationUs = originalEndTimeUs - targetStartTimeUs;
                }
                
                // Enforce same-track collision safety when resizing left
                if (parentTrack) {
                    var closestLeftClipEnd = -1;
                    for (var i = 0; i < parentTrack.clips().length; ++i) {
                        var c = parentTrack.clips()[i];
                        if (c.clipId === clipData.clipId) continue;
                        if (c.endTime <= clipData.startTime) {
                            if (closestLeftClipEnd === -1 || c.endTime > closestLeftClipEnd) {
                                closestLeftClipEnd = c.endTime;
                            }
                        }
                    }
                    if (closestLeftClipEnd !== -1 && targetStartTimeUs < closestLeftClipEnd) {
                        var collisionDelta = closestLeftClipEnd - targetStartTimeUs;
                        targetStartTimeUs = closestLeftClipEnd;
                        targetDurationUs = originalEndTimeUs - targetStartTimeUs;
                        newSourceStartUs = newSourceStartUs + collisionDelta;
                    }
                }
                
                // Write back to C++ (sourceStart, startTime, duration)
                clipData.sourceStart = Math.round(newSourceStartUs);
                clipData.startTime = Math.round(targetStartTimeUs);
                clipData.duration = Math.round(targetDurationUs);
                timelineManager.setDirty();
                
                // Restore coordinate bindings to ensure they sync automatically
                clipItemRoot.x = Qt.binding(function() { 
                    return (clipData ? clipData.startTime / 1000000.0 : 0.0) * zoomFactor; 
                });
                clipItemRoot.width = Qt.binding(function() { 
                    return (clipData ? clipData.duration / 1000000.0 : 1.0) * zoomFactor; 
                });
            }
        }
    }

    // Right Resizing Trimmer Handle
    Rectangle {
        width: 6
        height: parent.height
        anchors.right: parent.right
        color: dragRightArea.pressed ? "#FFF" : Qt.darker(border.color, 1.3)
        radius: 3
        visible: parentTrack ? !parentTrack.isLocked : true

        MouseArea {
            id: dragRightArea
            anchors.fill: parent
            anchors.margins: -4
            drag.target: null
            cursorShape: Qt.SizeHorCursor

            property real startMouseX: 0
            property real originalWidth: 0

            onPressed: (mouse) => {
                var parentPos = mapToItem(clipItemRoot.parent, mouse.x, mouse.y);
                startMouseX = parentPos.x;
                originalWidth = clipItemRoot.width;
            }

            onPositionChanged: (mouse) => {
                if (!clipData) return;
                var parentPos = mapToItem(clipItemRoot.parent, mouse.x, mouse.y);
                var dx = parentPos.x - startMouseX;
                
                var targetW = originalWidth + dx;
                var minWidthPx = 0.1 * zoomFactor; // 100ms minimum width
                if (targetW >= minWidthPx) {
                    clipItemRoot.width = targetW;
                }
            }

            onReleased: {
                if (!clipData) return;
                var targetDurationUs = (clipItemRoot.width / zoomFactor) * 1000000.0;
                
                // Clamp to source asset boundary (cannot extend beyond the raw media length)
                if (clipData.sourceDuration > 0) {
                    var maxDurationUs = clipData.sourceDuration - clipData.sourceStart;
                    if (maxDurationUs > 0 && targetDurationUs > maxDurationUs) {
                        targetDurationUs = maxDurationUs;
                    }
                }
                
                // Enforce same-track collision safety when resizing right
                if (parentTrack) {
                    var closestRightClipStart = -1;
                    for (var i = 0; i < parentTrack.clips().length; ++i) {
                        var c = parentTrack.clips()[i];
                        if (c.clipId === clipData.clipId) continue;
                        if (c.startTime >= clipData.startTime) {
                            if (closestRightClipStart === -1 || c.startTime < closestRightClipStart) {
                                closestRightClipStart = c.startTime;
                            }
                        }
                    }
                    if (closestRightClipStart !== -1 && (clipData.startTime + targetDurationUs) > closestRightClipStart) {
                        targetDurationUs = closestRightClipStart - clipData.startTime;
                    }
                }
                
                // Write back to C++ once
                clipData.duration = Math.round(targetDurationUs);
                timelineManager.setDirty();
                
                // Restore coordinate binding to sync future updates automatically
                clipItemRoot.width = Qt.binding(function() { 
                    return (clipData ? clipData.duration / 1000000.0 : 1.0) * zoomFactor; 
                });
            }
        }
    }

    // Real-time timecode overlay tooltip
    Rectangle {
        id: timecodeTooltip
        visible: clipItemRoot.isActiveManipulating && clipData !== null
        anchors.bottom: parent.top
        anchors.bottomMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        width: tooltipLayout.implicitWidth + 16
        height: 24
        color: "#1E1A30"
        border.color: rootWindow.colorAccentViolet
        border.width: 1
        radius: 4
        z: 99
        
        RowLayout {
            id: tooltipLayout
            anchors.centerIn: parent
            spacing: 4
            Label {
                text: dragLeftArea.pressed ? "Trim L: " : (dragRightArea.pressed ? "Trim R: " : "Start: ")
                font.pixelSize: 13
                font.bold: true
                color: rootWindow.colorAccentGreen
            }
            Label {
                text: {
                    if (!clipData) return "";
                    var currentX = clipItemRoot.x;
                    var currentW = clipItemRoot.width;
                    if (dragRightArea.pressed) {
                        var visualEndTimeUs = ((currentX + currentW) / zoomFactor) * 1000000.0;
                        return timelineManager.formatTimecode(visualEndTimeUs);
                    }
                    var visualStartTimeUs = (currentX / zoomFactor) * 1000000.0;
                    return timelineManager.formatTimecode(visualStartTimeUs);
                }
                font.pixelSize: 13
                font.bold: true
                color: "#FFF"
                font.family: "Courier New"
            }
        }
    }
}
