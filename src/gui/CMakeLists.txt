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
    SOURCES
        waveform_renderer.h
        waveform_renderer.cpp
    RESOURCES
        logo.png
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
)

# ─── Post-Build DLL Deployments ───────────────────────────────────────────────
# Copy shared libraries (ONNX Runtime, FFmpeg DLLs) into target build output
# directory so that the application executes seamlessly.
if(WIN32)
    # 1. Copy ONNX Runtime DLL
    if(TARGET onnx_shared)
        add_custom_command(TARGET NC-KTV_V2 POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${ORT_DLL}"
                $<TARGET_FILE_DIR:NC-KTV_V2>
            COMMENT "Deploying ONNX Runtime DLL to build bin..."
        )
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
endif()
