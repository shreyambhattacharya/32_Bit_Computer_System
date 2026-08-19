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
    if (address >= Ram::kBaseAddress && address <= Ram::kLastAddress) {
        const RamReadResult ram_result = ram_.read32(address);
        if (ram_result.ok()) {
            return {.data = ram_result.data};
        }
        return {.fault = ram_result.fault == RamFault::Misaligned ? BusFault::Misaligned
                                                                    : BusFault::Unmapped};
    }

    return {.fault = BusFault::Unmapped};
}

BusReadResult Bus::fetch32(const std::uint32_t address) const {
    if ((address & 0x3U) != 0U) {
        return {.fault = BusFault::Misaligned};
    }
    if (address >= Rom::kBaseAddress && address <= Rom::kLastAddress) {
        const RomReadResult rom_result = rom_.read32(address);
        return rom_result.ok() ? BusReadResult{.data = rom_result.data}
                               : BusReadResult{.fault = BusFault::Unmapped};
    }
    if (address >= Ram::kBaseAddress && address <= Ram::kLastAddress) {
        return {.fault = BusFault::NonExecutable};
    }
    return {.fault = BusFault::Unmapped};
}

BusWriteResult Bus::write32(const std::uint32_t address, const std::uint32_t value) {
    if ((address & 0x3U) != 0U) {
        return {.fault = BusFault::Misaligned};
    }
    if (address >= Rom::kBaseAddress && address <= Rom::kLastAddress) {
        return {.fault = BusFault::ReadOnly};
    }
    if (address >= Ram::kBaseAddress && address <= Ram::kLastAddress) {
        const RamWriteResult ram_result = ram_.write32(address, value);
        return {.fault = ram_result.fault == RamFault::None ? BusFault::None
                                                              : BusFault::Unmapped};
    }
    return {.fault = BusFault::Unmapped};
}

}  // namespace mini32
