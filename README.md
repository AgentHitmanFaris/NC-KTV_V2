# NC-KTV V2 - Premium Karaoke Maker and NLE

NC-KTV V2 is a professional, high-fidelity Karaoke Maker and Non-Linear Editor (NLE) designed to build high-quality karaoke video files. It features an advanced multi-track timeline, hardware-accelerated audio rendering, and AI-driven stem separation using ONNX Runtime.

## Key Features

- **Multi-Track Timeline**: Supports audio, video, and lyrics tracks with real-time waveform visualization.
- **Syllable-Level Timing and Tuning**: Interactive adjustments of syllable start times and sweep bounds with frame accuracy.
- **Stationary Track Headers Layout**: Keeps track titles, controls, and volume adjustments pinned to the left viewport edge during horizontal scrubbing.
- **AI Stem Separation**: Advanced audio stem separation powered by ONNX Runtime with a high-fidelity Mid-Side DSP fallback mode.
- **Muxing Render Engine**: Fully integrated FFmpeg H.264/AAC muxer for direct project rendering.
- **Dual-Line Karaoke Lookahead Display**: High-performance lyrics visualizer featuring active cues and next-line lookahead rendering.

## Requirements

- **C++ Standard**: C++20
- **Qt GUI Framework**: Qt 6.10.2
- **FFmpeg Libraries**: avcodec, avformat, avfilter, avutil, swresample, swscale (62.x / 11.x)
- **ONNX Runtime**: Version 18
- **Build System**: CMake

## Building and Running

### Build Project
To compile the targets, navigate to the `build` directory and run:
```cmd
build.bat
```

### Run Tests
To run the automated test suite, execute:
```powershell
$env:PATH += ";D:\ProgramData\Qt\6.10.2\msvc2022_64\bin"
./timeline_test.exe
```

### Launch Application
To launch the primary GUI executable:
```powershell
$env:PATH += ";D:\ProgramData\Qt\6.10.2\msvc2022_64\bin"
./src/gui/NC-KTV_V2.exe
```
