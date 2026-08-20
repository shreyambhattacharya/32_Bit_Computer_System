#include "mini32/timer.hpp"

namespace mini32 {

MmioFault Timer::validate_address(const std::uint32_t address) {
    if ((address & 0x3U) != 0U) return MmioFault::Misaligned;
    return address >= kBaseAddress && address <= kLastAddress ? MmioFault::None : MmioFault::OutOfRange;
}

MmioReadResult Timer::read32(const std::uint32_t address) const {
    const MmioFault fault = validate_address(address);
    if (fault != MmioFault::None) return {.fault = fault};
    switch (address - kBaseAddress) {
    case 0x00U: return {.data = counter_};
    case 0x04U: return {.data = compare_};
    case 0x08U: return {.data = enabled_ ? 1U : 0U};
    case 0x0CU: return {.data = match() ? 1U : 0U};
    default: return {};
    }
}

MmioWriteResult Timer::write32(const std::uint32_t address, const std::uint32_t value) {
    const MmioFault fault = validate_address(address);
    if (fault != MmioFault::None) return {.fault = fault};
    switch (address - kBaseAddress) {
    case 0x00U: counter_ = value; break;
    case 0x04U: compare_ = value; break;
    case 0x08U: enabled_ = (value & 1U) != 0U; break;
    default: break;
    }
    return {};
}

void Timer::retire_tick() {
    if (enabled_) ++counter_;
}

void Timer::reset() {
    counter_ = 0U;
    compare_ = 0U;
    enabled_ = false;
}

}  // namespace mini32
