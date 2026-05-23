import QtQuick
import QtQuick.Controls
import ncktv.core 1.0

Rectangle {
    id: clipItemRoot
    
    // Position and size calculations based on microsecond properties
    x: (clipData ? clipData.startTime / 1000000.0 : 0.0) * zoomFactor
    width: (clipData ? clipData.duration / 1000000.0 : 1.0) * zoomFactor
    height: 74
    anchors.verticalCenter: parent.verticalCenter
    radius: 6

    // Model properties
    property var clipData: null // C++ Clip* pointer passed from parent track lane
    property var parentTrack: null // C++ Track* pointer passed from parent
    property double zoomFactor: 120.0

    // Design states
    property bool isSelected: propertiesPanel.selectedClip === clipItemRoot.clipData
    
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

    Behavior on opacity { NumberAnimation { duration: 150 } }

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
    property double sweepProgress: {
        if (!clipData || clipData.clipType !== 2) return 0.0;
        return calculateSweepProgress(timelineManager.currentPlayheadTime);
    }

    function calculateSweepProgress(currentPlayheadTimeUs) {
        if (!clipData || clipData.clipType !== 2 || clipData.syllables.length === 0) {
            return 0.0;
        }
        
        var relativePlayheadUs = currentPlayheadTimeUs - clipData.startTime;
        
        if (relativePlayheadUs <= 0) {
            return 0.0;
        }
        if (relativePlayheadUs >= clipData.duration) {
            return 1.0;
        }
        
        var totalSyllables = clipData.syllables.length;
        var fullText = clipData.lyricText;
        var totalChars = fullText.length;
        if (totalChars === 0) return 0.0;
        
        // Precompute characters per syllable offset
        var charOffsets = [];
        var charCount = 0;
        for (var i = 0; i < totalSyllables; ++i) {
            charOffsets.push(charCount);
            charCount += clipData.syllables[i].text.length;
        }
        
        // Find current syllable timing slot
        for (var i = 0; i < totalSyllables; ++i) {
            var syl = clipData.syllables[i];
            var sStart = syl.relativeStart;
            var sDuration = syl.duration;
            var sEnd = sStart + sDuration;
            
            var sylCharOffset = charOffsets[i];
            var sylCharLen = syl.text.length;
            
            if (relativePlayheadUs >= sStart && relativePlayheadUs <= sEnd) {
                // Precise microsecond fractional progress inside the active syllable
                var sylProgress = (relativePlayheadUs - sStart) / sDuration;
                var activeChars = sylCharOffset + (sylCharLen * sylProgress);
                return activeChars / totalChars;
            } else if (relativePlayheadUs < sStart) {
                // Word separation gap
                return sylCharOffset / totalChars;
            }
        }
        
        return 1.0;
    }

    // Clip label details and UI Layout
    Column {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 2

        Label {
            text: clipData ? clipData.clipId : ""
            font.bold: true
            font.pixelSize: 10
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
                font.pixelSize: 10
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
                    font.pixelSize: 13
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
                        font.pixelSize: 13
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

    // Click to select clip
    MouseArea {
        anchors.fill: parent
        drag.target: null // Handled manually below for snapping calculations
        
        onPressed: (mouse) => {
            propertiesPanel.selectedClip = clipItemRoot.clipData;
            propertiesPanel.selectedTrack = clipItemRoot.parentTrack;
            mouse.accepted = true;
        }
    }

    // Horizontal dragging with snap & collision checks
    MouseArea {
        id: dragArea
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        cursorShape: Qt.SizeAll

        property real startDragX: 0
        property bool isDragging: false

        onPressed: (mouse) => {
            if (parentTrack && parentTrack.isLocked) {
                mouse.accepted = false;
                return;
            }
            startDragX = mouse.x;
            isDragging = true;
            propertiesPanel.selectedClip = clipItemRoot.clipData;
            propertiesPanel.selectedTrack = clipItemRoot.parentTrack;
        }

        onPositionChanged: (mouse) => {
            if (!isDragging || !clipData) return;
            
            // Calculate target position shift in pixels
            var dx = mouse.x - startDragX;
            var targetX = clipItemRoot.x + dx;
            
            // Map target x coordinate to start time in microseconds
            var targetStartTimeUs = (targetX / zoomFactor) * 1000000.0;
            if (targetStartTimeUs < 0) targetStartTimeUs = 0;

            // 1. Snapping engine calculations
            if (timelineView.snappingEnabled) {
                var thresholdUs = timelineView.snapThresholdMs * 1000.0;
                targetStartTimeUs = timelineManager.checkSnapping(clipData.clipId, targetStartTimeUs, thresholdUs);
            }

            // 2. Overlap/Collision blocking: prevents dragging past same-track adjacent clip bounds
            if (parentTrack) {
                targetStartTimeUs = timelineManager.checkCollisions(parentTrack.trackId, clipData.clipId, targetStartTimeUs);
            }

            // Write change back to C++ models
            clipData.startTime = targetStartTimeUs;
        }

        onReleased: {
            isDragging = false;
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

            property real startDragX: 0

            onPressed: (mouse) => {
                startDragX = mouse.x;
            }

            onPositionChanged: (mouse) => {
                if (!clipData) return;
                var dx = mouse.x - startDragX;
                var dxUs = (dx / zoomFactor) * 1000000.0;
                
                var oldStart = clipData.startTime;
                var oldDuration = clipData.duration;
                
                var newStart = oldStart + dxUs;
                var newDuration = oldDuration - dxUs;
                
                if (newStart >= 0 && newDuration > 100000) { // At least 100ms long
                    // Enforce same-track collision safety when resizing left
                    if (parentTrack) {
                        // Find the closest clip ending before oldStart
                        var closestLeftClipEnd = -1;
                        for (var i = 0; i < parentTrack.clips().length; ++i) {
                            var c = parentTrack.clips()[i];
                            if (c.clipId === clipData.clipId) continue;
                            if (c.endTime <= oldStart) {
                                if (closestLeftClipEnd === -1 || c.endTime > closestLeftClipEnd) {
                                    closestLeftClipEnd = c.endTime;
                                }
                            }
                        }
                        if (closestLeftClipEnd !== -1 && newStart < closestLeftClipEnd) {
                            newStart = closestLeftClipEnd;
                            newDuration = oldStart + oldDuration - newStart;
                        }
                    }

                    clipData.startTime = newStart;
                    clipData.duration = newDuration;
                }
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

            property real startDragX: 0

            onPressed: (mouse) => {
                startDragX = mouse.x;
            }

            onPositionChanged: (mouse) => {
                if (!clipData) return;
                var dx = mouse.x - startDragX;
                var dxUs = (dx / zoomFactor) * 1000000.0;
                
                var oldStart = clipData.startTime;
                var newDuration = clipData.duration + dxUs;
                
                if (newDuration > 100000) { // At least 100ms long
                    // Enforce same-track collision safety when resizing right
                    if (parentTrack) {
                        var closestRightClipStart = -1;
                        for (var i = 0; i < parentTrack.clips().length; ++i) {
                            var c = parentTrack.clips()[i];
                            if (c.clipId === clipData.clipId) continue;
                            if (c.startTime >= oldStart + clipData.duration) {
                                if (closestRightClipStart === -1 || c.startTime < closestRightClipStart) {
                                    closestRightClipStart = c.startTime;
                                }
                            }
                        }
                        if (closestRightClipStart !== -1 && (oldStart + newDuration) > closestRightClipStart) {
                            newDuration = closestRightClipStart - oldStart;
                        }
                    }

                    clipData.duration = newDuration;
                }
            }
        }
    }
}
