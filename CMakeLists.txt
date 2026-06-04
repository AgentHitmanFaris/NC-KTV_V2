cmake_minimum_required(VERSION 3.25)
project(NC-KTV_V2 VERSION 2.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ─── Dynamic Qt6 Kit Detection ───────────────────────────────────────────────
set(QT_ROOT "D:/ProgramData/Qt")
if(EXISTS "${QT_ROOT}")
    if(MSVC)
        set(CMAKE_PREFIX_PATH "${QT_ROOT}/6.10.2/msvc2022_64")
    else()
        set(CMAKE_PREFIX_PATH "${QT_ROOT}/6.10.2/mingw_64")
    endif()
    message(STATUS "NC-KTV V2: Using Qt Kit prefix path: ${CMAKE_PREFIX_PATH}")
else()
    message(WARNING "NC-KTV V2: Baseline Qt path '${QT_ROOT}' not found. Relying on default system search.")
endif()

# ─── Find Core Qt6 Components ────────────────────────────────────────────────
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Network Multimedia Qml Quick QuickControls2)

# ─── Enable Qt Autotools ──────────────────────────────────────────────────────
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# ─── Fetch Dependencies via FetchContent ──────────────────────────────────────
set(CMAKE_TLS_VERIFY OFF)
include(FetchContent)

# 1. nlohmann_json
FetchContent_Declare(nlohmann_json
    GIT_REPOSITORY https://github.com/nlohmann/json.git
    GIT_TAG v3.11.3
)
FetchContent_MakeAvailable(nlohmann_json)

# 2. ONNX Runtime (GPU build for high-performance stem separation)
if(WIN32)
    set(ORT_VERSION "1.18.0")
    message(STATUS "NC-KTV V2: Fetching ONNX Runtime v${ORT_VERSION} (win-x64-dml)...")
    FetchContent_Declare(onnxruntime
        URL "https://globalcdn.nuget.org/packages/microsoft.ml.onnxruntime.directml.1.18.0.nupkg"
        DOWNLOAD_NAME "onnxruntime.zip"
    )
    FetchContent_MakeAvailable(onnxruntime)

    set(ORT_DLL "${onnxruntime_SOURCE_DIR}/runtimes/win-x64/native/onnxruntime.dll")
    set(ORT_INC "${onnxruntime_SOURCE_DIR}/build/native/include")

    add_library(onnx_shared SHARED IMPORTED GLOBAL)
    target_include_directories(onnx_shared INTERFACE "${ORT_INC}")
    set_property(TARGET onnx_shared PROPERTY IMPORTED_LOCATION "${ORT_DLL}")

    if(MSVC)
        # MSVC uses the pre-built import library (.lib)
        set_property(TARGET onnx_shared PROPERTY IMPORTED_IMPLIB "${onnxruntime_SOURCE_DIR}/runtimes/win-x64/native/onnxruntime.lib")
    else()
        # MinGW: Resolve dlltool to generate .a import library
        set(ORT_IMPLIB "${CMAKE_BINARY_DIR}/libonnxruntime.a")
        set(ORT_DEF    "${CMAKE_BINARY_DIR}/onnxruntime.def")

        find_program(DLLTOOL_EXE dlltool
            HINTS "${CMAKE_CXX_COMPILER_DIR}" "D:/ProgramData/Qt/Tools/mingw1310_64/bin"
            REQUIRED
        )

        add_custom_command(
            OUTPUT  "${ORT_IMPLIB}"
            COMMAND "${DLLTOOL_EXE}" --dllname onnxruntime.dll --output-lib "${ORT_IMPLIB}" "${ORT_DLL}"
            DEPENDS "${ORT_DLL}"
            WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
            COMMENT "Generating MinGW .a import lib for ONNX Runtime via dlltool"
            VERBATIM
        )
        add_custom_target(onnxruntime_implib ALL DEPENDS "${ORT_IMPLIB}")
        set_property(TARGET onnx_shared PROPERTY IMPORTED_IMPLIB "${ORT_IMPLIB}")
        add_dependencies(onnx_shared onnxruntime_implib)
    endif()
    set(NCKTV_HAS_ONNX ON)
else()
    set(NCKTV_HAS_ONNX OFF)
endif()

# 3. FFmpeg Shared Dev (Headers + Libraries for decoding/encoding/rendering)
if(WIN32)
    message(STATUS "NC-KTV V2: Fetching FFmpeg Shared Dev builds...")
    FetchContent_Declare(ffmpeg_dev
        URL "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n7.1-latest-win64-gpl-shared-7.1.zip"
    )
    FetchContent_MakeAvailable(ffmpeg_dev)

    # BtbN structure contains a top level folder 'ffmpeg-master-latest-win64-gpl-shared'
    # We dynamically locate this subdirectory to avoid build breakage when folder names change
    file(GLOB FFMPEG_SUBDIR RELATIVE "${ffmpeg_dev_SOURCE_DIR}" "${ffmpeg_dev_SOURCE_DIR}/ffmpeg-master-*")
    set(FFMPEG_ROOT "${ffmpeg_dev_SOURCE_DIR}/${FFMPEG_SUBDIR}")
    message(STATUS "NC-KTV V2: FFmpeg dynamically resolved to: ${FFMPEG_ROOT}")

    # Establish an Interface library for FFmpeg that encapsulates all linked components
    add_library(ffmpeg INTERFACE)
    target_include_directories(ffmpeg INTERFACE "${FFMPEG_ROOT}/include")
    target_link_libraries(ffmpeg INTERFACE
        "${FFMPEG_ROOT}/lib/avcodec.lib"
        "${FFMPEG_ROOT}/lib/avformat.lib"
        "${FFMPEG_ROOT}/lib/avfilter.lib"
        "${FFMPEG_ROOT}/lib/avutil.lib"
        "${FFMPEG_ROOT}/lib/swresample.lib"
        "${FFMPEG_ROOT}/lib/swscale.lib"
    )
    
    # Expose FFmpeg DLLs folder so they can be easily copied to target bin
    set(FFMPEG_BIN_DIR "${FFMPEG_ROOT}/bin" CACHE INTERNAL "FFmpeg DLL bin folder")
    set(NCKTV_HAS_FFMPEG ON)
else()
    set(NCKTV_HAS_FFMPEG OFF)
endif()

# ─── Target Subdirectories ────────────────────────────────────────────────────
add_subdirectory(src/core)
add_subdirectory(src/gui)

# ─── Automated Verification Tests ─────────────────────────────────────────────
enable_testing()
add_executable(timeline_test tests/timeline_test.cpp)
target_link_libraries(timeline_test PRIVATE ncktv_core Qt6::Core)
add_test(NAME timeline_test COMMAND timeline_test)
