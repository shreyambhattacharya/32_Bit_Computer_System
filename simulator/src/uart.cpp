#include "mini32/uart.hpp"

#include <utility>

namespace mini32 {

Uart::Uart(TxCallback tx_callback) : tx_callback_(std::move(tx_callback)) {}

MmioFault Uart::validate_address(const std::uint32_t address) {
    if ((address & 0x3U) != 0U) {
        return MmioFault::Misaligned;
    }
    return address >= kBaseAddress && address <= kLastAddress ? MmioFault::None
                                                               : MmioFault::OutOfRange;
}

MmioReadResult Uart::read32(const std::uint32_t address) const {
    const MmioFault fault = validate_address(address);
    if (fault != MmioFault::None) {
        return {.fault = fault};
    }

    switch (address - kBaseAddress) {
    case 0x04U:
        return {.data = 1U};  // TX_READY
    case 0x00U:  // DATA receive is not implemented yet.
    case 0x08U:  // CONTROL is reserved.
    case 0x0CU:  // Reserved.
        return {};
    default:
        return {.fault = MmioFault::OutOfRange};
    }
}

MmioWriteResult Uart::write32(const std::uint32_t address, const std::uint32_t value) {
    const MmioFault fault = validate_address(address);
    if (fault != MmioFault::None) {
        return {.fault = fault};
    }

    switch (address - kBaseAddress) {
    case 0x00U:
        if (tx_callback_) {
            tx_callback_(static_cast<std::uint8_t>(value & 0xFFU));
        }
        return {};
    case 0x04U:  // STATUS writes are accepted for a stable register window.
    case 0x08U:  // CONTROL has no defined bits yet.
    case 0x0CU:  // Reserved.
        return {};
    default:
        return {.fault = MmioFault::OutOfRange};
    }
}

void Uart::reset() {
    // The first UART model has no guest-visible state.
}

}  // namespace mini32
