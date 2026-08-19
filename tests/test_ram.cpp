#include <cstdint>

#include "mini32/ram.hpp"
#include "test_support.hpp"

int main() {
    mini32::Ram ram;
    CHECK(ram.read32(mini32::Ram::kBaseAddress).data == 0U);
    CHECK(ram.write32(mini32::Ram::kBaseAddress, 0x12345678U).ok());
    CHECK(ram.read32(mini32::Ram::kBaseAddress).data == 0x12345678U);
    CHECK(ram.debug_read_byte(mini32::Ram::kBaseAddress) == 0x78U);
    CHECK(ram.debug_read_byte(mini32::Ram::kBaseAddress + 1U) == 0x56U);
    CHECK(ram.debug_read_byte(mini32::Ram::kBaseAddress + 2U) == 0x34U);
    CHECK(ram.debug_read_byte(mini32::Ram::kBaseAddress + 3U) == 0x12U);
    CHECK(ram.write32(mini32::Ram::kBaseAddress, 0xAABBCCDDU).ok());
    CHECK(ram.read32(mini32::Ram::kBaseAddress).data == 0xAABBCCDDU);
    CHECK(ram.write32(mini32::Ram::kBaseAddress + 4U, 0xCAFEBABEU).ok());
    CHECK(ram.read32(mini32::Ram::kBaseAddress + 4U).data == 0xCAFEBABEU);
    CHECK(ram.write32(0x1000FFFCU, 0xDEADBEEFU).ok());
    CHECK(ram.read32(0x1000FFFCU).data == 0xDEADBEEFU);
    CHECK(ram.read32(mini32::Ram::kBaseAddress + 2U).fault == mini32::RamFault::Misaligned);
    CHECK(ram.write32(mini32::Ram::kBaseAddress + 2U, 1U).fault == mini32::RamFault::Misaligned);
    CHECK(ram.read32(0x10010000U).fault == mini32::RamFault::OutOfRange);
    CHECK(ram.write32(0x10010000U, 1U).fault == mini32::RamFault::OutOfRange);
}
