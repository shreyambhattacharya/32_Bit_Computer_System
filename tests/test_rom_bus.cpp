#include <array>
#include <cstdint>

#include "mini32/bus.hpp"
#include "mini32/rom.hpp"
#include "test_support.hpp"

int main() {
    mini32::Rom rom;
    const std::array<std::uint8_t, 8> image{0x78U, 0x56U, 0x34U, 0x12U,
                                            0xEFU, 0xCDU, 0xABU, 0x90U};
    rom.load_bytes(0U, image);
    CHECK(rom.read32(0U).ok());
    CHECK(rom.read32(0U).data == 0x12345678U);
    CHECK(rom.read32(4U).data == 0x90ABCDEFU);

    rom.load32(0xFFFCU, 0xDEADBEEFU);
    CHECK(rom.read32(0xFFFCU).data == 0xDEADBEEFU);
    CHECK(rom.read32(2U).fault == mini32::RomFault::Misaligned);
    CHECK(rom.read32(0x10000U).fault == mini32::RomFault::OutOfRange);

    const mini32::Bus bus(rom);
    CHECK(bus.read32(0U).data == 0x12345678U);
    CHECK(bus.read32(2U).fault == mini32::BusFault::Misaligned);
    CHECK(bus.read32(0x10000U).fault == mini32::BusFault::Unmapped);
}
