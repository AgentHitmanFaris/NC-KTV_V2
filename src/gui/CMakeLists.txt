# ─── NC-KTV GUI QML Module ───────────────────────────────────────────────────
# Application binary configuration using modern qt_add_qml_module.

# We define the executable target
if(WIN32)
    qt_add_executable(NC-KTV_V2
        ${CMAKE_SOURCE_DIR}/main.cpp
        app.rc
    )
else()
    qt_add_executable(NC-KTV_V2
        ${CMAKE_SOURCE_DIR}/main.cpp
    )
endif()

# Set binary output directory to the root build folder to match tests and ensure correct windeployqt behavior
set_target_properties(NC-KTV_V2 PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}"
)

# Copy logo from assets to gui source dir for Qt resource embedding & Windows resource compiler
configure_file(
    ${CMAKE_SOURCE_DIR}/assets/logo.png
    ${CMAKE_CURRENT_SOURCE_DIR}/logo.png
    COPYONLY
)
configure_file(
    ${CMAKE_SOURCE_DIR}/assets/logo.ico
    ${CMAKE_CURRENT_SOURCE_DIR}/logo.ico
    COPYONLY
)
configure_file(
    "${CMAKE_SOURCE_DIR}/splash/end.mp4"
    "${CMAKE_CURRENT_SOURCE_DIR}/end.mp4"
    COPYONLY
)

# Define the QML module under the URI 'ncktv.gui'
qt_add_qml_module(NC-KTV_V2
    URI ncktv.gui
    VERSION 1.0
    QML_FILES
        main.qml
        TimelineView.qml
        TrackLane.qml
        ClipItem.qml
        MediaBrowser.qml
        PropertiesPanel.qml
        ExportDialog.qml
        KaraokeLyricView.qml
        LyricTunerWindow.qml
        SplashScreenWindow.qml
    SOURCES
        waveform_renderer.h
        waveform_renderer.cpp
        karaoke_lyric_renderer.h
        karaoke_lyric_renderer.cpp
    RESOURCES
        logo.png
        end.mp4
)

target_link_libraries(NC-KTV_V2
    PRIVATE
        ncktv_core
        Qt6::Core
        Qt6::Gui
        Qt6::Quick
        Qt6::Qml
        Qt6::Widgets
        Qt6::QuickControls2
        Qt6::Multimedia
)

# ─── Post-Build DLL Deployments ───────────────────────────────────────────────
# Copy shared libraries (ONNX Runtime, FFmpeg DLLs) into target build output
# directory so that the application executes seamlessly.
if(WIN32)
    # 1. Copy ONNX Runtime DLLs (including providers for CUDA/TensorRT/etc.)
    if(TARGET onnx_shared)
        file(GLOB ORT_DLLS "${onnxruntime_SOURCE_DIR}/runtimes/win-x64/native/*.dll")
        foreach(DLL_PATH ${ORT_DLLS})
            add_custom_command(TARGET NC-KTV_V2 POST_BUILD
                COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    "${DLL_PATH}"
                    $<TARGET_FILE_DIR:NC-KTV_V2>
                COMMENT "Deploying ONNX Runtime DLL ${DLL_PATH} to build bin..."
            )
        endforeach()
    endif()

    # 2. Copy FFmpeg Shared DLLs
    if(DEFINED FFMPEG_BIN_DIR)
        add_custom_command(TARGET NC-KTV_V2 POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${FFMPEG_BIN_DIR}"
                $<TARGET_FILE_DIR:NC-KTV_V2>
            COMMENT "Deploying FFmpeg DLLs to build bin..."
        )
    endif()

    # 3. Deploy Qt runtime dependencies (DLLs, plugins, QML modules)
    find_program(WINDEPLOYQT_EXECUTABLE windeployqt6
        HINTS "${CMAKE_PREFIX_PATH}/bin"
    )
    if(WINDEPLOYQT_EXECUTABLE)
        add_custom_command(TARGET NC-KTV_V2 POST_BUILD
            COMMAND cmd.exe /C "set \"PATH=${CMAKE_PREFIX_PATH}/bin;%PATH%\" && ${WINDEPLOYQT_EXECUTABLE} --no-translations --no-compiler-runtime --debug --qmldir ${CMAKE_CURRENT_SOURCE_DIR} $<TARGET_FILE:NC-KTV_V2> || exit 0"
            COMMENT "Running windeployqt6 to deploy Qt runtime dependencies..."
        )
    else()
        message(WARNING "windeployqt6 not found. Qt runtime DLLs will not be auto-deployed.")
    endif()
endif()
