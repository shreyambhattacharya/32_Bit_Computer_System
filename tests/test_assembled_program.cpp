#include <cstdint>
#include <fstream>
#include <iterator>
#include <vector>

#include "mini32/bus.hpp"
#include "mini32/cpu_core.hpp"
#include "mini32/debug_device.hpp"
#include "mini32/ram.hpp"
#include "mini32/rom.hpp"
#include "mini32/uart.hpp"
#include "test_support.hpp"

int main() {
    std::ifstream input(MINI32_ARITHMETIC_LOOP_BIN, std::ios::binary);
    CHECK(input.is_open());
    const std::vector<char> raw_bytes((std::istreambuf_iterator<char>(input)),
                                      std::istreambuf_iterator<char>());
    std::vector<std::uint8_t> image;
    image.reserve(raw_bytes.size());
    for (const char value : raw_bytes) {
        image.push_back(static_cast<std::uint8_t>(static_cast<unsigned char>(value)));
    }

    mini32::Rom rom;
    rom.load_bytes(0U, image);
    mini32::Ram ram;
    mini32::Uart uart;
    mini32::DebugDevice debug;
    mini32::Bus bus(rom, ram, uart, debug);
    mini32::CpuCore cpu(bus);
    for (std::uint32_t steps = 0U; steps < 32U && !cpu.halted() && !cpu.faulted(); ++steps) {
        static_cast<void>(cpu.step());
    }
    CHECK(cpu.halted());
    CHECK(!cpu.faulted());
    CHECK(cpu.registers().read(1U) == 0U);
    CHECK(cpu.registers().read(2U) == 6U);
}
