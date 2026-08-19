cmake_minimum_required(VERSION 3.20)

project(mini_computer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(CTest)

add_library(mini32_core
    simulator/src/alu.cpp
    simulator/src/bus.cpp
    simulator/src/cpu_core.cpp
    simulator/src/decoder.cpp
    simulator/src/register_file.cpp
    simulator/src/rom.cpp
)

target_include_directories(mini32_core PUBLIC simulator/include)

if(MSVC)
    target_compile_options(mini32_core PRIVATE /W4 /permissive-)
else()
    target_compile_options(mini32_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

if(BUILD_TESTING)
    function(add_mini32_test target)
        add_executable(${target} tests/${target}.cpp)
        target_link_libraries(${target} PRIVATE mini32_core)
        target_include_directories(${target} PRIVATE tests)
        if(MSVC)
            target_compile_options(${target} PRIVATE /W4 /permissive-)
        else()
            target_compile_options(${target} PRIVATE -Wall -Wextra -Wpedantic)
        endif()
        add_test(NAME ${target} COMMAND ${target})
    endfunction()

    add_mini32_test(test_alu)
    add_mini32_test(test_register_file)
    add_mini32_test(test_decoder)
    add_mini32_test(test_rom_bus)
    add_mini32_test(test_cpu_arithmetic)
endif()
