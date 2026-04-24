cmake_minimum_required(VERSION 3.10)
project(ProfessionalCreativeSuite VERSION 1.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED True)

# Find necessary libraries
find_package(SDL2 REQUIRED)
find_package(PkgConfig REQUIRED)
pkg_check_modules(CAIRO REQUIRED cairo)
pkg_check_modules(PANGO REQUIRED pango pangocairo)

# Add include directories
include_directories(
    ${SDL2_INCLUDE_DIRS}
    ${CAIRO_INCLUDE_DIRS}
    ${PANGO_INCLUDE_DIRS}
    src
)

# Source files
set(SOURCES
    src/main.cpp
    src/Engine/EventBus.cpp
    src/Engine/Window.cpp
    src/Engine/Renderer.cpp
    src/UI/UIElement.cpp
    src/UI/Components.cpp
)

# Create executable
add_executable(${PROJECT_NAME} ${SOURCES})

# Link libraries
target_link_libraries(${PROJECT_NAME}
    ${SDL2_LIBRARIES}
    ${CAIRO_LIBRARIES}
    ${PANGO_LIBRARIES}
)
