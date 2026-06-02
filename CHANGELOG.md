# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Internal Media Library drag-and-drop support: you can now drag-and-drop media assets directly from the Media Browser list onto the timeline tracks to insert them.
- Global persistent software decoding preference setting (`disable_hw_decoding` in `QSettings`) that disables hardware acceleration for the Qt Multimedia FFmpeg backend on startup to resolve device/texture allocation failures (like `8007000e`) for 4K and AV1 files.
- One-click recovery toggle button ("Switch to Software Decoding & Restart") directly inside the playback error/warning dialog to allow instant switching to software mode when a video fails to play.
- "SYSTEM DECODING PREFERENCES" card in the global metadata properties panel to view the active decoding mode and manually switch between Hardware (Fast) and Software (Safe) modes with a restart prompt.
- `disableHwDecoding` and `setDisableHwDecoding` settings controls and a `restartApplication` helper to the C++ `TimelineManager` backend.
- Syllable-level timing and tuning methods to the C++ core backend (`Clip::updateSyllable`).
- Interactive Syllable Tuning Inspector in the clip properties panel supporting 50ms nudging controls.
- Live audio visualizer canvas rendering a spectrum sine wave inside the preview monitor.
- Lookahead lyrics overlay display in the preview monitor, showing the active cue and upcoming lyrics line.
- Search and filter layout in the Media Library panel.
- Stationary track headers layout in the timeline grid, ensuring that track titles, volumes, and controls remain pinned to the left edge of the viewport during horizontal scrolling.
- Horizontal time ruler cover to block scrolling ticks behind the stationary header block.
- Playhead and clip guide visual tooltip displaying current timeline timecodes during drag operations.
- Master volume control slider inside the transport deck.
- Shortcut Guide helper dialog mapping core keyboard shortcuts.
- Project Save and Load UI buttons and status text alerts.
- Magnetic snapping to exactly 0s in the timeline snapping engine.
- Real-time progress percentage updates and status text in both the Media Library panel and the Properties Panel during stem separation.
- Automated auto-put logic to instantly place imported media files into compatible tracks at the current playhead time on the timeline.
- Fully functional "+ VIDEO TRACK" creation button in the timeline control header.
- Custom orange color accents and layout styling tags for Video Tracks inside the timeline lane headers.
- Horizontal playback auto-scrolling viewport follow in TimelineView.qml, automatically keeping the playhead visible and centered at 25% of the tracks area during active playback.

### Changed
- Re-anchored the root window's global `DropArea` and glassmorphic overlay to exclude the timeline editor area. This prevents the global drop area from shadowing/intercepting drop events, allowing files dragged directly onto the timeline tracks to be correctly added as clips and snapped to the drop point.
- Refactored C++ `StemSeparator` spectrogram representations from pointer-chasing 3D vectors to flat 1D contiguous vectors to improve cache locality.
- Pre-allocated STFT and ISTFT temporary frame/complex vectors outside of processing loops to eliminate over 120,000 dynamic heap memory operations.
- Optimized fallback Mid-Side DSP separation loop by removing thread sleeping (`msleep`) and loop boundary branch checks, accelerating fallback execution by up to 100x.
- Decoupled active clip dragging and trimming coordinates to use native QML drag targets, deferring C++ model writes and expensive waveform rebuilds to mouse release for smooth 60fps movement.
- Exposed horizontal scroll coordinate `scrollX` from `TimelineView` to delegate `TrackLane` templates to resolve undeclared warning outputs.
- Qualified the `snappingEnabled` and `compactTracks` properties inside `TimelineView.qml` with the root ID `timelineRoot` to resolve QML ReferenceError console warnings.

### Fixed
- Fixed playback compatibility issues for high-resolution (2K/4K) and AV1-encoded videos by providing a software decoding fallback mechanism.
- Fixed QML TypeErrors on animation state changes, specifically resolving the missing property alias for `introAnimationSequence` on the intro splash screen.
- QML double-to-qlonglong property assignment crash by wrapping calculations in `Math.round`.
- Fixed playhead scrubbing lockups by directly writing to properties instead of using missing C++ setters as functions.
- Corrected alignment of timeline ruler ticks and playhead lines by offsetting coordinates with the 180px track header boundary.
- Fixed stem separation track duplication by searching for and reusing existing audio tracks.
- Resolved video clip placement bugs where Video files incorrectly mapped to Audio tracks and could not be loaded into Video lanes.
- Fixed playhead jumping when clicking on track headers in TimelineView.qml by adding a bounds check to the ruler MouseArea.
- Fixed ONNX Runtime GPU execution provider loader failure by updating the CMake post-build script to copy all runtime library DLLs (including cuda, tensorrt, and shared providers) to the executable directory, allowing CUDA GPU-accelerated stem separation.

