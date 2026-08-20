#include "mini32/gpio.hpp"

namespace mini32 {

MmioFault Gpio::validate_address(const std::uint32_t address) {
    if ((address & 0x3U) != 0U) return MmioFault::Misaligned;
    return address >= kBaseAddress && address <= kLastAddress ? MmioFault::None : MmioFault::OutOfRange;
}

MmioReadResult Gpio::read32(const std::uint32_t address) const {
    const MmioFault fault = validate_address(address);
    if (fault != MmioFault::None) return {.fault = fault};
    switch (address - kBaseAddress) {
    case 0x00U: return {.data = input_};
    case 0x04U: return {.data = output_};
    case 0x08U: return {.data = direction_};
    default: return {};
    }
}

MmioWriteResult Gpio::write32(const std::uint32_t address, const std::uint32_t value) {
    const MmioFault fault = validate_address(address);
    if (fault != MmioFault::None) return {.fault = fault};
    switch (address - kBaseAddress) {
    case 0x04U: output_ = value; break;
    case 0x08U: direction_ = value; break;
    default: break;
    }
    return {};
}

void Gpio::reset() {
    output_ = 0U;
    direction_ = 0U;
}

}  // namespace mini32
