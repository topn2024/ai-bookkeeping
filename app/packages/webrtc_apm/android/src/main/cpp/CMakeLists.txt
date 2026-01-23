cmake_minimum_required(VERSION 3.18.1)

project("webrtc_apm_jni")

# 设置 C++ 标准
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# JNI 桥接库
add_library(${CMAKE_PROJECT_NAME} SHARED
    webrtc_apm_jni.cpp
    audio_processor.cpp
)

# 头文件路径
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# 链接库
find_library(log-lib log)
find_library(android-lib android)

target_link_libraries(${CMAKE_PROJECT_NAME}
    ${log-lib}
    ${android-lib}
)
