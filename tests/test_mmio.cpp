#include <cstdint>
#include <string>

#include "mini32/bus.hpp"
#include "mini32/debug_device.hpp"
#include "mini32/ram.hpp"
#include "mini32/rom.hpp"
#include "mini32/uart.hpp"
#include "test_support.hpp"

int main() {
    std::string transmitted;
    mini32::Uart uart([&transmitted](const std::uint8_t byte) {
        transmitted.push_back(static_cast<char>(byte));
    });
    CHECK(uart.write32(mini32::Uart::kBaseAddress, 0x12345641U).ok());
    CHECK(transmitted == "A");
    CHECK(uart.read32(mini32::Uart::kBaseAddress).data == 0U);
    CHECK(uart.read32(mini32::Uart::kBaseAddress + 4U).data == 1U);
    CHECK(uart.read32(mini32::Uart::kBaseAddress + 8U).data == 0U);
    CHECK(uart.read32(mini32::Uart::kBaseAddress + 12U).data == 0U);
    CHECK(uart.write32(mini32::Uart::kBaseAddress + 8U, 1U).ok());
    CHECK(uart.write32(mini32::Uart::kBaseAddress + 12U, 1U).ok());
    CHECK(uart.read32(mini32::Uart::kBaseAddress + 2U).fault == mini32::MmioFault::Misaligned);
    CHECK(uart.read32(mini32::Uart::kBaseAddress + 16U).fault == mini32::MmioFault::OutOfRange);
    uart.reset();

    mini32::DebugDevice debug;
    CHECK(debug.value() == 0U);
    CHECK(debug.write32(mini32::DebugDevice::kBaseAddress, 0x12345678U).ok());
    CHECK(debug.value() == 0x12345678U);
    CHECK(debug.read32(mini32::DebugDevice::kBaseAddress).data == 0x12345678U);
    CHECK(debug.read32(mini32::DebugDevice::kBaseAddress + 4U).data == 0U);
    CHECK(debug.read32(mini32::DebugDevice::kBaseAddress + 8U).data == 0U);
    CHECK(debug.read32(mini32::DebugDevice::kBaseAddress + 12U).data == 0U);
    CHECK(debug.write32(mini32::DebugDevice::kBaseAddress + 4U, 1U).ok());
    CHECK(debug.write32(mini32::DebugDevice::kBaseAddress + 8U, 1U).ok());
    CHECK(debug.write32(mini32::DebugDevice::kBaseAddress + 12U, 1U).ok());
    CHECK(debug.read32(mini32::DebugDevice::kBaseAddress + 2U).fault == mini32::MmioFault::Misaligned);
    CHECK(debug.read32(mini32::DebugDevice::kBaseAddress + 16U).fault == mini32::MmioFault::OutOfRange);
    debug.reset();
    CHECK(debug.value() == 0U);

    mini32::Rom rom;
    rom.load32(0U, 0x12345678U);
    mini32::Ram ram;
    mini32::Bus bus(rom, ram, uart, debug);
    CHECK(bus.read32(0U).data == 0x12345678U);
    CHECK(bus.write32(mini32::Ram::kBaseAddress, 0xA1B2C3D4U).ok());
    CHECK(bus.read32(mini32::Ram::kBaseAddress).data == 0xA1B2C3D4U);
    CHECK(bus.write32(mini32::Uart::kBaseAddress, 0x42U).ok());
    CHECK(transmitted == "AB");
    CHECK(bus.read32(mini32::Uart::kBaseAddress + 4U).data == 1U);
    CHECK(bus.write32(mini32::DebugDevice::kBaseAddress, 0xCAFEBABEU).ok());
    CHECK(bus.read32(mini32::DebugDevice::kBaseAddress).data == 0xCAFEBABEU);
    CHECK(bus.fetch32(mini32::Uart::kBaseAddress).fault == mini32::BusFault::NonExecutable);
    CHECK(bus.fetch32(mini32::DebugDevice::kBaseAddress).fault == mini32::BusFault::NonExecutable);
    CHECK(bus.read32(mini32::Uart::kBaseAddress + 2U).fault == mini32::BusFault::Misaligned);
    CHECK(bus.write32(mini32::DebugDevice::kBaseAddress + 2U, 0U).fault == mini32::BusFault::Misaligned);
    CHECK(bus.read32(mini32::Uart::kBaseAddress + 16U).fault == mini32::BusFault::Unmapped);
    CHECK(bus.read32(mini32::DebugDevice::kBaseAddress + 16U).fault == mini32::BusFault::Unmapped);
    CHECK(bus.read32(0x20000200U).fault == mini32::BusFault::Unmapped);
}
