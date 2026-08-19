#include "mini32/ram.hpp"

#include <stdexcept>

namespace mini32 {
namespace {

bool valid_word_address(const std::uint32_t address) {
    return address >= Ram::kBaseAddress && address <= Ram::kLastAddress - 3U;
}

}  // namespace

RamReadResult Ram::read32(const std::uint32_t address) const {
    if ((address & 0x3U) != 0U) {
        return {.fault = RamFault::Misaligned};
    }
    if (!valid_word_address(address)) {
        return {.fault = RamFault::OutOfRange};
    }
    const auto offset = static_cast<std::size_t>(address - kBaseAddress);
    return {.data = static_cast<std::uint32_t>(bytes_[offset]) |
                    (static_cast<std::uint32_t>(bytes_[offset + 1U]) << 8U) |
                    (static_cast<std::uint32_t>(bytes_[offset + 2U]) << 16U) |
                    (static_cast<std::uint32_t>(bytes_[offset + 3U]) << 24U)};
}

RamWriteResult Ram::write32(const std::uint32_t address, const std::uint32_t value) {
    if ((address & 0x3U) != 0U) {
        return {.fault = RamFault::Misaligned};
    }
    if (!valid_word_address(address)) {
        return {.fault = RamFault::OutOfRange};
    }
    const auto offset = static_cast<std::size_t>(address - kBaseAddress);
    bytes_[offset] = static_cast<std::uint8_t>(value & 0xFFU);
    bytes_[offset + 1U] = static_cast<std::uint8_t>((value >> 8U) & 0xFFU);
    bytes_[offset + 2U] = static_cast<std::uint8_t>((value >> 16U) & 0xFFU);
    bytes_[offset + 3U] = static_cast<std::uint8_t>((value >> 24U) & 0xFFU);
    return {};
}

std::uint8_t Ram::debug_read_byte(const std::uint32_t address) const {
    if (address < kBaseAddress || address > kLastAddress) {
        throw std::out_of_range("RAM debug byte address is outside the Mini32 RAM region");
    }
    return bytes_[static_cast<std::size_t>(address - kBaseAddress)];
}

}  // namespace mini32
