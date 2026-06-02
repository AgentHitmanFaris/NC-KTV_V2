import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: mediaBrowserRoot
    color: rootWindow.colorBgPanel
    border.color: rootWindow.colorBorder
    border.width: 1

    property int selectedMediaIdx: -1
    property string searchQuery: ""
    property string filterType: "All"
    property int matchingCount: 0

    // Tabbed Navigation
    property int currentTab: 0 // 0 = Library, 1 = Lyrics, 2 = YouTube
    
    // Lyrics finder states
    property var selectedLrcItem: null
    
    // YouTube downloader states
    property var selectedYtItem: null
    property string activeDownloadVideoId: ""
    property double activeDownloadProgress: 0.0
    property string activeDownloadTitle: ""

    function updateMatchingCount() {
        var count = 0;
        for (var i = 0; i < mockFilesModel.count; ++i) {
            var item = mockFilesModel.get(i);
            if (!item) continue;
            var matchesSearch = searchQuery === "" || item.name.toLowerCase().indexOf(searchQuery.toLowerCase()) !== -1;
            var matchesFilter = filterType === "All" || item.type === filterType;
            if (matchesSearch && matchesFilter) {
                count++;
            }
        }
        matchingCount = count;
    }

    onSearchQueryChanged: updateMatchingCount()
    onFilterTypeChanged: updateMatchingCount()

    Connections {
        target: mockFilesModel
        function onCountChanged() {
            mediaBrowserRoot.updateMatchingCount();
        }
    }

    Connections {
        target: timelineManager
        function onMediaSeparationCompleted(vocalsPath, instPath) {
            var vocalsName = vocalsPath.substring(Math.max(vocalsPath.lastIndexOf('/'), vocalsPath.lastIndexOf('\\')) + 1);
            var instName = instPath.substring(Math.max(instPath.lastIndexOf('/'), instPath.lastIndexOf('\\')) + 1);
            mediaBrowserRoot.addMediaFile(vocalsName, vocalsPath, "Audio", false);
            mediaBrowserRoot.addMediaFile(instName, instPath, "Audio", false);
        }
        function onMediaListChanged() {
            mockFilesModel.clear();
            var list = timelineManager.mediaList;
            for (var i = 0; i < list.length; ++i) {
                var item = list[i];
                mockFilesModel.append({
                    "name": item.name,
                    "path": item.path,
                    "type": item.type,
                    "durationMs": item.durationMs || 180000
                });
            }
            mediaBrowserRoot.updateMatchingCount();
        }
    }

    // YoutubeManager Signals Connection
    Connections {
        target: youtubeManager
        
        function onSearchCompleted(results) {
            ytResultsModel.clear();
            for (var i = 0; i < results.length; ++i) {
                ytResultsModel.append(results[i]);
            }
            lblYtStatus.text = results.length > 0 ? "" : "No results found.";
        }
        
        function onSearchFailed(error) {
            ytResultsModel.clear();
            lblYtStatus.text = error;
        }
        
        function onDownloadProgress(videoId, progress) {
            if (mediaBrowserRoot.activeDownloadVideoId === videoId) {
                mediaBrowserRoot.activeDownloadProgress = progress;
            }
        }
        
        function onDownloadCompleted(videoId, filePath, audioOnly) {
            if (mediaBrowserRoot.activeDownloadVideoId === videoId) {
                var title = mediaBrowserRoot.activeDownloadTitle;
                mediaBrowserRoot.activeDownloadVideoId = "";
                mediaBrowserRoot.activeDownloadProgress = 0.0;
                
                // Automatically register downloaded file in the Media Library list
                var ext = audioOnly ? ".wav" : ".mp4";
                var cleanName = title.replace(/[\\/:*?"<>|]/g, "_");
                mediaBrowserRoot.addMediaFile(cleanName + ext, filePath, audioOnly ? "Audio" : "Video", true);
            }
        }
        
        function onDownloadFailed(videoId, errorMessage) {
            if (mediaBrowserRoot.activeDownloadVideoId === videoId) {
                mediaBrowserRoot.activeDownloadVideoId = "";
                mediaBrowserRoot.activeDownloadProgress = 0.0;
                lblYtStatus.text = "Download Failed: " + errorMessage;
            }
        }
    }

    function updateMediaListInManager() {
        var list = [];
        for (var i = 0; i < mockFilesModel.count; ++i) {
            var item = mockFilesModel.get(i);
            list.push({
                "name": item.name,
                "path": item.path,
                "type": item.type,
                "durationMs": item.durationMs || 180000
            });
        }
        timelineManager.mediaList = list;
        timelineManager.setDirty(true);
    }

    function addMediaFile(name, path, type, autoPut) {
        // Prevent duplicate entries in media browser
        for (var i = 0; i < mockFilesModel.count; ++i) {
            if (mockFilesModel.get(i).path === path) {
                mediaBrowserRoot.selectedMediaIdx = i;
                if (autoPut) {
                    autoPutToTimeline(path, type);
                }
                return;
            }
        }

        mockFilesModel.append({
            "name": name,
            "path": path,
            "type": type,
            "durationMs": 180000
        });
        mediaBrowserRoot.selectedMediaIdx = mockFilesModel.count - 1;

        updateMediaListInManager();

        if (autoPut) {
            autoPutToTimeline(path, type);
        }
    }

    function autoPutToTimeline(path, type) {
        // Find currently selected track or first compatible track
        var track = propertiesPanel.selectedTrack;
        var i;
        if (!track || track.trackType !== (type === "Video" ? 1 : (type === "Audio" ? 0 : 2))) {
            track = null;
            for (i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                var t = timelineManager.trackListModel.tracks()[i];
                if (type === "Video" && t.trackType === 1) {
                    track = t;
                    break;
                } else if (type === "Audio" && t.trackType === 0) {
                    track = t;
                    break;
                } else if (type === "Lyrics" && t.trackType === 2) {
                    track = t;
                    break;
                }
            }
        }

        // Dynamic creation if compatible track does not exist
        if (!track) {
            if (type === "Video") {
                var newVidTrackId = timelineManager.addTrack(1, "Video Track " + (timelineManager.trackListModel.rowCount() + 1));
                for (i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                    var nt = timelineManager.trackListModel.tracks()[i];
                    if (nt.trackId === newVidTrackId) {
                        track = nt;
                        break;
                    }
                }
            } else if (type === "Audio") {
                var newTrackId = timelineManager.addTrack(0, "Audio Track " + (timelineManager.trackListModel.rowCount() + 1));
                for (i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                    var nt2 = timelineManager.trackListModel.tracks()[i];
                    if (nt2.trackId === newTrackId) {
                        track = nt2;
                        break;
                    }
                }
            } else if (type === "Lyrics") {
                var newLyrTrackId = timelineManager.addTrack(2, "Lyrics Track " + (timelineManager.trackListModel.rowCount() + 1));
                for (i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                    var nlt = timelineManager.trackListModel.tracks()[i];
                    if (nlt.trackId === newLyrTrackId) {
                        track = nlt;
                        break;
                    }
                }
            }
        }

        if (track) {
            var clipCount = track.clips().length;
            var clipId = "clip_" + (clipCount + 1);
            var startUs = timelineManager.currentPlayheadTime;
            var durUs = (track.trackType === 2) ? 4000000 : 0; // 0 lets C++ auto-detect length

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

    // timed lyrics finder logic
    function searchLyrics(title, artist) {
        if (title.trim() === "" && artist.trim() === "") {
            lblLrcStatus.text = "Please enter a song title or artist.";
            return;
        }
        lblLrcStatus.text = "Searching timed lyrics database...";
        lrcResultsModel.clear();
        mediaBrowserRoot.selectedLrcItem = null;
        
        var xhr = new XMLHttpRequest();
        var url = "https://lrclib.net/api/search?track_name=" + encodeURIComponent(title) + "&artist_name=" + encodeURIComponent(artist);
        
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText);
                        if (res.length === 0) {
                            lblLrcStatus.text = "No matched lyrics found.";
                            return;
                        }
                        
                        var foundCount = 0;
                        for (var i = 0; i < res.length; ++i) {
                            var item = res[i];
                            // Filter only results that have synced lyrics
                            if (item.syncedLyrics && item.syncedLyrics.trim() !== "") {
                                lrcResultsModel.append({
                                    "id": item.id,
                                    "title": item.trackName || "Unknown",
                                    "artist": item.artistName || "Unknown",
                                    "album": item.albumName || "N/A",
                                    "duration": item.duration || 0,
                                    "syncedLyrics": item.syncedLyrics || "",
                                    "plainLyrics": item.plainLyrics || ""
                                });
                                foundCount++;
                            }
                        }
                        
                        if (foundCount > 0) {
                            lblLrcStatus.text = "";
                        } else {
                            lblLrcStatus.text = "Lyrics found, but they are not synchronized (no timings).";
                        }
                    } catch (e) {
                        lblLrcStatus.text = "Error parsing server response.";
                    }
                } else {
                    lblLrcStatus.text = "LRC service unavailable (status " + xhr.status + ").";
                }
            }
        }
        xhr.open("GET", url, true);
        xhr.send();
    }

    function importLyricsToTimeline(lrcText) {
        var track = null;
        var i;
        // Search first compatible lyrics track on timeline
        for (i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
            var t = timelineManager.trackListModel.tracks()[i];
            if (t.trackType === 2) {
                track = t;
                break;
            }
        }
        
        // Auto-create lyrics track if not found
        if (!track) {
            var newLyrTrackId = timelineManager.addTrack(2, "Karaoke Subtitles " + (timelineManager.trackListModel.rowCount() + 1));
            for (i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                var nt = timelineManager.trackListModel.tracks()[i];
                if (nt.trackId === newLyrTrackId) {
                    track = nt;
                    break;
                }
            }
        }
        
        if (track) {
            // Auto-clear existing clips on the matched lyrics track to prevent cluttering
            if (!track.isLocked) {
                track.clearClips();
            }
            
            var success = timelineManager.importLyricsFromString(track.trackId, lrcText);
            if (success) {
                console.log("[LYRICS FINDER] Synced lyrics successfully imported!");
                propertiesPanel.selectedTrack = track;
                rootWindow.lastPlayheadTime = -1; // Invalidate rendering cache
                rootWindow.updateCachedClips();
            } else {
                lblLrcStatus.text = "Failed to parse timed lyrics tags.";
            }
        }
    }

    // YouTube downloader helper
    function downloadVideo(videoId, audioOnly, title) {
        if (mediaBrowserRoot.activeDownloadVideoId !== "") {
            lblYtStatus.text = "A download is already active.";
            return;
        }
        
        mediaBrowserRoot.activeDownloadVideoId = videoId;
        mediaBrowserRoot.activeDownloadProgress = 0.0;
        mediaBrowserRoot.activeDownloadTitle = title;
        lblYtStatus.text = "";
        
        // Save directly in the project's 'video' folder
        var saveDir = "D:/Document/NC-Project/NC-KTV/NC-KTV_V2/video";
        youtubeManager.download(videoId, audioOnly, saveDir);
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // Sleek Tab Navigation Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    { "text": "LIBRARY", "tabIdx": 0 },
                    { "text": "LYRICS FINDER", "tabIdx": 1 },
                    { "text": "YT DISCOVER", "tabIdx": 2 }
                ]
                delegate: Button {
                    id: tabBtn
                    text: modelData.text
                    Layout.fillWidth: true
                    implicitHeight: 26
                    
                    property bool isActive: mediaBrowserRoot.currentTab === modelData.tabIdx
                    
                    onClicked: mediaBrowserRoot.currentTab = modelData.tabIdx
                    
                    background: Rectangle {
                        color: tabBtn.isActive ? "#2A1F4D" : (tabBtn.hovered ? "#1E1A2E" : "#111116")
                        radius: 4
                        border.color: tabBtn.isActive ? rootWindow.colorAccentViolet : "#222"
                        border.width: 1
                    }
                    contentItem: Text {
                        text: tabBtn.text
                        font.bold: true
                        font.pixelSize: 12
                        font.family: "Outfit"
                        color: tabBtn.isActive ? "#FFF" : rootWindow.colorTextSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // TAB 0: ORIGINAL MEDIA LIBRARY WORKSPACE
        ColumnLayout {
            id: libraryTab
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            visible: mediaBrowserRoot.currentTab === 0

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "MEDIA LIBRARY"
                    font.bold: true
                    font.pixelSize: 15
                    color: rootWindow.colorTextPrimary
                    Layout.fillWidth: true
                }

                Button {
                    id: btnImportMedia
                    text: "IMPORT MEDIA..."
                    implicitWidth: 95
                    implicitHeight: 22
                    onClicked: mediaFileDialog.open()
                    background: Rectangle {
                        color: btnImportMedia.hovered ? rootWindow.colorAccentViolet : "#222"
                        radius: 3
                        border.color: rootWindow.colorBorder
                    }
                    contentItem: Text {
                        text: btnImportMedia.text
                        font.bold: true
                        font.pixelSize: 12
                        color: "#FFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Search & Filter Panel
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                TextField {
                    id: txtSearch
                    Layout.fillWidth: true
                    placeholderText: "🔍 Search media library..."
                    placeholderTextColor: "#5A5A6C"
                    color: rootWindow.colorTextPrimary
                    font.pixelSize: 14
                    
                    background: Rectangle {
                        color: "#16161D"
                        border.color: txtSearch.activeFocus ? rootWindow.colorAccentViolet : rootWindow.colorBorder
                        border.width: 1
                        radius: 4
                    }
                    
                    onTextChanged: mediaBrowserRoot.searchQuery = text
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: ["All", "Audio", "Video"]
                        delegate: Button {
                            id: btnFilter
                            text: modelData.toUpperCase()
                            Layout.fillWidth: true
                            implicitHeight: 18
                            
                            property bool isActive: mediaBrowserRoot.filterType === modelData
                            
                            onClicked: mediaBrowserRoot.filterType = modelData
                            
                            background: Rectangle {
                                color: btnFilter.isActive ? rootWindow.colorAccentViolet : (btnFilter.hovered ? "#222" : "#16161D")
                                radius: 3
                                border.color: btnFilter.isActive ? "#A27FFF" : rootWindow.colorBorder
                                border.width: 1
                            }
                            
                            contentItem: Text {
                                text: btnFilter.text
                                font.bold: true
                                font.pixelSize: 12
                                color: btnFilter.isActive ? "#FFF" : rootWindow.colorTextSecondary
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            ListModel {
                id: mockFilesModel
            }

            // Empty State
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                visible: mediaBrowserRoot.matchingCount === 0

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    width: parent.width - 40

                    Label {
                        text: mockFilesModel.count === 0 ? "📁" : "🔍"
                        font.pixelSize: 28
                        Layout.alignment: Qt.AlignCenter
                    }

                    Label {
                        text: mockFilesModel.count === 0 ? "Media Library is Empty" : "No Matching Media Files"
                        font.bold: true
                        font.pixelSize: 16
                        color: rootWindow.colorTextPrimary
                        Layout.alignment: Qt.AlignCenter
                    }

                    Label {
                        text: mockFilesModel.count === 0 ? 
                              "Import backing tracks or go to YT DISCOVER to download lyrics and videos." : 
                              "Try typing a different name or checking filters above."
                        font.pixelSize: 13
                        color: rootWindow.colorTextSecondary
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }

            // Assets List
            ListView {
                id: fileListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: mockFilesModel
                clip: true
                spacing: 5
                visible: mediaBrowserRoot.matchingCount > 0

                delegate: Rectangle {
                    id: fileDelegate
                    width: fileListView.width
                    
                    property bool matchesSearch: mediaBrowserRoot.searchQuery === "" || name.toLowerCase().indexOf(mediaBrowserRoot.searchQuery.toLowerCase()) !== -1
                    property bool matchesFilter: mediaBrowserRoot.filterType === "All" || type === mediaBrowserRoot.filterType
                    property bool isMatch: matchesSearch && matchesFilter
                    
                    visible: isMatch
                    height: isMatch ? 48 : 0
                    clip: true
                    
                    color: (mediaBrowserRoot.selectedMediaIdx === index) ? "#211B35" : (delegateHover.hovered ? rootWindow.colorBgCard : "#15151D")
                    border.color: (mediaBrowserRoot.selectedMediaIdx === index) ? rootWindow.colorAccentGreen : (delegateHover.hovered ? rootWindow.colorAccentViolet : rootWindow.colorBorder)
                    border.width: (mediaBrowserRoot.selectedMediaIdx === index) ? 2 : 1
                    radius: 4

                    HoverHandler { id: delegateHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 8

                        Rectangle {
                            width: 28
                            height: 28
                            radius: 4
                            color: type === "Audio" ? "#2C1E3A" : "#3A291E"
                            Label {
                                anchors.centerIn: parent
                                text: type === "Audio" ? "♫" : "🎬"
                                font.pixelSize: 16
                                color: type === "Audio" ? rootWindow.colorAccentViolet : "#FFAB40"
                            }
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Label {
                                text: name
                                font.bold: true
                                font.pixelSize: 14
                                color: rootWindow.colorTextPrimary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: (type === "Audio" ? "Audio" : "Video") + " - " + (durationMs ? (Math.floor(durationMs / 60000) + ":" + ("0" + Math.floor((durationMs % 60000) / 1000)).slice(-2)) : "3:00")
                                font.pixelSize: 12
                                color: rootWindow.colorTextSecondary
                            }
                        }

                        Button {
                            id: btnInsertClip
                            text: "ADD"
                            implicitWidth: 42
                            implicitHeight: 22
                            onClicked: {
                                var track = propertiesPanel.selectedTrack;
                                if (!track) {
                                    for (var i = 0; i < timelineManager.trackListModel.rowCount(); ++i) {
                                        var t = timelineManager.trackListModel.tracks()[i];
                                        if (type === "Video" && t.trackType === 1) { track = t; break; }
                                        else if (type === "Audio" && t.trackType === 0) { track = t; break; }
                                    }
                                    
                                    if (!track) {
                                        if (type === "Video") {
                                            var newVidTrackId = timelineManager.addTrack(1, "Video Track " + (timelineManager.trackListModel.rowCount() + 1));
                                            for (var j = 0; j < timelineManager.trackListModel.rowCount(); ++j) {
                                                if (timelineManager.trackListModel.tracks()[j].trackId === newVidTrackId) {
                                                    track = timelineManager.trackListModel.tracks()[j];
                                                    break;
                                                }
                                            }
                                        } else if (type === "Audio") {
                                            var newTrackId = timelineManager.addTrack(0, "Audio Track " + (timelineManager.trackListModel.rowCount() + 1));
                                            for (var j = 0; j < timelineManager.trackListModel.rowCount(); ++j) {
                                                if (timelineManager.trackListModel.tracks()[j].trackId === newTrackId) {
                                                    track = timelineManager.trackListModel.tracks()[j];
                                                    break;
                                                }
                                            }
                                        }
                                    }
                                }
                                if (track) {
                                    var clipCount = track.clips().length;
                                    var clipId = "clip_" + (clipCount + 1);
                                    var startUs = timelineManager.currentPlayheadTime;
                                    var durUs = 0; // auto detect
                                    
                                    var added = timelineManager.addClipToTrack(track.trackId, clipId, track.trackType, startUs, durUs, path, "");
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
                                font.pixelSize: 12
                                color: "#FFF"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    // Drag source configuration to support dragging items from internal media library to timeline
                    Item {
                        id: dragActiveTracker
                        x: 0; y: 0; width: 1; height: 1
                        Drag.active: dragMouseArea.drag.active
                        Drag.keys: ["text/uri-list"]
                        Drag.mimeData: { "text/uri-list": "file:///" + path.replace(/\\/g, "/") }
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.CopyAction
                    }

                    MouseArea {
                        id: dragMouseArea
                        anchors.fill: parent
                        drag.target: dragActiveTracker
                        onClicked: mediaBrowserRoot.selectedMediaIdx = index
                        onDoubleClicked: rootWindow.loadIntoSourceMonitor(path, type, name)
                    }
                }
            }

            // AI Stem Separation Panel
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 145
                color: "#161224"
                border.color: rootWindow.colorAccentViolet
                border.width: 1
                radius: 6

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 6

                    Label {
                        text: "AI STEM SEPARATION (ONNX)"
                        font.bold: true
                        font.pixelSize: 14
                        color: rootWindow.colorAccentViolet
                    }

                    Label {
                        text: "Separate audio into vocals & instrumentals instantly using ONNX GPU model acceleration."
                        font.pixelSize: 12
                        color: rootWindow.colorTextSecondary
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Label {
                            Layout.fillWidth: true
                            text: "Model: " + (timelineManager.modelPath !== "" ? 
                                  timelineManager.modelPath.substring(timelineManager.modelPath.lastIndexOf('/') + 1) 
                                  : "DSP MS Fallback")
                            font.pixelSize: 12
                            color: rootWindow.colorTextSecondary
                            elide: Text.ElideMiddle
                        }

                        Button {
                            id: btnSelectFileMedia
                            text: "Model..."
                            implicitWidth: 55
                            implicitHeight: 18
                            onClicked: modelFileDialog.open()
                            background: Rectangle {
                                color: btnSelectFileMedia.hovered ? "#2D264A" : "#1B1B22"
                                radius: 3
                                border.color: rootWindow.colorAccentViolet
                            }
                            contentItem: Text {
                                text: btnSelectFileMedia.text
                                font.bold: true
                                font.pixelSize: 12
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
                                return "SEPARATING (" + Math.round(timelineManager.separationProgress * 100) + "%)...";
                            }
                            if (propertiesPanel.selectedClip && propertiesPanel.selectedClip.clipType === 0) {
                                return "PROCESS TIMELINE AUDIO CLIP";
                            }
                            if (mediaBrowserRoot.selectedMediaIdx !== -1) {
                                return "PROCESS SELECTED Backing Track";
                            }
                            return "PROCESS SELECTED CLIP";
                        }
                        Layout.fillWidth: true
                        implicitHeight: 28
                        enabled: !timelineManager.isSeparating && (
                            (propertiesPanel.selectedClip && propertiesPanel.selectedClip.clipType === 0) ||
                            (mediaBrowserRoot.selectedMediaIdx !== -1)
                        )
                        onClicked: {
                            if (propertiesPanel.selectedClip && propertiesPanel.selectedClip.clipType === 0) {
                                timelineManager.separateStems(propertiesPanel.selectedClip.clipId);
                            } else if (mediaBrowserRoot.selectedMediaIdx !== -1) {
                                var path = mockFilesModel.get(mediaBrowserRoot.selectedMediaIdx).path;
                                timelineManager.separateStemsForFile(path);
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
                            font.pixelSize: 13
                            color: btnProcessAI.enabled ? "#FFF" : "#666"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: timelineManager.isSeparating || timelineManager.separationProgress > 0
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: timelineManager.separationStatusText
                                font.pixelSize: 12
                                color: rootWindow.colorTextSecondary
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Label {
                                text: Math.round(timelineManager.separationProgress * 100) + "%"
                                font.pixelSize: 12
                                font.bold: true
                                color: rootWindow.colorAccentGreen
                            }
                        }

                        ProgressBar {
                            id: aiProgress
                            Layout.fillWidth: true
                            implicitHeight: 3
                            value: timelineManager.separationProgress
                            background: Rectangle { color: "#2C203E"; radius: 2 }
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

        // TAB 1: TIMED LYRICS FINDER (LRCLIB API)
        ColumnLayout {
            id: lyricsTab
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            visible: mediaBrowserRoot.currentTab === 1

            Label {
                text: "TIMED LYRICS FINDER (LRCLIB)"
                font.bold: true
                font.pixelSize: 15
                color: rootWindow.colorTextPrimary
            }

            Label {
                text: "Fetch synchronized, word-by-word timed LRC lyrics directly from lrclib open timed database."
                font.pixelSize: 12
                color: rootWindow.colorTextSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Dual search input fields
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                TextField {
                    id: txtLrcTitle
                    Layout.fillWidth: true
                    placeholderText: "Track name (e.g. Stay)..."
                    placeholderTextColor: "#5A5A6C"
                    color: rootWindow.colorTextPrimary
                    font.pixelSize: 13
                    background: Rectangle { color: "#16161D"; border.color: rootWindow.colorBorder; radius: 4 }
                    onAccepted: btnLrcSearch.clicked()
                }

                TextField {
                    id: txtLrcArtist
                    Layout.fillWidth: true
                    placeholderText: "Artist (optional)..."
                    placeholderTextColor: "#5A5A6C"
                    color: rootWindow.colorTextPrimary
                    font.pixelSize: 13
                    background: Rectangle { color: "#16161D"; border.color: rootWindow.colorBorder; radius: 4 }
                    onAccepted: btnLrcSearch.clicked()
                }
            }

            Button {
                id: btnLrcSearch
                text: "SEARCH SYNCHRONIZED LYRICS"
                Layout.fillWidth: true
                implicitHeight: 26
                onClicked: mediaBrowserRoot.searchLyrics(txtLrcTitle.text, txtLrcArtist.text)
                background: Rectangle {
                    color: btnLrcSearch.hovered ? rootWindow.colorAccentViolet : "#7C4DFF"
                    radius: 4
                }
                contentItem: Text {
                    text: btnLrcSearch.text
                    font.bold: true
                    font.pixelSize: 13
                    color: "#FFF"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Label {
                id: lblLrcStatus
                text: ""
                font.pixelSize: 13
                color: "#E57373"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: text !== ""
            }

            ListModel {
                id: lrcResultsModel
            }

            // Results List
            ListView {
                id: lrcListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: lrcResultsModel
                clip: true
                spacing: 4
                visible: count > 0

                delegate: Rectangle {
                    width: lrcListView.width
                    height: 40
                    color: (mediaBrowserRoot.selectedLrcItem === model) ? "#211B35" : (lrcHover.hovered ? rootWindow.colorBgCard : "#15151D")
                    border.color: (mediaBrowserRoot.selectedLrcItem === model) ? rootWindow.colorAccentGreen : "#222"
                    border.width: 1
                    radius: 4

                    HoverHandler { id: lrcHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 6

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Label {
                                text: title
                                font.bold: true
                                font.pixelSize: 13
                                color: "#FFF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: artist + " - " + album
                                font.pixelSize: 12
                                color: rootWindow.colorTextSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Label {
                            text: "⏱ Synced"
                            font.pixelSize: 12
                            font.bold: true
                            color: rootWindow.colorAccentGreen
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            // Assign selected result object
                            mediaBrowserRoot.selectedLrcItem = {
                                "id": model.id,
                                "title": model.title,
                                "artist": model.artist,
                                "syncedLyrics": model.syncedLyrics,
                                "plainLyrics": model.plainLyrics
                            };
                        }
                    }
                }
            }

            // Selected Item Lyrics Preview Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                color: "#0C0C0F"
                border.color: "#1E1E26"
                border.width: 1
                radius: 4
                clip: true
                visible: mediaBrowserRoot.selectedLrcItem !== null

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 6
                    
                    Text {
                        width: parent.width - 12
                        text: mediaBrowserRoot.selectedLrcItem ? mediaBrowserRoot.selectedLrcItem.syncedLyrics : ""
                        color: "#8A8A9E"
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Button {
                id: btnLrcImport
                text: "IMPORT LYRICS INTO SUBTITLE TRACK"
                Layout.fillWidth: true
                implicitHeight: 30
                enabled: mediaBrowserRoot.selectedLrcItem !== null
                onClicked: {
                    mediaBrowserRoot.importLyricsToTimeline(mediaBrowserRoot.selectedLrcItem.syncedLyrics);
                }
                background: Rectangle {
                    color: btnLrcImport.enabled ? (btnLrcImport.hovered ? rootWindow.colorAccentGreen : "#00E676") : "#333"
                    radius: 4
                }
                contentItem: Text {
                    text: btnLrcImport.text
                    font.bold: true
                    font.pixelSize: 13
                    color: btnLrcImport.enabled ? "#000" : "#666"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // TAB 2: YOUTUBE SONG SEARCH + DOWNLOAD (yt-dlp)
        ColumnLayout {
            id: ytTab
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            visible: mediaBrowserRoot.currentTab === 2

            Label {
                text: "YOUTUBE DISCOVER & DOWNLOADER"
                font.bold: true
                font.pixelSize: 15
                color: rootWindow.colorTextPrimary
            }

            Label {
                text: "Find background instrumental or guide videos on YouTube and download high-quality assets directly."
                font.pixelSize: 12
                color: rootWindow.colorTextSecondary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            // Search query layout
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                TextField {
                    id: txtYtQuery
                    Layout.fillWidth: true
                    placeholderText: "Search YouTube (e.g. Queen karaoke BGM)..."
                    placeholderTextColor: "#5A5A6C"
                    color: rootWindow.colorTextPrimary
                    font.pixelSize: 13
                    background: Rectangle { color: "#16161D"; border.color: rootWindow.colorBorder; radius: 4 }
                    onAccepted: btnYtSearch.clicked()
                }

                Button {
                    id: btnYtSearch
                    text: youtubeManager.isSearching ? "⏳" : "🔍"
                    implicitWidth: 36
                    implicitHeight: 26
                    enabled: !youtubeManager.isSearching
                    onClicked: {
                        mediaBrowserRoot.selectedYtItem = null;
                        youtubeManager.search(txtYtQuery.text);
                    }
                    background: Rectangle {
                        color: btnYtSearch.hovered ? rootWindow.colorAccentViolet : "#222"
                        radius: 4
                        border.color: rootWindow.colorBorder
                    }
                    contentItem: Text {
                        text: btnYtSearch.text
                        font.bold: true
                        font.pixelSize: 14
                        color: "#FFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Label {
                id: lblYtStatus
                text: ""
                font.pixelSize: 13
                color: "#FFD54F"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: text !== ""
            }

            ListModel {
                id: ytResultsModel
            }

            // YouTube matched list
            ListView {
                id: ytListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: ytResultsModel
                clip: true
                spacing: 5
                visible: count > 0 && !youtubeManager.isSearching

                delegate: Rectangle {
                    width: ytListView.width
                    height: 52
                    clip: true
                    color: (mediaBrowserRoot.selectedYtItem === model) ? "#211B35" : (ytHover.hovered ? rootWindow.colorBgCard : "#15151D")
                    border.color: (mediaBrowserRoot.selectedYtItem === model) ? rootWindow.colorAccentGreen : "#222"
                    border.width: 1
                    radius: 4

                    HoverHandler { id: ytHover }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 8

                        // Video Thumbnail Mock/Constructed image
                        Item {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 44
                            Layout.fillWidth: false
                            Layout.fillHeight: false
                            clip: true

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                source: thumbnail
                                asynchronous: true
                                
                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: "#2C2C3E"
                                    border.width: 1
                                    radius: 2
                                }
                            }
                            
                            // Duration Overlay Box
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 2
                                color: "#000"
                                opacity: 0.8
                                width: 26
                                height: 11
                                radius: 2
                                Label {
                                    anchors.centerIn: parent
                                    text: durationStr
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: "#FFF"
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 1
                            Layout.fillWidth: true
                            Label {
                                text: title
                                font.bold: true
                                font.pixelSize: 13
                                color: "#FFF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Label {
                                text: channel
                                font.pixelSize: 12
                                color: rootWindow.colorTextSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            mediaBrowserRoot.selectedYtItem = {
                                "id": id,
                                "title": title,
                                "channel": channel,
                                "thumbnail": thumbnail,
                                "durationStr": durationStr
                            };
                        }
                    }
                }
            }

            // Downloader Details Card & Action row
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                visible: mediaBrowserRoot.selectedYtItem !== null

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: "#222"
                }

                // Compact Selected YouTube Item Card
                Rectangle {
                    Layout.fillWidth: true
                    height: 80
                    color: "#0F0F13"
                    border.color: "#1E1E26"
                    border.width: 1
                    radius: 6
                    clip: true

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 10

                        // Thumbnail container with Duration Overlay
                        Item {
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 64
                            Layout.fillWidth: false
                            Layout.fillHeight: false
                            Layout.alignment: Qt.AlignVCenter
                            clip: true

                            Image {
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                source: mediaBrowserRoot.selectedYtItem ? mediaBrowserRoot.selectedYtItem.thumbnail : ""
                                asynchronous: true

                                Rectangle {
                                    anchors.fill: parent
                                    color: "transparent"
                                    border.color: "#2C2C3E"
                                    border.width: 1
                                    radius: 4
                                }
                            }

                            // Duration Overlay Box
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 4
                                color: "#000"
                                opacity: 0.8
                                width: 34
                                height: 14
                                radius: 2
                                Label {
                                    anchors.centerIn: parent
                                    text: mediaBrowserRoot.selectedYtItem ? mediaBrowserRoot.selectedYtItem.durationStr : ""
                                    font.pixelSize: 10
                                    font.bold: true
                                    color: "#FFF"
                                }
                            }
                        }

                        // Title, Channel and Preview details
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Layout.alignment: Qt.AlignVCenter

                            Label {
                                text: mediaBrowserRoot.selectedYtItem ? mediaBrowserRoot.selectedYtItem.title : ""
                                font.bold: true
                                font.pixelSize: 13
                                color: "#FFF"
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            Label {
                                text: mediaBrowserRoot.selectedYtItem ? mediaBrowserRoot.selectedYtItem.channel : ""
                                font.pixelSize: 12
                                color: rootWindow.colorTextSecondary
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }

                            // Preview Button
                            Button {
                                id: btnPreview
                                text: "▶ PREVIEW IN BROWSER"
                                implicitHeight: 20
                                Layout.preferredWidth: 140
                                onClicked: {
                                    if (mediaBrowserRoot.selectedYtItem) {
                                        Qt.openUrlExternally("https://www.youtube.com/watch?v=" + mediaBrowserRoot.selectedYtItem.id);
                                    }
                                }
                                background: Rectangle {
                                    color: btnPreview.hovered ? "#3A2E4C" : "#251D33"
                                    radius: 3
                                    border.color: rootWindow.colorAccentViolet
                                    border.width: 1
                                }
                                contentItem: Text {
                                    text: btnPreview.text
                                    font.bold: true
                                    font.pixelSize: 10
                                    color: rootWindow.colorAccentViolet
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                }

                // Action buttons stacked vertically to ensure font fits inside the button boxes
                ColumnLayout {
                    spacing: 6
                    Layout.fillWidth: true

                    Button {
                        id: btnDlAudio
                        text: "DOWNLOAD AUDIO BACKING (WAV)"
                        Layout.fillWidth: true
                        implicitHeight: 32
                        enabled: mediaBrowserRoot.activeDownloadVideoId === ""
                        onClicked: {
                            mediaBrowserRoot.downloadVideo(mediaBrowserRoot.selectedYtItem.id, true, mediaBrowserRoot.selectedYtItem.title);
                        }
                        background: Rectangle {
                            color: btnDlAudio.enabled ? (btnDlAudio.hovered ? "#4C1C6C" : "#2C1E3A") : "#333"
                            radius: 4
                            border.color: btnDlAudio.enabled ? rootWindow.colorAccentViolet : "#222"
                        }
                        contentItem: Text {
                            text: btnDlAudio.text
                            font.bold: true
                            font.pixelSize: 12
                            color: btnDlAudio.enabled ? "#FFF" : "#666"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        id: btnDlVideo
                        text: "DOWNLOAD VIDEO GUIDE (MP4)"
                        Layout.fillWidth: true
                        implicitHeight: 32
                        enabled: mediaBrowserRoot.activeDownloadVideoId === ""
                        onClicked: {
                            mediaBrowserRoot.downloadVideo(mediaBrowserRoot.selectedYtItem.id, false, mediaBrowserRoot.selectedYtItem.title);
                        }
                        background: Rectangle {
                            color: btnDlVideo.enabled ? (btnDlVideo.hovered ? "#5E2909" : "#3A291E") : "#333"
                            radius: 4
                            border.color: btnDlVideo.enabled ? "#FFAB40" : "#222"
                        }
                        contentItem: Text {
                            text: btnDlVideo.text
                            font.bold: true
                            font.pixelSize: 12
                            color: btnDlVideo.enabled ? "#FFF" : "#666"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }

            // Real-Time Progress Bar Section
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: mediaBrowserRoot.activeDownloadVideoId !== ""

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Downloading: " + mediaBrowserRoot.activeDownloadTitle
                        font.pixelSize: 12
                        color: "#FFD54F"
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Label {
                        text: Math.round(mediaBrowserRoot.activeDownloadProgress * 100) + "%"
                        font.pixelSize: 12
                        font.bold: true
                        color: rootWindow.colorAccentGreen
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    ProgressBar {
                        id: dlProgress
                        Layout.fillWidth: true
                        implicitHeight: 4
                        value: mediaBrowserRoot.activeDownloadProgress
                        background: Rectangle { color: "#2C203E"; radius: 2 }
                        contentItem: Item {
                            Rectangle {
                                width: dlProgress.visualPosition * parent.width
                                height: parent.height
                                radius: 2
                                color: rootWindow.colorAccentGreen
                            }
                        }
                    }

                    Button {
                        id: btnDlCancel
                        text: "CANCEL"
                        implicitWidth: 46
                        implicitHeight: 18
                        onClicked: {
                            youtubeManager.cancelDownload(mediaBrowserRoot.activeDownloadVideoId);
                        }
                        background: Rectangle {
                            color: btnDlCancel.hovered ? "#CC3333" : "#801A1A"
                            radius: 3
                        }
                        contentItem: Text {
                            text: btnDlCancel.text
                            font.bold: true
                            font.pixelSize: 11
                            color: "#FFF"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
