#include <cstdint>

#include "instruction_encoding.hpp"
#include "mini32/bus.hpp"
#include "mini32/cpu_core.hpp"
#include "mini32/debug_device.hpp"
#include "mini32/gpio.hpp"
#include "mini32/ram.hpp"
#include "mini32/rom.hpp"
#include "mini32/timer.hpp"
#include "mini32/uart.hpp"
#include "test_support.hpp"

int main() {
    mini32::Timer timer;
    CHECK(timer.counter() == 0U && timer.compare() == 0U && !timer.enabled() && !timer.match());
    timer.retire_tick();
    CHECK(timer.counter() == 0U);
    CHECK(timer.write32(mini32::Timer::kBaseAddress + 4U, 3U).ok());
    CHECK(timer.write32(mini32::Timer::kBaseAddress + 8U, 0xFFFFFFFFU).ok());
    CHECK(timer.enabled() && timer.read32(mini32::Timer::kBaseAddress + 8U).data == 1U);
    timer.retire_tick(); timer.retire_tick();
    CHECK(timer.counter() == 2U && !timer.match());
    timer.retire_tick();
    CHECK(timer.counter() == 3U && timer.match());
    timer.retire_tick();
    CHECK(timer.counter() == 4U && !timer.match());
    CHECK(timer.write32(mini32::Timer::kBaseAddress, 0xFFFFFFFFU).ok());
    timer.retire_tick();
    CHECK(timer.counter() == 0U);
    CHECK(timer.write32(mini32::Timer::kBaseAddress + 8U, 0U).ok());
    timer.retire_tick();
    CHECK(timer.counter() == 0U);
    CHECK(timer.read32(mini32::Timer::kBaseAddress + 12U).data == 0U);
    CHECK(timer.write32(mini32::Timer::kBaseAddress + 12U, 0xDEADBEEFU).ok());
    CHECK(timer.read32(mini32::Timer::kBaseAddress + 2U).fault == mini32::MmioFault::Misaligned);
    CHECK(timer.read32(mini32::Timer::kBaseAddress + 16U).fault == mini32::MmioFault::OutOfRange);
    timer.reset();
    CHECK(timer.counter() == 0U && timer.compare() == 0U && !timer.enabled());

    mini32::Rom rom;
    rom.load32(0U, test_encoding::encode_i(mini32::Opcode::Lui, 1U, 0U, 0x2000U));
    rom.load32(4U, test_encoding::encode_i(mini32::Opcode::Ori, 1U, 1U, 0x0100U));
    rom.load32(8U, test_encoding::encode_i(mini32::Opcode::Addi, 2U, 0U, 1U));
    rom.load32(12U, test_encoding::encode_s(2U, 1U, 8U));
    rom.load32(16U, static_cast<std::uint32_t>(mini32::Opcode::Halt) << 26U);
    mini32::Ram ram;
    mini32::Uart uart;
    mini32::DebugDevice debug;
    mini32::Timer instruction_timer;
    mini32::Gpio gpio;
    mini32::Bus bus(rom, ram, uart, debug, instruction_timer, gpio);
    mini32::CpuCore cpu(bus);
    while (!cpu.halted()) static_cast<void>(cpu.step());
    CHECK(cpu.retired_instructions() == 5U);
    CHECK(instruction_timer.counter() == 2U);
}
