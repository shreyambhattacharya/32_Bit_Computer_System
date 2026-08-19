#include "mini32/rom.hpp"

#include <algorithm>
#include <array>
#include <stdexcept>

namespace mini32 {

void Rom::load_bytes(const std::uint32_t address, const std::span<const std::uint8_t> image) {
    if (address > kLastAddress || image.size() > (kSizeBytes - address)) {
        throw std::out_of_range("ROM image does not fit in the Mini32 ROM region");
    }

    const auto offset = static_cast<std::size_t>(address - kBaseAddress);
    std::copy(image.begin(), image.end(), bytes_.begin() + static_cast<std::ptrdiff_t>(offset));
}

void Rom::load32(const std::uint32_t address, const std::uint32_t word) {
    if ((address & 0x3U) != 0U) {
        throw std::invalid_argument("ROM word load requires a 4-byte-aligned address");
    }

    const std::array<std::uint8_t, 4> bytes{
        static_cast<std::uint8_t>(word & 0xFFU),
        static_cast<std::uint8_t>((word >> 8U) & 0xFFU),
        static_cast<std::uint8_t>((word >> 16U) & 0xFFU),
        static_cast<std::uint8_t>((word >> 24U) & 0xFFU),
    };
    load_bytes(address, bytes);
}

RomReadResult Rom::read32(const std::uint32_t address) const {
    if ((address & 0x3U) != 0U) {
        return {.fault = RomFault::Misaligned};
    }
    if (address > kLastAddress || address > kLastAddress - 3U) {
        return {.fault = RomFault::OutOfRange};
    }

    const auto offset = static_cast<std::size_t>(address - kBaseAddress);
    return {
        .data = static_cast<std::uint32_t>(bytes_[offset]) |
                (static_cast<std::uint32_t>(bytes_[offset + 1U]) << 8U) |
                (static_cast<std::uint32_t>(bytes_[offset + 2U]) << 16U) |
                (static_cast<std::uint32_t>(bytes_[offset + 3U]) << 24U),
    };
}

}  // namespace mini32
