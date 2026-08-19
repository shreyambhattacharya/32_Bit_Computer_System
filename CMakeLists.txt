cmake_minimum_required(VERSION 3.20)

project(mini_computer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(CTest)

# Targets are introduced with the first simulator milestone. Keeping this file
# valid now establishes one reproducible build entry point without pretending
# that an architecture document is already an implementation.
