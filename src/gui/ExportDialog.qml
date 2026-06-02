import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Popup {
    id: exportPopup
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    closePolicy: Popup.NoAutoClose

    width: 500
    height: 480

    background: Rectangle {
        color: "#111115"
        border.color: "#2A2A35"
        border.width: 2
        radius: 12

        // Ambient glow effect
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            color: "transparent"
            border.color: "#3A3A4A"
            border.width: 1
            radius: 11
        }
    }

    // File Dialog to choose export path
    FileDialog {
        id: fileSaveDialog
        title: "Choose Export Destination"
        fileMode: FileDialog.SaveFile
        nameFilters: ["MPEG-4 Video (*.mp4)"]
        currentFolder: "file:///D:/Document/NC-Project/NC-KTV/NC-KTV_V2"
        onAccepted: {
            // Clean up the URL representation
            var path = selectedFile.toString();
            if (path.startsWith("file:///")) {
                path = path.substring(8);
            }
            // Remove leading slash on Windows if present
            if (Qt.platform.os === "windows" && path.charAt(0) === '/' && path.charAt(2) === ':') {
                path = path.substring(1);
            }
            txtOutPath.text = path;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 25
        spacing: 20

        // Title Block
        RowLayout {
            spacing: 10
            Rectangle {
                width: 8
                height: 24
                color: "#00E676"
                radius: 2
            }
            Label {
                text: "Export Video Pipeline"
                font.pixelSize: 23
                font.bold: true
                font.family: "Outfit"
                color: "#F0F0F5"
            }
        }

        // Configuration Form (shown when not rendering)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 15
            visible: !timelineManager.isRendering

            // Resolution Choice
            RowLayout {
                spacing: 15
                Label {
                    text: "Resolution:"
                    font.bold: true
                    color: "#8A8A9E"
                    Layout.preferredWidth: 100
                }
                ComboBox {
                    id: comboRes
                    Layout.fillWidth: true
                    model: ["1920x1080 (1080p Full HD)", "3840x2160 (4K Ultra HD)", "1280x720 (720p HD)"]
                    currentIndex: 0
                    
                    background: Rectangle {
                        color: "#1B1B22"
                        border.color: "#2A2A35"
                        radius: 6
                    }
                    contentItem: Text {
                        text: comboRes.currentText
                        color: "#F0F0F5"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                    }
                }
            }

            // Frame Rate Choice
            RowLayout {
                spacing: 15
                Label {
                    text: "Frame Rate:"
                    font.bold: true
                    color: "#8A8A9E"
                    Layout.preferredWidth: 100
                }
                ComboBox {
                    id: comboFps
                    Layout.fillWidth: true
                    model: ["30 FPS", "60 FPS"]
                    currentIndex: 0
                    
                    background: Rectangle {
                        color: "#1B1B22"
                        border.color: "#2A2A35"
                        radius: 6
                    }
                    contentItem: Text {
                        text: comboFps.currentText
                        color: "#F0F0F5"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                    }
                }
            }

            // Quality Bitrate Choice
            RowLayout {
                spacing: 15
                Label {
                    text: "Video Quality:"
                    font.bold: true
                    color: "#8A8A9E"
                    Layout.preferredWidth: 100
                }
                ComboBox {
                    id: comboQuality
                    Layout.fillWidth: true
                    model: ["High (15 Mbps)", "Standard (8 Mbps)", "Ultra HQ (30 Mbps)"]
                    currentIndex: 0
                    
                    background: Rectangle {
                        color: "#1B1B22"
                        border.color: "#2A2A35"
                        radius: 6
                    }
                    contentItem: Text {
                        text: comboQuality.currentText
                        color: "#F0F0F5"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                    }
                }
            }

            // Video Mode Choice
            RowLayout {
                spacing: 15
                Label {
                    text: "Background:"
                    font.bold: true
                    color: "#8A8A9E"
                    Layout.preferredWidth: 100
                }
                ComboBox {
                    id: comboVideoMode
                    Layout.fillWidth: true
                    model: ["Include Video Track", "Clean Background (Lyrics Only)"]
                    currentIndex: timelineManager.showVideoBackground ? 0 : 1
                    onActivated: {
                        timelineManager.showVideoBackground = (index === 0);
                    }
                    
                    background: Rectangle {
                        color: "#1B1B22"
                        border.color: "#2A2A35"
                        radius: 6
                    }
                    contentItem: Text {
                        text: comboVideoMode.currentText
                        color: "#F0F0F5"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                    }
                }
            }

            // Lyrics Layout Choice
            RowLayout {
                spacing: 15
                Label {
                    text: "Lyrics Layout:"
                    font.bold: true
                    color: "#8A8A9E"
                    Layout.preferredWidth: 100
                }
                ComboBox {
                    id: comboLyricsLayout
                    Layout.fillWidth: true
                    model: ["Standard Bottom Overlay", "Center Waiting Queue", "Word Bounce rhythm", "Cinematic Full-Screen"]
                    currentIndex: timelineManager.lyricDisplayMode
                    onActivated: {
                        timelineManager.lyricDisplayMode = index;
                    }
                    
                    background: Rectangle {
                        color: "#1B1B22"
                        border.color: "#2A2A35"
                        radius: 6
                    }
                    contentItem: Text {
                        text: comboLyricsLayout.currentText
                        color: "#F0F0F5"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                    }
                }
            }

            // Audio Export Mode Choice
            RowLayout {
                spacing: 15
                Label {
                    text: "Audio Mix:"
                    font.bold: true
                    color: "#8A8A9E"
                    Layout.preferredWidth: 100
                }
                ComboBox {
                    id: comboAudioMode
                    Layout.fillWidth: true
                    model: ["Full Sound Mix", "Instrumental Track Only"]
                    currentIndex: timelineManager.exportAudioMode
                    onActivated: {
                        timelineManager.exportAudioMode = index;
                    }
                    
                    background: Rectangle {
                        color: "#1B1B22"
                        border.color: "#2A2A35"
                        radius: 6
                    }
                    contentItem: Text {
                        text: comboAudioMode.currentText
                        color: "#F0F0F5"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 10
                    }
                }
            }

            // Output File Destination
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Label {
                    text: "Destination Path:"
                    font.bold: true
                    color: "#8A8A9E"
                }
                RowLayout {
                    spacing: 10
                    TextField {
                        id: txtOutPath
                        Layout.fillWidth: true
                        text: "D:/Document/NC-Project/NC-KTV/NC-KTV_V2/export.mp4"
                        placeholderText: "Output video file path..."
                        color: "#F0F0F5"
                        font.pixelSize: 16
                        
                        background: Rectangle {
                            color: "#1B1B22"
                            border.color: "#2A2A35"
                            radius: 6
                        }
                    }
                    Button {
                        text: "Browse..."
                        onClicked: fileSaveDialog.open()
                        contentItem: Text {
                            text: "Browse..."
                            color: "#F0F0F5"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            color: "#2D264A"
                            radius: 6
                            border.color: "#7C4DFF"
                        }
                    }
                }
            }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 20
                spacing: 15

                Button {
                    Layout.fillWidth: true
                    text: "Cancel"
                    onClicked: exportPopup.close()
                    contentItem: Text {
                        text: "Cancel"
                        color: "#8A8A9E"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "#1B1B22"
                        border.color: "#2A2A35"
                        radius: 6
                    }
                }

                Button {
                    Layout.fillWidth: true
                    text: "Start Export"
                    onClicked: {
                        // Gather settings
                        var w = 1920;
                        var h = 1080;
                        if (comboRes.currentIndex === 1) {
                            w = 3840; h = 2160;
                        } else if (comboRes.currentIndex === 2) {
                            w = 1280; h = 720;
                        }

                        var fpsVal = 30;
                        if (comboFps.currentIndex === 1) {
                            fpsVal = 60;
                        }

                        var bitrate = 15000000; // 15mbps
                        if (comboQuality.currentIndex === 1) {
                            bitrate = 8000000;
                        } else if (comboQuality.currentIndex === 2) {
                            bitrate = 30000000;
                        }

                        timelineManager.startExport(txtOutPath.text, w, h, fpsVal, bitrate, 192000);
                    }
                    contentItem: Text {
                        text: "Start Export"
                        color: "#F0F0F5"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: "#0E3A2F"
                        border.color: "#00E676"
                        radius: 6
                    }
                }
            }
        }

        // Rendering Progress Overlay (shown during active render exports)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 20
            visible: timelineManager.isRendering || timelineManager.renderProgress >= 0.99

            // Status Indicator Icon / Pulse
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: timelineManager.renderProgress >= 1.0 ? "#00E676" : "#7C4DFF"
                    
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: timelineManager.isRendering
                        NumberAnimation { from: 1.0; to: 0.4; duration: 800 }
                        NumberAnimation { from: 0.4; to: 1.0; duration: 800 }
                    }
                }
                Label {
                    text: timelineManager.renderProgress >= 1.0 ? "Export Completed!" : "Encoding Audio & Video Tracks..."
                    font.pixelSize: 18
                    font.bold: true
                    color: "#F0F0F5"
                }
            }

            // Shimmering Progress Bar
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    height: 12
                    color: "#1B1B22"
                    radius: 6
                    clip: true

                    // Progress fill
                    Rectangle {
                        width: parent.width * timelineManager.renderProgress
                        height: parent.height
                        radius: 6
                        
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#7C4DFF" }
                            GradientStop { position: 1.0; color: "#00E676" }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: timelineManager.renderStatusText
                        font.pixelSize: 15
                        color: "#8A8A9E"
                        Layout.fillWidth: true
                    }
                    Label {
                        text: Math.round(timelineManager.renderProgress * 100) + "%"
                        font.pixelSize: 17
                        font.bold: true
                        color: "#00E676"
                    }
                }
            }

            // Close / Cancel Buttons during render
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 20
                Layout.alignment: Qt.AlignHCenter
                
                Button {
                    Layout.preferredWidth: 200
                    text: timelineManager.renderProgress >= 1.0 ? "Close" : "Cancel Export"
                    onClicked: {
                        if (timelineManager.renderProgress >= 1.0) {
                            exportPopup.close();
                        } else {
                            timelineManager.cancelExport();
                        }
                    }
                    contentItem: Text {
                        text: timelineManager.renderProgress >= 1.0 ? "Close" : "Cancel Export"
                        color: "#F0F0F5"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: timelineManager.renderProgress >= 1.0 ? "#2D264A" : "#3D1313"
                        border.color: timelineManager.renderProgress >= 1.0 ? "#7C4DFF" : "#FF5252"
                        radius: 6
                    }
                }
            }
        }
    }
}
