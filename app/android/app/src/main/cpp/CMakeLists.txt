# CMakeLists.txt for native libraries
cmake_minimum_required(VERSION 3.10.2)

project("native_libs")

# Add bspatch library
add_library(
    bspatch
    SHARED
    bspatch.c
    bspatch_jni.c
)

# Add secure_keys library
add_library(
    secure_keys
    SHARED
    secure_keys.c
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

# Link libraries for bspatch
target_link_libraries(
    bspatch
    ${log-lib}
    ${z-lib}
)

# Link libraries for secure_keys
target_link_libraries(
    secure_keys
    ${log-lib}
)
