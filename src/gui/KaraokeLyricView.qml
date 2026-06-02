import QtQuick
import QtQuick.Controls
import ncktv.core 1.0

// ─────────────────────────────────────────────────────────────────────────────
// KaraokeLyricView — High-performance karaoke lyric rendering component
// Delegated to the C++ KaraokeLyricRenderer custom painter for 60 FPS rendering,
// timing-accurate progressive sweeps, guide cursor glows, and cinematic layouts.
// ─────────────────────────────────────────────────────────────────────────────

Item {
    id: root

    // ── Required Properties ──────────────────────────────────────────────────
    property var lyricEngine: null

    // Font styling (bound from timelineManager subtitle properties)
    property string fontFamily: "Georgia"
    property int fontSize: 28
    property color fillColor: "#808080"
    property color activeColor: "#FFFFFF"
    property color outlineColor: "#000000"
    property int outlineWidth: 2

    // Current playhead time (microseconds)
    property real currentPlayheadTime: 0

    // ── High Performance C++ Custom Painter ──────────────────────────────────
    KaraokeLyricRenderer {
        id: renderer
        anchors.fill: parent
        lyricEngine: root.lyricEngine
        
        displayMode: {
            if (root.lyricEngine) {
                return root.lyricEngine.displayMode;
            }
            return 0;
        }

        fontFamily: root.fontFamily
        fontSize: root.fontSize
        fillColor: root.fillColor
        activeColor: root.activeColor
        outlineColor: root.outlineColor
        outlineWidth: root.outlineWidth
        currentTimestamp: root.currentPlayheadTime / 1000 // Convert microseconds to milliseconds
        
        // Solid black background for WordBounce, dark gradient for Cinema, transparent for overlays
        backgroundColor: {
            var mode = root.lyricEngine ? root.lyricEngine.displayMode : 0;
            if (mode === 2) {
                return "#000000"; // WordBounce: Solid Black
            } else if (mode === 3) {
                return "#0F0F15"; // Cinema: Dark Vignette Gradient
            }
            return "#00000000"; // BottomTwoLine & CenterScrollQueue: Transparent overlay (drawn on top of video)
        }

        showGuideCursor: true
        vignetteEnabled: true
    }
}
