#include <iostream>
#include <string>

// Qt6 core, GUI, and QML components
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQmlError>
#include <QStyleFactory>
#include <QIcon>
#include <QQuickStyle>
#include <QFile>
#include <QSettings>


// External thirdparty & fetched headers (Verifies compiler path resolutions)
#include <nlohmann/json.hpp>

// miniaudio configuration
#include <miniaudio.h>

// FFmpeg headers (C linkable)
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavfilter/avfilter.h>
#include <libavutil/avutil.h>
}

// ONNX Runtime headers
#include <onnxruntime_cxx_api.h>

// Core timeline & audio engines
#include "timeline/timeline_manager.h"
#include "timeline/track.h"
#include "timeline/clip.h"
#include "timeline/models/track_list_model.h"
#include "timeline/models/clip_list_model.h"
#include "audio/audio_engine.h"
#include "youtube/youtube_manager.h"
#include "src/gui/waveform_renderer.h"
#include "src/gui/karaoke_lyric_renderer.h"

int main(int argc, char* argv[]) {
    // Read hardware acceleration setting before QGuiApplication is created
    QSettings settings("NC-KTV", "NC-KTV_V2");
    bool disableHw = settings.value("disable_hw_decoding", false).toBool();
    if (disableHw) {
        qputenv("QT_FFMPEG_DECODING_HW_DEVICE_TYPES", "none");
        std::cout << "[SYSTEM] Software Decoding Mode enabled (Hardware acceleration disabled globally).\n";
    }

    // Force Basic style to allow full QML customization and suppress native style warnings
    QQuickStyle::setStyle("Basic");

    // We use QGuiApplication for hardware-accelerated QML rendering
    QGuiApplication app(argc, argv);

    // Set application icon (taskbar, Alt+Tab, title bar)
    QIcon appIcon(":/qt/qml/ncktv/gui/logo.png");
    if (appIcon.isNull()) {
        appIcon = QIcon(":/ncktv/gui/logo.png");
    }
    app.setWindowIcon(appIcon);

    // ─── Diagnostics Outputs (Prints toolchain resolution specs) ────────────
    std::cout << "========================================================\n";
    std::cout << "        NC-KTV V2 - Premium Karaoke Maker & NLE         \n";
    std::cout << "========================================================\n";
    std::cout << "[SYSTEM] Compiling C++ Standard : C++20\n";
    std::cout << "[SYSTEM] Qt GUI Version          : " << QT_VERSION_STR << "\n";
    std::cout << "[SYSTEM] FFmpeg avcodec version  : " << LIBAVCODEC_VERSION_MAJOR << "." 
              << LIBAVCODEC_VERSION_MINOR << "." << LIBAVCODEC_VERSION_MICRO << "\n";
    std::cout << "[SYSTEM] ONNX Runtime Version    : " << ORT_API_VERSION << "\n";
    std::cout << "[SYSTEM] Miniaudio Version       : " << MA_VERSION_MAJOR << "."
              << MA_VERSION_MINOR << "." << MA_VERSION_REVISION << "\n";
    std::cout << "[SYSTEM] nlohmann_json Version   : " << NLOHMANN_JSON_VERSION_MAJOR << "."
              << NLOHMANN_JSON_VERSION_MINOR << "." << NLOHMANN_JSON_VERSION_PATCH << "\n";
    std::cout << "========================================================\n";

    // Initialize core controllers
    ncktv::TimelineManager timelineManager;
    ncktv::AudioEngine audioEngine(&timelineManager);
    ncktv::YoutubeManager youtubeManager;

    // ─── Initialize clean, empty default tracks for a premium blank startup state ───
    timelineManager.addTrack(0, "Background Instrumental");
    timelineManager.addTrack(0, "Guide Vocals Track");
    timelineManager.addTrack(2, "Karaoke Subtitles");

    // ─── QML Bootstrapping & Engine Setup ────────────────────────────────────
    QQmlApplicationEngine engine;

    // Register custom C++ list models and classes to QML namespace 'ncktv.core'
    qmlRegisterType<ncktv::TrackListModel>("ncktv.core", 1, 0, "TrackListModel");
    qmlRegisterType<ncktv::ClipListModel>("ncktv.core", 1, 0, "ClipListModel");
    qmlRegisterType<ncktv::WaveformRenderer>("ncktv.core", 1, 0, "WaveformRenderer");
    qmlRegisterType<ncktv::KaraokeLyricRenderer>("ncktv.core", 1, 0, "KaraokeLyricRenderer");
    
    // Register Track and Clip pointers as uncreatable to expose meta properties & methods
    qmlRegisterUncreatableType<ncktv::Track>("ncktv.core", 1, 0, "Track", "Track objects are created by C++ core only");
    qmlRegisterUncreatableType<ncktv::Clip>("ncktv.core", 1, 0, "Clip", "Clip objects are created by C++ core only");

    // Bind manager singletons as global context properties for easy QML anchors
    engine.rootContext()->setContextProperty("timelineManager", &timelineManager);
    engine.rootContext()->setContextProperty("audioEngine", &audioEngine);
    engine.rootContext()->setContextProperty("youtubeManager", &youtubeManager);

    // Connect to warning signals to print QML errors clearly in console
    QObject::connect(&engine, &QQmlApplicationEngine::warnings, [](const QList<QQmlError>& warnings) {
        for (const auto& error : warnings) {
            std::cerr << "[QML WARNING] " << error.toString().toStdString() << "\n";
        }
    });

    // Load main application QML window
    const QUrl url(u"qrc:/ncktv/gui/main.qml"_qs);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    
    engine.load(url);

    if (engine.rootObjects().isEmpty()) {
        std::cerr << "[SYSTEM] Error: QML engine failed to load main.qml! No root objects created.\n";
        return 1;
    }

    return app.exec();
}
