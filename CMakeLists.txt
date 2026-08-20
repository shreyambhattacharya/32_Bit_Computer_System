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
    simulator/src/debug_device.cpp
    simulator/src/decoder.cpp
    simulator/src/ram.cpp
    simulator/src/register_file.cpp
    simulator/src/rom.cpp
    simulator/src/uart.cpp
)

target_include_directories(mini32_core PUBLIC simulator/include)

if(MSVC)
    target_compile_options(mini32_core PRIVATE /W4 /permissive-)
else()
    target_compile_options(mini32_core PRIVATE -Wall -Wextra -Wpedantic)
endif()

add_executable(mini32_sim simulator/app/main.cpp)
target_link_libraries(mini32_sim PRIVATE mini32_core)
if(MSVC)
    target_compile_options(mini32_sim PRIVATE /W4 /permissive-)
else()
    target_compile_options(mini32_sim PRIVATE -Wall -Wextra -Wpedantic)
endif()

set(MINI32_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(MINI32_ARITHMETIC_LOOP_BIN "${MINI32_GENERATED_DIR}/arithmetic_loop.bin")
set(MINI32_HELLO_UART_BIN "${MINI32_GENERATED_DIR}/hello_uart.bin")
set(MINI32_DEBUG_DEMO_BIN "${MINI32_GENERATED_DIR}/debug_demo.bin")
set(MINI32_INFINITE_LOOP_BIN "${MINI32_GENERATED_DIR}/infinite_loop.bin")
set(MINI32_FAULT_ILLEGAL_BIN "${MINI32_GENERATED_DIR}/fault_illegal.bin")

function(add_mini32_assembled_program output source)
    add_custom_command(
        OUTPUT "${output}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${MINI32_GENERATED_DIR}"
        COMMAND ${Python3_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/assembler/assembler.py"
                "${CMAKE_CURRENT_SOURCE_DIR}/programs/${source}" -o "${output}"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/assembler/assembler.py"
                "${CMAKE_CURRENT_SOURCE_DIR}/assembler/mini32_isa.py"
                "${CMAKE_CURRENT_SOURCE_DIR}/programs/${source}"
        VERBATIM
    )
endfunction()

add_mini32_assembled_program("${MINI32_ARITHMETIC_LOOP_BIN}" "arithmetic_loop.asm")
add_mini32_assembled_program("${MINI32_HELLO_UART_BIN}" "hello_uart.asm")
add_mini32_assembled_program("${MINI32_DEBUG_DEMO_BIN}" "debug_demo.asm")
add_mini32_assembled_program("${MINI32_INFINITE_LOOP_BIN}" "infinite_loop.asm")
add_mini32_assembled_program("${MINI32_FAULT_ILLEGAL_BIN}" "fault_illegal.asm")
add_custom_target(mini32_sample_binaries DEPENDS
    "${MINI32_ARITHMETIC_LOOP_BIN}"
    "${MINI32_HELLO_UART_BIN}"
    "${MINI32_DEBUG_DEMO_BIN}"
    "${MINI32_INFINITE_LOOP_BIN}"
    "${MINI32_FAULT_ILLEGAL_BIN}")
add_dependencies(mini32_sim mini32_sample_binaries)

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
    add_mini32_test(test_mmio)

    add_mini32_test(test_assembled_program)
    add_dependencies(test_assembled_program mini32_sample_binaries)
    target_compile_definitions(test_assembled_program PRIVATE
        MINI32_ARITHMETIC_LOOP_BIN="${MINI32_ARITHMETIC_LOOP_BIN}")

    add_mini32_test(test_assembled_mmio_program)
    add_dependencies(test_assembled_mmio_program mini32_sample_binaries)
    target_compile_definitions(test_assembled_mmio_program PRIVATE
        MINI32_HELLO_UART_BIN="${MINI32_HELLO_UART_BIN}"
        MINI32_DEBUG_DEMO_BIN="${MINI32_DEBUG_DEMO_BIN}")

    add_test(NAME test_python_toolchain
             COMMAND ${Python3_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/tests/python/test_toolchain.py")
    set_tests_properties(test_python_toolchain PROPERTIES
        WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    add_test(NAME test_simulator_cli
             COMMAND ${Python3_EXECUTABLE} "${CMAKE_CURRENT_SOURCE_DIR}/tests/python/test_simulator_cli.py"
                     $<TARGET_FILE:mini32_sim>
                     "${MINI32_HELLO_UART_BIN}"
                     "${MINI32_INFINITE_LOOP_BIN}"
                     "${MINI32_FAULT_ILLEGAL_BIN}")
endif()
