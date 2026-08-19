cmake_minimum_required(VERSION 3.20)

project(mini_computer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

include(CTest)
find_package(Python3 COMPONENTS Interpreter REQUIRED)

add_library(mini32_core
    simulator/src/alu.cpp
    simulator/src/bus.cpp
    simulator/src/cpu_core.cpp
    simulator/src/decoder.cpp
    simulator/src/ram.cpp
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
    add_mini32_test(test_ram)
    add_mini32_test(test_cpu_arithmetic)
    add_mini32_test(test_cpu_memory)
    add_mini32_test(test_cpu_control_flow)

    set(MINI32_ARITHMETIC_LOOP_BIN "${CMAKE_CURRENT_BINARY_DIR}/generated/arithmetic_loop.bin")
    add_custom_command(
        OUTPUT "${MINI32_ARITHMETIC_LOOP_BIN}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${CMAKE_CURRENT_BINARY_DIR}/generated"
        COMMAND ${Python3_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/assembler/assembler.py"
                "${CMAKE_CURRENT_SOURCE_DIR}/programs/arithmetic_loop.asm"
                -o "${MINI32_ARITHMETIC_LOOP_BIN}"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/assembler/assembler.py"
                "${CMAKE_CURRENT_SOURCE_DIR}/assembler/mini32_isa.py"
                "${CMAKE_CURRENT_SOURCE_DIR}/programs/arithmetic_loop.asm"
        VERBATIM
    )
    add_custom_target(mini32_sample_binaries DEPENDS "${MINI32_ARITHMETIC_LOOP_BIN}")

    add_mini32_test(test_assembled_program)
    add_dependencies(test_assembled_program mini32_sample_binaries)
    target_compile_definitions(test_assembled_program PRIVATE
        MINI32_ARITHMETIC_LOOP_BIN="${MINI32_ARITHMETIC_LOOP_BIN}")

    add_test(NAME test_python_toolchain
             COMMAND ${Python3_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/tests/python/test_toolchain.py")
    set_tests_properties(test_python_toolchain PROPERTIES
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
endif()
