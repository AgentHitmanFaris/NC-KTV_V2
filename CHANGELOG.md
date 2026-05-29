# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
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

### Changed
- Refactored C++ `StemSeparator` spectrogram representations from pointer-chasing 3D vectors to flat 1D contiguous vectors to improve cache locality.
- Pre-allocated STFT and ISTFT temporary frame/complex vectors outside of processing loops to eliminate over 120,000 dynamic heap memory operations.
- Optimized fallback Mid-Side DSP separation loop by removing thread sleeping (`msleep`) and loop boundary branch checks, accelerating fallback execution by up to 100x.
- Decoupled active clip dragging and trimming coordinates to use native QML drag targets, deferring C++ model writes and expensive waveform rebuilds to mouse release for smooth 60fps movement.
- Exposed horizontal scroll coordinate `scrollX` from `TimelineView` to delegate `TrackLane` templates to resolve undeclared warning outputs.
- Qualified the `snappingEnabled` and `compactTracks` properties inside `TimelineView.qml` with the root ID `timelineRoot` to resolve QML ReferenceError console warnings.

### Fixed
- QML double-to-qlonglong property assignment crash by wrapping calculations in `Math.round`.
- Fixed playhead scrubbing lockups by directly writing to properties instead of using missing C++ setters as functions.
- Corrected alignment of timeline ruler ticks and playhead lines by offsetting coordinates with the 180px track header boundary.
- Fixed stem separation track duplication by searching for and reusing existing audio tracks.
