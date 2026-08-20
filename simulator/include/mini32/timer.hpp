#pragma once

#include <cstdint>

#include "mini32/mmio.hpp"

namespace mini32 {

class Timer {
public:
    inline static constexpr std::uint32_t kBaseAddress = 0x20000100U;
    inline static constexpr std::uint32_t kSizeBytes = 16U;
    inline static constexpr std::uint32_t kLastAddress = kBaseAddress + kSizeBytes - 1U;

    [[nodiscard]] MmioReadResult read32(std::uint32_t address) const;
    [[nodiscard]] MmioWriteResult write32(std::uint32_t address, std::uint32_t value);
    void retire_tick();
    [[nodiscard]] std::uint32_t counter() const { return counter_; }
    [[nodiscard]] std::uint32_t compare() const { return compare_; }
    [[nodiscard]] bool enabled() const { return enabled_; }
    [[nodiscard]] bool match() const { return enabled_ && counter_ == compare_; }
    void reset();

private:
    [[nodiscard]] static MmioFault validate_address(std::uint32_t address);

    std::uint32_t counter_{};
    std::uint32_t compare_{};
    bool enabled_{};
};

}  // namespace mini32
