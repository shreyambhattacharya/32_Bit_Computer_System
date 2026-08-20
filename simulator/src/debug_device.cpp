#include "mini32/debug_device.hpp"

namespace mini32 {

MmioFault DebugDevice::validate_address(const std::uint32_t address) {
    if ((address & 0x3U) != 0U) {
        return MmioFault::Misaligned;
    }
    return address >= kBaseAddress && address <= kLastAddress ? MmioFault::None
                                                               : MmioFault::OutOfRange;
}

MmioReadResult DebugDevice::read32(const std::uint32_t address) const {
    const MmioFault fault = validate_address(address);
    if (fault != MmioFault::None) {
        return {.fault = fault};
    }
    return address - kBaseAddress == 0U ? MmioReadResult{.data = value_} : MmioReadResult{};
}

MmioWriteResult DebugDevice::write32(const std::uint32_t address, const std::uint32_t value) {
    const MmioFault fault = validate_address(address);
    if (fault != MmioFault::None) {
        return {.fault = fault};
    }
    if (address - kBaseAddress == 0U) {
        value_ = value;
    }
    return {};
}

void DebugDevice::reset() {
    value_ = 0U;
}

}  // namespace mini32
