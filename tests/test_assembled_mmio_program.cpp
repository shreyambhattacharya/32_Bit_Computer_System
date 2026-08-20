#include <cstdint>
#include <fstream>
#include <iterator>
#include <string>
#include <vector>

#include "mini32/bus.hpp"
#include "mini32/cpu_core.hpp"
#include "mini32/debug_device.hpp"
#include "mini32/ram.hpp"
#include "mini32/rom.hpp"
#include "mini32/uart.hpp"
#include "test_support.hpp"

namespace {

std::vector<std::uint8_t> load_image(const char* path) {
    std::ifstream input(path, std::ios::binary);
    CHECK(input.is_open());
    const std::vector<char> raw((std::istreambuf_iterator<char>(input)),
                                std::istreambuf_iterator<char>());
    std::vector<std::uint8_t> image;
    image.reserve(raw.size());
    for (const char byte : raw) {
        image.push_back(static_cast<std::uint8_t>(static_cast<unsigned char>(byte)));
    }
    return image;
}

void run_until_halted(mini32::CpuCore& cpu) {
    for (std::uint32_t steps = 0U; steps < 128U && !cpu.halted() && !cpu.faulted(); ++steps) {
        static_cast<void>(cpu.step());
    }
    CHECK(cpu.halted());
    CHECK(!cpu.faulted());
}

}  // namespace

int main() {
    {
        mini32::Rom rom;
        rom.load_bytes(0U, load_image(MINI32_HELLO_UART_BIN));
        mini32::Ram ram;
        std::string output;
        mini32::Uart uart([&output](const std::uint8_t byte) { output.push_back(static_cast<char>(byte)); });
        mini32::DebugDevice debug;
        mini32::Bus bus(rom, ram, uart, debug);
        mini32::CpuCore cpu(bus);
        run_until_halted(cpu);
        CHECK(output == "Hello Mini32!\n");
    }
    {
        mini32::Rom rom;
        rom.load_bytes(0U, load_image(MINI32_DEBUG_DEMO_BIN));
        mini32::Ram ram;
        mini32::Uart uart;
        mini32::DebugDevice debug;
        mini32::Bus bus(rom, ram, uart, debug);
        mini32::CpuCore cpu(bus);
        run_until_halted(cpu);
        CHECK(debug.value() == 0x12345678U);
        CHECK(cpu.registers().read(3U) == 0x12345678U);
        cpu.reset();
        CHECK(debug.value() == 0x12345678U);
    }
}
