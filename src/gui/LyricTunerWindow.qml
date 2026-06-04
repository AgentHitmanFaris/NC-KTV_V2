import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ncktv.core 1.0

Window {
    id: tunerWindow
    width: 1000
    height: 680
    title: "NC-KTV V2 - Dedicated Lyric & Syllable Timing Editor"
    color: "#08080A"
    flags: Qt.Window

    onClosing: {
        audioEngine.playbackRate = 1.0;
    }

    // Context bindings
    property var lyricsTrack: null
    property var selectedClip: null
    property int selectedSylIdx: -1
    property double sylZoomFactor: 1.5
    property bool sylContiguousMode: true

    // Computed active syllable based on playhead time
    property int activeSylIdx: {
        if (!selectedClip || timelineManager.currentPlayheadTime < selectedClip.startTime || timelineManager.currentPlayheadTime > selectedClip.endTime) {
            return -1;
        }
        var elapsed = timelineManager.currentPlayheadTime - selectedClip.startTime;
        var syls = selectedClip.syllables;
        for (var i = 0; i < syls.length; ++i) {
            if (elapsed >= syls[i].relativeStart && elapsed < (syls[i].relativeStart + syls[i].duration)) {
                return i;
            }
        }
        return -1;
    }

    onActiveSylIdxChanged: {
        if (activeSylIdx !== -1 && activeSylIdx !== selectedSylIdx) {
            selectedSylIdx = activeSylIdx;
            sylListView.positionViewAtIndex(selectedSylIdx, ListView.Contain);
        }
    }

    // Helper functions
    function playSyllable(index) {
        if (!selectedClip) return;
        var syls = selectedClip.syllables;
        if (index >= 0 && index < syls.length) {
            var syl = syls[index];
            rootWindow.syllableLoopStartUs = selectedClip.startTime + syl.relativeStart;
            rootWindow.syllableLoopEndUs = rootWindow.syllableLoopStartUs + syl.duration;
            timelineManager.currentPlayheadTime = rootWindow.syllableLoopStartUs;
            rootWindow.syllableLoopEnabled = true;
            audioEngine.play();
        }
    }

    function findLyricsTrack() {
        var tracksList = timelineManager.trackListModel.tracks();
        for (var i = 0; i < tracksList.length; ++i) {
            if (tracksList[i].trackType === 2) {
                return tracksList[i];
            }
        }
        return null;
    }

    function showTunerForActiveSelection() {
        var track = findLyricsTrack();
        if (track) {
            lyricsTrack = track;
            // Look if main window has a selected lyric clip
            if (propertiesPanel.selectedClip && propertiesPanel.selectedClip.clipType === 2) {
                selectedClip = propertiesPanel.selectedClip;
            } else {
                // Default to first clip in lyrics track
                var clips = timelineManager.getClipModelForTrack(track.trackId);
                if (clips && clips.rowCount() > 0) {
                    selectedClip = clips.getClip(0); // Get first clip object
                }
            }
        }
        tunerWindow.show();
        tunerWindow.raise();
        tunerWindow.requestActivate();
    }

    function adjustSyllableRight(index, originalStart, originalDur, deltaUs) {
        if (!selectedClip) return;
        var newDur = Math.max(10000, originalDur + deltaUs);
        selectedClip.updateSyllable(index, originalStart, newDur);
        
        if (sylContiguousMode && index + 1 < selectedClip.syllables.length) {
            var nextSyl = selectedClip.syllables[index + 1];
            var nextStart = originalStart + newDur;
            var nextDur = Math.max(10000, (nextSyl.relativeStart + nextSyl.duration) - nextStart);
            selectedClip.updateSyllable(index + 1, nextStart, nextDur);
        }
    }

    function adjustSyllableLeft(index, originalStart, originalDur, deltaUs) {
        if (!selectedClip) return;
        var maxDelta = originalDur - 10000;
        var finalDelta = Math.max(-originalStart, Math.min(maxDelta, deltaUs));
        var newStart = originalStart + finalDelta;
        var newDur = originalDur - finalDelta;
        selectedClip.updateSyllable(index, newStart, newDur);

        if (sylContiguousMode && index > 0) {
            var prevSyl = selectedClip.syllables[index - 1];
            var prevDur = Math.max(10000, newStart - prevSyl.relativeStart);
            selectedClip.updateSyllable(index - 1, prevSyl.relativeStart, prevDur);
        }
    }

    // Main window background styling
    Rectangle {
        anchors.fill: parent
        color: "#08080A"
        
        // Dynamic background gradients matching premium NLE theme
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#0F0F18" }
                GradientStop { position: 1.0; color: "#07070A" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header Section
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Label {
                    text: "🎙️ LYRICS & SYLLABLE TIMING TUNER"
                    font.pixelSize: 18
                    font.bold: true
                    font.family: "Space Grotesk"
                    color: rootWindow.colorTextPrimary
                }

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    color: rootWindow.colorAccentGreen
                }

                Label {
                    text: lyricsTrack ? ("Track: " + lyricsTrack.trackName) : "No Lyrics Track Found"
                    font.pixelSize: 13
                    font.bold: true
                    color: rootWindow.colorAccentViolet
                }

                Item { Layout.fillWidth: true }

                // Playback control mini panel
                RowLayout {
                    spacing: 8

                    Button {
                        id: btnMiniPlay
                        text: audioEngine.isPlaying ? "‖ Pause" : "▶ Play"
                        implicitWidth: 80
                        implicitHeight: 26
                        onClicked: audioEngine.isPlaying ? audioEngine.pause() : audioEngine.play()
                        background: Rectangle {
                            color: btnMiniPlay.hovered ? "#222" : "#111"
                            border.color: rootWindow.colorAccentGreen
                            radius: 4
                        }
                        contentItem: Text {
                            text: btnMiniPlay.text
                            color: "#FFF"
                            font.bold: true
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        id: btnMiniStop
                        text: "■ Stop"
                        implicitWidth: 65
                        implicitHeight: 26
                        onClicked: audioEngine.stop()
                        background: Rectangle {
                            color: btnMiniStop.hovered ? "#222" : "#111"
                            border.color: rootWindow.colorTextSecondary
                            radius: 4
                        }
                        contentItem: Text {
                            text: btnMiniStop.text
                            color: "#FFF"
                            font.bold: true
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // Split Layout: Left list of lines, right detail editing
            SplitView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                orientation: Qt.Horizontal

                // Left Panel: Scrollable Lyric Lines List
                Rectangle {
                    SplitView.preferredWidth: 320
                    SplitView.minimumWidth: 260
                    color: "#111115"
                    border.color: rootWindow.colorBorder
                    border.width: 1
                    radius: 6

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8

                        Label {
                            text: "LYRIC LINES INDEX"
                            font.bold: true
                            font.pixelSize: 13
                            color: rootWindow.colorTextSecondary
                        }

                        // Search Filter Box
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 32
                            color: "#16161D"
                            border.color: rootWindow.colorBorder
                            radius: 4

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                TextField {
                                    id: filterInput
                                    Layout.fillWidth: true
                                    placeholderText: "Search lyrics..."
                                    placeholderTextColor: "#444"
                                    color: rootWindow.colorTextPrimary
                                    font.pixelSize: 13
                                    background: null
                                }

                                Button {
                                    text: "✕"
                                    visible: filterInput.text !== ""
                                    implicitWidth: 20
                                    implicitHeight: 20
                                    onClicked: filterInput.text = ""
                                    background: null
                                    contentItem: Text { text: "✕"; color: "#666" }
                                }
                            }
                        }

                        // ListView of all subtitle clips
                        ListView {
                            id: lyricLinesListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            spacing: 4
                            model: lyricsTrack ? timelineManager.getClipModelForTrack(lyricsTrack.trackId) : null

                            delegate: Rectangle {
                                width: lyricLinesListView.width
                                height: visible ? 40 : 0
                                visible: {
                                    if (filterInput.text.trim() === "") return true;
                                    var text = model.clipLyricText ? model.clipLyricText.toLowerCase() : "";
                                    return text.includes(filterInput.text.toLowerCase());
                                }
                                color: (selectedClip === model.clipObject) ? "#2D264A" : "#1B1B22"
                                border.color: (selectedClip === model.clipObject) ? rootWindow.colorAccentViolet : rootWindow.colorBorder
                                border.width: 1
                                radius: 4

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        selectedClip = model.clipObject;
                                        timelineManager.currentPlayheadTime = model.clipStartTime;
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    spacing: 8

                                    Rectangle {
                                        implicitWidth: 70
                                        implicitHeight: 22
                                        color: "#08080C"
                                        radius: 3
                                        border.color: "#3F51B5"
                                        
                                        Label {
                                            anchors.centerIn: parent
                                            text: timelineManager.formatTimecode(model.clipStartTime)
                                            font.pixelSize: 11
                                            color: rootWindow.colorAccentGreen
                                            font.family: "Courier New"
                                            font.bold: true
                                        }
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: model.clipLyricText
                                        font.pixelSize: 13
                                        color: rootWindow.colorTextPrimary
                                        elide: Text.ElideRight
                                    }

                                    // Remove/delete line button
                                    Button {
                                        id: btnDelLine
                                        text: "✕"
                                        implicitWidth: 18
                                        implicitHeight: 18
                                        onClicked: {
                                            if (confirm("Delete this lyric line?")) {
                                                timelineManager.removeClip(model.clipId);
                                                selectedClip = null;
                                                timelineManager.setDirty(true);
                                            }
                                        }
                                        background: Rectangle {
                                            color: btnDelLine.hovered ? "#C62828" : "transparent"
                                            radius: 3
                                        }
                                        contentItem: Text { text: "✕"; color: "#888"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }
                                }
                            }
                        }

                        // Add new line button
                        Button {
                            id: btnAddLine
                            text: "+ ADD NEW LINE HERE"
                            Layout.fillWidth: true
                            implicitHeight: 30
                            onClicked: {
                                if (lyricsTrack) {
                                    var clipId = "lyric_" + Date.now();
                                    timelineManager.addClipToTrack(lyricsTrack.trackId, clipId, 2, timelineManager.currentPlayheadTime, 3000000, "", "New Lyric Line");
                                    timelineManager.setDirty(true);
                                    // Set focus to the new clip
                                    var listModel = timelineManager.getClipModelForTrack(lyricsTrack.trackId);
                                    if (listModel && listModel.rowCount() > 0) {
                                        selectedClip = listModel.getClip(listModel.rowCount() - 1).clipObject;
                                    }
                                }
                            }
                            background: Rectangle {
                                color: btnAddLine.hovered ? "#1B3A24" : "#14241F"
                                border.color: rootWindow.colorAccentGreen
                                radius: 4
                            }
                            contentItem: Text {
                                text: btnAddLine.text
                                color: "#FFF"
                                font.bold: true
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }

                // Right Panel: Lyrics detail & Syllables editing details
                ScrollView {
                    SplitView.fillWidth: true
                    clip: true

                    ColumnLayout {
                        width: parent.width - 15
                        spacing: 12

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 400
                            visible: selectedClip === null
                            Label {
                                anchors.centerIn: parent
                                text: "Select a lyric line from the list to begin tuning."
                                font.pixelSize: 15
                                color: rootWindow.colorTextSecondary
                                font.italic: true
                            }
                        }

                        // Section 1: Line timings & Text Cue
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 180
                            color: "#111115"
                            border.color: rootWindow.colorBorder
                            border.width: 1
                            radius: 6
                            visible: selectedClip !== null

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    // Line Title & Coordinates display
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Label {
                                            text: "ACTIVE CUE TIMINGS"
                                            font.bold: true
                                            font.pixelSize: 13
                                            color: rootWindow.colorTextSecondary
                                        }

                                        Item { Layout.fillWidth: true }

                                        Label {
                                            text: selectedClip ? "Start: " + timelineManager.formatTimecode(selectedClip.startTime) + " | Dur: " + (selectedClip.duration / 1000000.0).toFixed(2) + "s" : "No clip selected"
                                            font.pixelSize: 12
                                            font.bold: true
                                            color: rootWindow.colorAccentGreen
                                            font.family: "Courier New"
                                        }
                                    }

                                    // Line text editor field
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "#16161D"
                                        border.color: rootWindow.colorBorder
                                        radius: 4

                                        TextArea {
                                            id: clipTextField
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            text: selectedClip ? selectedClip.lyricText : ""
                                            color: rootWindow.colorTextPrimary
                                            font.pixelSize: 15
                                            wrapMode: TextArea.Wrap
                                            placeholderText: "Enter line text..."
                                            placeholderTextColor: "#444"
                                            background: null

                                            onTextEdited: {
                                                selectedClip.lyricText = text;
                                                timelineManager.setDirty(true);
                                            }
                                        }
                                    }

                                    // Romanize & Nudge Cue Start
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        Button {
                                            id: btnRomLineWindow
                                            text: "🔤 ROMANIZE TEXT"
                                            Layout.fillWidth: true
                                            implicitHeight: 28
                                            onClicked: {
                                                timelineManager.romanizeClip(selectedClip);
                                                clipTextField.text = selectedClip.lyricText;
                                                timelineManager.setDirty(true);
                                            }
                                            background: Rectangle {
                                                color: btnRomLineWindow.hovered ? "#2D264A" : "#1B1B22"
                                                radius: 4
                                                border.color: rootWindow.colorAccentViolet
                                            }
                                            contentItem: Text {
                                                text: btnRomLineWindow.text
                                                font.bold: true
                                                font.pixelSize: 12
                                                color: "#FFF"
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }

                                        Label { text: "Nudge Line:"; font.pixelSize: 12; color: rootWindow.colorTextSecondary }

                                        Button {
                                            text: "-100ms"
                                            implicitWidth: 60
                                            implicitHeight: 28
                                            onClicked: {
                                                var newStart = Math.max(0, selectedClip.startTime - 100000);
                                                selectedClip.moveTo(newStart);
                                                timelineManager.setDirty(true);
                                            }
                                            background: Rectangle { color: "#222"; radius: 4 }
                                            contentItem: Text { text: "-100ms"; font.pixelSize: 11; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        }

                                        Button {
                                            text: "+100ms"
                                            implicitWidth: 60
                                            implicitHeight: 28
                                            onClicked: {
                                                selectedClip.moveTo(selectedClip.startTime + 100000);
                                                timelineManager.setDirty(true);
                                            }
                                            background: Rectangle { color: "#222"; radius: 4 }
                                            contentItem: Text { text: "+100ms"; font.pixelSize: 11; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        }
                                    }
                                }
                            }

                            // Section 2: Syllable Map zooming and Loop testing controls
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 390
                                color: "#111115"
                                border.color: rootWindow.colorBorder
                                border.width: 1
                                radius: 6
                                visible: selectedClip !== null

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    // Timing Tuner toolbar
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Label {
                                            text: "SYLLABLE TIMING TUNER GRID"
                                            font.bold: true
                                            font.pixelSize: 13
                                            color: rootWindow.colorTextSecondary
                                        }

                                        Item { Layout.fillWidth: true }

                                        Label {
                                            text: "Speed:"
                                            font.pixelSize: 11
                                            font.bold: true
                                            color: rootWindow.colorTextSecondary
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        ComboBox {
                                            id: playbackSpeedCombo
                                            implicitWidth: 80
                                            implicitHeight: 24
                                            model: ["0.25x", "0.5x", "0.75x", "1.0x", "1.25x", "1.5x"]
                                            currentIndex: 3 // Default 1.0x
                                            
                                            onActivated: (index) => {
                                                var rates = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5];
                                                audioEngine.playbackRate = rates[index];
                                            }

                                            delegate: ItemDelegate {
                                                width: playbackSpeedCombo.width
                                                contentItem: Text {
                                                    text: modelData
                                                    color: highlighted ? "#FFF" : "#8A8A9E"
                                                    font.bold: highlighted
                                                    font.pixelSize: 12
                                                    font.family: "Outfit"
                                                    verticalAlignment: Text.AlignVCenter
                                                }
                                                background: Rectangle {
                                                    color: highlighted ? "#2D264A" : "#111115"
                                                }
                                            }

                                            contentItem: Text {
                                                leftPadding: 6
                                                rightPadding: 20
                                                text: playbackSpeedCombo.currentText
                                                font.pixelSize: 12
                                                font.bold: true
                                                font.family: "Outfit"
                                                color: rootWindow.colorAccentGreen
                                                verticalAlignment: Text.AlignVCenter
                                            }

                                            background: Rectangle {
                                                color: "#16161C"
                                                border.color: "#2C2C3A"
                                                border.width: 1
                                                radius: 4
                                            }
                                        }

                                        // Linked mode
                                        Button {
                                            id: btnLinkModeWin
                                            text: sylContiguousMode ? "🔗 Linked Boundaries" : "🔓 Free Form"
                                            implicitWidth: 130
                                            implicitHeight: 24
                                            onClicked: sylContiguousMode = !sylContiguousMode
                                            background: Rectangle {
                                                color: sylContiguousMode ? "#1B3A24" : "#222"
                                                radius: 4
                                                border.color: sylContiguousMode ? rootWindow.colorAccentGreen : rootWindow.colorBorder
                                            }
                                            contentItem: Text {
                                                text: btnLinkModeWin.text
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: "#FFF"
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }

                                        // Syllable loop
                                        Button {
                                            id: btnLoopSylWin
                                            text: rootWindow.syllableLoopEnabled && selectedClip && rootWindow.syllableLoopStartUs !== selectedClip.startTime ? "⏹ Stop Syl" : "🔁 Loop Syl"
                                            implicitWidth: 85
                                            implicitHeight: 24
                                            enabled: selectedSylIdx !== -1
                                            onClicked: {
                                                if (rootWindow.syllableLoopEnabled && rootWindow.syllableLoopStartUs !== selectedClip.startTime) {
                                                    rootWindow.syllableLoopEnabled = false;
                                                    audioEngine.pause();
                                                } else {
                                                    var syl = selectedClip.syllables[selectedSylIdx];
                                                    if (syl) {
                                                        rootWindow.syllableLoopStartUs = selectedClip.startTime + syl.relativeStart;
                                                        rootWindow.syllableLoopEndUs = rootWindow.syllableLoopStartUs + syl.duration;
                                                        timelineManager.currentPlayheadTime = rootWindow.syllableLoopStartUs;
                                                        rootWindow.syllableLoopEnabled = true;
                                                        audioEngine.play();
                                                    }
                                                }
                                            }
                                            background: Rectangle {
                                                color: (rootWindow.syllableLoopEnabled && selectedClip && rootWindow.syllableLoopStartUs !== selectedClip.startTime) ? "#C62828" : "#222"
                                                radius: 4
                                            }
                                            contentItem: Text {
                                                text: btnLoopSylWin.text
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: "#FFF"
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }

                                        // Line loop
                                        Button {
                                            id: btnLoopLineWin
                                            text: rootWindow.syllableLoopEnabled && selectedClip && rootWindow.syllableLoopStartUs === selectedClip.startTime ? "⏹ Stop Line" : "🔁 Loop Line"
                                            implicitWidth: 85
                                            implicitHeight: 24
                                            onClicked: {
                                                if (rootWindow.syllableLoopEnabled && rootWindow.syllableLoopStartUs === selectedClip.startTime) {
                                                    rootWindow.syllableLoopEnabled = false;
                                                    audioEngine.pause();
                                                } else {
                                                    rootWindow.syllableLoopStartUs = selectedClip.startTime;
                                                    rootWindow.syllableLoopEndUs = selectedClip.endTime;
                                                    timelineManager.currentPlayheadTime = rootWindow.syllableLoopStartUs;
                                                    rootWindow.syllableLoopEnabled = true;
                                                    audioEngine.play();
                                                }
                                            }
                                            background: Rectangle {
                                                color: (rootWindow.syllableLoopEnabled && selectedClip && rootWindow.syllableLoopStartUs === selectedClip.startTime) ? "#C62828" : "#222"
                                                radius: 4
                                            }
                                            contentItem: Text {
                                                text: btnLoopLineWin.text
                                                font.bold: true
                                                font.pixelSize: 11
                                                color: "#FFF"
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }

                                    // Visual Timing Map - Horizontal dragging area
                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 70
                                        color: "#09090C"
                                        border.color: rootWindow.colorBorder
                                        radius: 4
                                        clip: true

                                        Flickable {
                                            id: windowFlickable
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            contentWidth: winSylRow.width
                                            contentHeight: parent.height - 8
                                            clip: true
                                            flickableDirection: Flickable.HorizontalFlick
                                            ScrollBar.horizontal: ScrollBar { active: true }

                                            Item {
                                                id: winSylRow
                                                height: parent.height - 6
                                                width: selectedClip ? (selectedClip.duration / 1000000.0) * 220.0 * sylZoomFactor : 0

                                                // Playhead indicator
                                                Rectangle {
                                                    width: 2
                                                    height: parent.height
                                                    color: "#FF1744"
                                                    z: 10
                                                    x: selectedClip ? ((timelineManager.currentPlayheadTime - selectedClip.startTime) / 1000000.0) * 220.0 * sylZoomFactor : 0
                                                    visible: selectedClip ? (timelineManager.currentPlayheadTime >= selectedClip.startTime && timelineManager.currentPlayheadTime <= selectedClip.endTime) : false
                                                }

                                                Repeater {
                                                    model: selectedClip ? selectedClip.syllables : null
                                                    delegate: Rectangle {
                                                        height: parent.height
                                                        x: (modelData.relativeStart / 1000000.0) * 220.0 * sylZoomFactor
                                                        width: Math.max(30.0, (modelData.duration / 1000000.0) * 220.0 * sylZoomFactor)
                                                        
                                                        property bool isActive: activeSylIdx === index
                                                        property bool isSelected: selectedSylIdx === index

                                                        color: isActive ? "#2D1A4D" : (isSelected ? "#221C35" : "#14141A")
                                                        border.color: isActive ? rootWindow.colorAccentGreen : (isSelected ? rootWindow.colorAccentViolet : rootWindow.colorBorder)
                                                        border.width: (isActive || isSelected) ? 2 : 1
                                                        radius: 4

                                                        Column {
                                                            anchors.centerIn: parent
                                                            spacing: 2
                                                            Text {
                                                                text: modelData.text.trim()
                                                                color: isActive ? "#FFF" : rootWindow.colorTextPrimary
                                                                font.bold: true
                                                                font.pixelSize: 15
                                                                anchors.horizontalCenter: parent.horizontalCenter
                                                                elide: Text.ElideRight
                                                                width: parent.parent.width - 8
                                                                horizontalAlignment: Text.AlignHCenter
                                                            }
                                                            Text {
                                                                text: (modelData.duration / 1000000.0).toFixed(2) + "s"
                                                                color: isActive ? rootWindow.colorAccentGreen : rootWindow.colorTextSecondary
                                                                font.pixelSize: 12
                                                                anchors.horizontalCenter: parent.horizontalCenter
                                                            }
                                                        }

                                                        // Left handle
                                                        Rectangle {
                                                            width: 10
                                                            height: parent.height
                                                            anchors.left: parent.left
                                                            color: "transparent"
                                                            z: 5
                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.SizeHorCursor
                                                                property real startParentX: 0
                                                                property real originalStart: 0
                                                                property real originalDur: 0
                                                                onPressed: (mouse) => {
                                                                    var mapped = mapToItem(winSylRow, mouse.x, mouse.y);
                                                                    startParentX = mapped.x;
                                                                    originalStart = modelData.relativeStart;
                                                                    originalDur = modelData.duration;
                                                                    selectedSylIdx = index;
                                                                    playSyllable(index);
                                                                }
                                                                onPositionChanged: (mouse) => {
                                                                    var mapped = mapToItem(winSylRow, mouse.x, mouse.y);
                                                                    var dx = mapped.x - startParentX;
                                                                    var deltaUs = (dx / (220.0 * sylZoomFactor)) * 1000000.0;
                                                                    adjustSyllableLeft(index, originalStart, originalDur, Math.round(deltaUs));
                                                                }
                                                                onReleased: timelineManager.setDirty(true)
                                                            }
                                                        }

                                                        // Middle drag
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            anchors.leftMargin: 10
                                                            anchors.rightMargin: 10
                                                            cursorShape: Qt.SizeAll
                                                            property real startParentX: 0
                                                            property real originalStart: 0
                                                            onPressed: (mouse) => {
                                                                var mapped = mapToItem(winSylRow, mouse.x, mouse.y);
                                                                startParentX = mapped.x;
                                                                originalStart = modelData.relativeStart;
                                                                selectedSylIdx = index;
                                                                playSyllable(index);
                                                            }
                                                            onPositionChanged: (mouse) => {
                                                                var mapped = mapToItem(winSylRow, mouse.x, mouse.y);
                                                                var dx = mapped.x - startParentX;
                                                                var deltaUs = (dx / (220.0 * sylZoomFactor)) * 1000000.0;
                                                                var newStart = Math.max(0, originalStart + deltaUs);
                                                                selectedClip.updateSyllable(index, Math.round(newStart), modelData.duration);
                                                            }
                                                            onReleased: timelineManager.setDirty(true)
                                                        }

                                                        // Right handle
                                                        Rectangle {
                                                            width: 10
                                                            height: parent.height
                                                            anchors.right: parent.right
                                                            color: "transparent"
                                                            z: 5
                                                            MouseArea {
                                                                anchors.fill: parent
                                                                cursorShape: Qt.SizeHorCursor
                                                                property real startParentX: 0
                                                                property real originalDur: 0
                                                                onPressed: (mouse) => {
                                                                    var mapped = mapToItem(winSylRow, mouse.x, mouse.y);
                                                                    startParentX = mapped.x;
                                                                    originalDur = modelData.duration;
                                                                    selectedSylIdx = index;
                                                                    playSyllable(index);
                                                                }
                                                                onPositionChanged: (mouse) => {
                                                                    var mapped = mapToItem(winSylRow, mouse.x, mouse.y);
                                                                    var dx = mapped.x - startParentX;
                                                                    var deltaUs = (dx / (220.0 * sylZoomFactor)) * 1000000.0;
                                                                    adjustSyllableRight(index, modelData.relativeStart, originalDur, Math.round(deltaUs));
                                                                }
                                                                onReleased: timelineManager.setDirty(true)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Zoom slider & Auto distribute buttons
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        Label { text: "Zoom Factor:"; font.pixelSize: 12; color: rootWindow.colorTextSecondary }
                                        Slider {
                                            id: gridZoomSlider
                                            Layout.fillWidth: true
                                            from: 0.5
                                            to: 5.0
                                            value: sylZoomFactor
                                            onMoved: sylZoomFactor = value
                                            
                                            background: Rectangle {
                                                implicitHeight: 3
                                                color: "#222"
                                                radius: 1.5
                                                Rectangle {
                                                    width: gridZoomSlider.visualPosition * parent.width
                                                    height: parent.height
                                                    color: rootWindow.colorAccentViolet
                                                    radius: 1.5
                                                }
                                            }
                                            handle: Rectangle {
                                                x: gridZoomSlider.visualPosition * (gridZoomSlider.width - width)
                                                y: (gridZoomSlider.height - height) / 2
                                                width: 10
                                                height: 10
                                                radius: 5
                                                color: gridZoomSlider.hovered ? "#FFF" : rootWindow.colorAccentViolet
                                            }
                                        }

                                        Button {
                                            id: btnAutoWeight
                                            text: "⚡ Auto-Weight Timing"
                                            implicitHeight: 24
                                            implicitWidth: 150
                                            onClicked: {
                                                if (selectedClip) {
                                                    // Trigger clip timing auto recalculation
                                                    selectedClip.autoGenerateSyllables();
                                                    timelineManager.setDirty(true);
                                                }
                                            }
                                            background: Rectangle {
                                                color: btnAutoWeight.hovered ? "#1B3A24" : "#112215"
                                                radius: 4
                                                border.color: rootWindow.colorAccentGreen
                                            }
                                            contentItem: Text {
                                                text: btnAutoWeight.text
                                                color: "#FFF"
                                                font.bold: true
                                                font.pixelSize: 11
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }

                                    // Detailed list of syllables
                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "#16161D"
                                        border.color: rootWindow.colorBorder
                                        radius: 4

                                        ListView {
                                            id: sylListView
                                            anchors.fill: parent
                                            anchors.margins: 4
                                            model: selectedClip ? selectedClip.syllables : null
                                            clip: true
                                            spacing: 4

                                            delegate: Rectangle {
                                                width: sylListView.width - 12
                                                height: 32
                                                property bool isActive: activeSylIdx === index
                                                property bool isSelected: selectedSylIdx === index

                                                color: isActive ? "#2D1A4D" : (isSelected ? "#221C35" : "#1B1B22")
                                                border.color: isActive ? rootWindow.colorAccentGreen : (isSelected ? rootWindow.colorAccentViolet : rootWindow.colorBorder)
                                                border.width: (isActive || isSelected) ? 2 : 1
                                                radius: 4

                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        selectedSylIdx = index;
                                                        playSyllable(index);
                                                    }
                                                }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 4
                                                    spacing: 8

                                                    Label {
                                                        text: modelData.text.trim()
                                                        font.bold: true
                                                        font.pixelSize: 14
                                                        color: "#FFF"
                                                        Layout.preferredWidth: 90
                                                        elide: Text.ElideRight
                                                    }

                                                    Label {
                                                        text: "Start: " + (modelData.relativeStart / 1000000.0).toFixed(2) + "s"
                                                        font.pixelSize: 12
                                                        color: rootWindow.colorTextSecondary
                                                        font.family: "Courier New"
                                                        Layout.preferredWidth: 90
                                                    }

                                                    Label {
                                                        text: "Dur: " + (modelData.duration / 1000000.0).toFixed(2) + "s"
                                                        font.pixelSize: 12
                                                        color: rootWindow.colorAccentGreen
                                                        font.family: "Courier New"
                                                        Layout.preferredWidth: 80
                                                    }

                                                    Item { Layout.fillWidth: true }

                                                    // Nudge Start buttons
                                                    Label { text: "Start:"; font.pixelSize: 11; color: "#555" }
                                                    Button {
                                                        text: "-"
                                                        implicitWidth: 24
                                                        implicitHeight: 20
                                                        onClicked: {
                                                            var newStart = Math.max(0, modelData.relativeStart - 50000);
                                                            selectedClip.updateSyllable(index, newStart, modelData.duration);
                                                            timelineManager.setDirty(true);
                                                        }
                                                        background: Rectangle { color: "#222"; radius: 2 }
                                                        contentItem: Text { text: "-50"; font.pixelSize: 10; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                    }
                                                    Button {
                                                        text: "+"
                                                        implicitWidth: 24
                                                        implicitHeight: 20
                                                        onClicked: {
                                                            selectedClip.updateSyllable(index, modelData.relativeStart + 50000, modelData.duration);
                                                            timelineManager.setDirty(true);
                                                        }
                                                        background: Rectangle { color: "#222"; radius: 2 }
                                                        contentItem: Text { text: "+50"; font.pixelSize: 10; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                    }

                                                    // Nudge Duration buttons
                                                    Label { text: "Dur:"; font.pixelSize: 11; color: "#555" }
                                                    Button {
                                                        text: "-"
                                                        implicitWidth: 24
                                                        implicitHeight: 20
                                                        onClicked: {
                                                            var newDur = Math.max(10000, modelData.duration - 50000);
                                                            selectedClip.updateSyllable(index, modelData.relativeStart, newDur);
                                                            timelineManager.setDirty(true);
                                                        }
                                                        background: Rectangle { color: "#222"; radius: 2 }
                                                        contentItem: Text { text: "-50"; font.pixelSize: 10; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                    }
                                                    Button {
                                                        text: "+"
                                                        implicitWidth: 24
                                                        implicitHeight: 20
                                                        onClicked: {
                                                            selectedClip.updateSyllable(index, modelData.relativeStart, modelData.duration + 50000);
                                                            timelineManager.setDirty(true);
                                                        }
                                                        background: Rectangle { color: "#222"; radius: 2 }
                                                        contentItem: Text { text: "+50"; font.pixelSize: 10; color: "#FFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }
}
