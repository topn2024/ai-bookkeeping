# CMakeLists.txt for bspatch native library
cmake_minimum_required(VERSION 3.10.2)

project("bspatch")

# Add bspatch library
add_library(
    bspatch
    SHARED
    bspatch.c
    bspatch_jni.c
)

# Find required libraries
find_library(
    log-lib
    log
)

find_library(
    z-lib
    z
)

# Link libraries
target_link_libraries(
    bspatch
    ${log-lib}
    ${z-lib}
)
