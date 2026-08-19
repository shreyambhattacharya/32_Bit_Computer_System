#include "mini32/bus.hpp"

namespace mini32 {

BusReadResult Bus::read32(const std::uint32_t address) const {
    if ((address & 0x3U) != 0U) {
        return {.fault = BusFault::Misaligned};
    }

    if (address >= Rom::kBaseAddress && address <= Rom::kLastAddress) {
        const RomReadResult rom_result = rom_.read32(address);
        if (rom_result.ok()) {
            return {.data = rom_result.data};
        }
        return {.fault = rom_result.fault == RomFault::Misaligned ? BusFault::Misaligned
                                                                    : BusFault::Unmapped};
    }

    return {.fault = BusFault::Unmapped};
}

}  // namespace mini32
