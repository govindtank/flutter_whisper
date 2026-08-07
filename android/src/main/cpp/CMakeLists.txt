cmake_minimum_required(VERSION 3.10)
project(whisper_jni LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(WHISPER_CPP ${CMAKE_CURRENT_SOURCE_DIR}/../../../../third_party/whisper.cpp)

# whisper.cpp build options for Android (CPU only).
set(WHISPER_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(WHISPER_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(GGML_METAL OFF CACHE BOOL "" FORCE)
set(GGML_ACCELERATE OFF CACHE BOOL "" FORCE)

add_subdirectory(${WHISPER_CPP} whisper_cpp)

# libwhisper.so — JNI bridge. Output name must match Kotlin's
# System.loadLibrary("whisper").
add_library(whisper_jni SHARED whisper_jni.cpp)
set_target_properties(whisper_jni PROPERTIES OUTPUT_NAME whisper)
target_include_directories(whisper_jni PRIVATE
    ${WHISPER_CPP}/include
    ${WHISPER_CPP}/examples)
# Link to whisper (which transitively links ggml).
target_link_libraries(whisper_jni PRIVATE whisper)

# Ensure libggml.so exists for Android loader (whisper.cpp builds libggml-cpu.so).
# Add a custom command to copy it.
add_custom_command(
    TARGET whisper_jni POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        $<TARGET_FILE_DIR:ggml>/libggml-cpu.so
        $<TARGET_FILE_DIR:whisper_jni>/libggml.so
    COMMENT "Copy libggml-cpu.so as libggml.so for Android loader"
)
