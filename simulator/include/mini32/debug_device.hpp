#pragma once

#include <cstdint>

#include "mini32/mmio.hpp"

namespace mini32 {

class DebugDevice {
public:
    inline static constexpr std::uint32_t kBaseAddress = 0x20000300U;
    inline static constexpr std::uint32_t kSizeBytes = 16U;
    inline static constexpr std::uint32_t kLastAddress = kBaseAddress + kSizeBytes - 1U;

    [[nodiscard]] MmioReadResult read32(std::uint32_t address) const;
    [[nodiscard]] MmioWriteResult write32(std::uint32_t address, std::uint32_t value);
    [[nodiscard]] std::uint32_t value() const { return value_; }
    void reset();

private:
    [[nodiscard]] static MmioFault validate_address(std::uint32_t address);

    std::uint32_t value_{};
};

}  // namespace mini32
