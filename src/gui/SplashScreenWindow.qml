import QtQuick
import QtQuick.Controls

Window {
    id: splashWindow
    width: 800
    height: 600
    visible: true
    title: "NC-KTV Karaoke - Loading..."
    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: "transparent"

    // Theme Colors
    readonly property color colorBg: "#190C2D"
    readonly property color colorOnBg: "#ECDCFF"
    readonly property color colorPrimary: "#FFB1C3"
    readonly property color colorSecondaryGlow: "#00EEFC"
    readonly property color colorSurfaceContainer: "#26193A"
    readonly property color colorBorderTranslucent: "#40FFFFFF"

    // Progress properties
    property real loaderProgress: 0.0
    property bool loadingComplete: false

    // Signal emitted when loading animation is fully finished
    signal loadingFinished()

    // ─── Main Visual Board ───
    Rectangle {
        id: bgContainer
        anchors.fill: parent
        color: splashWindow.colorBg
        radius: 16 // Elegant rounded corners for splash screen window
        border.color: "#30FFFFFF"
        border.width: 1
        clip: true

        // Top-Left Primary Pulsing Light Streak
        Rectangle {
            x: -250
            y: -250
            width: 600
            height: 600
            radius: 300
            color: splashWindow.colorPrimary
            opacity: 0.12
            z: 1

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.22; duration: 4000; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 0.12; duration: 4000; easing.type: Easing.InOutQuad }
            }
        }

        // Bottom-Right Cyan Pulsing Light Streak
        Rectangle {
            x: parent.width - 350
            y: parent.height - 350
            width: 500
            height: 500
            radius: 250
            color: splashWindow.colorSecondaryGlow
            opacity: 0.12
            z: 1

            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { to: 0.20; duration: 5000; easing.type: Easing.InOutQuad }
                NumberAnimation { to: 0.12; duration: 5000; easing.type: Easing.InOutQuad }
            }
        }

        // Center Subtle Ambient Glow
        Rectangle {
            anchors.centerIn: parent
            width: 400
            height: 400
            radius: 200
            color: "#A178FF"
            opacity: 0.06
            z: 1
        }

        // ─── Content Column ───
        Column {
            anchors.centerIn: parent
            spacing: 28
            width: Math.min(parent.width - 40, 480)
            z: 2

            // Logo with floating micro-animation
            Image {
                id: imgLogo
                source: "logo.png"
                width: 160
                height: 160
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter

                SequentialAnimation on y {
                    loops: Animation.Infinite
                    NumberAnimation { to: -12; duration: 3000; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 0; duration: 3000; easing.type: Easing.InOutQuad }
                }
            }

            // Title and Subtitle Text Card
            Column {
                width: parent.width
                spacing: 6
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    text: "NC-KTV Karaoke"
                    font.family: "Syne"
                    font.pixelSize: 38
                    font.bold: true
                    color: splashWindow.colorPrimary
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    style: Text.Outline
                    styleColor: "#40FFB1C3"
                }

                Text {
                    text: "Your Voice, Your Version"
                    font.family: "Hanken Grotesk"
                    font.pixelSize: 18
                    font.weight: Font.Normal
                    color: splashWindow.colorOnBg
                    opacity: 0.8
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            // Space before loader
            Item { width: 1; height: 16 }

            // Custom Glass Loading Bar Container
            Rectangle {
                width: parent.width - 40
                height: 8
                color: splashWindow.colorSurfaceContainer
                radius: 4
                border.color: splashWindow.colorBorderTranslucent
                border.width: 1
                anchors.horizontalCenter: parent.horizontalCenter
                clip: true

                // Glowing Progress Fill
                Rectangle {
                    height: parent.height
                    width: parent.width * splashWindow.loaderProgress
                    radius: 4
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: splashWindow.colorSecondaryGlow }
                        GradientStop { position: 1.0; color: splashWindow.colorPrimary }
                    }

                    Behavior on width {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }
                }
            }

            // Spinner / Activity Indicator Area
            Item {
                width: 48
                height: 48
                anchors.horizontalCenter: parent.horizontalCenter

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: splashWindow.colorPrimary
                    border.width: 4
                    radius: width / 2
                    visible: !splashWindow.loadingComplete

                    Rectangle {
                        width: parent.width / 2
                        height: parent.height / 2
                        color: splashWindow.colorBg
                        anchors.right: parent.right
                        anchors.top: parent.top
                    }

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: !splashWindow.loadingComplete
                    }
                }
            }
        }
    }

    // ─── Loading Logic Animation ───
    SequentialAnimation {
        running: true
        
        // Animates loader progress from 0.0 to 1.0 over 3 seconds
        NumberAnimation {
            target: splashWindow
            property: "loaderProgress"
            from: 0.0
            to: 1.0
            duration: 3000
            easing.type: Easing.OutSine
        }

        PauseAnimation { duration: 200 }

        ScriptAction {
            script: {
                splashWindow.loadingComplete = true;
            }
        }

        // Smoothly fade out the splash screen
        NumberAnimation {
            target: splashWindow
            property: "opacity"
            to: 0.0
            duration: 650
            easing.type: Easing.InOutQuad
        }

        // Signal completion to C++ launcher
        ScriptAction {
            script: {
                splashWindow.loadingFinished();
            }
        }
    }
}
