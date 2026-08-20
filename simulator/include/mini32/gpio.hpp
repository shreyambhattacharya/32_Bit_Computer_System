#pragma once

#include <cstdint>

#include "mini32/mmio.hpp"

namespace mini32 {

class Gpio {
public:
    inline static constexpr std::uint32_t kBaseAddress = 0x20000200U;
    inline static constexpr std::uint32_t kSizeBytes = 16U;
    inline static constexpr std::uint32_t kLastAddress = kBaseAddress + kSizeBytes - 1U;

    [[nodiscard]] MmioReadResult read32(std::uint32_t address) const;
    [[nodiscard]] MmioWriteResult write32(std::uint32_t address, std::uint32_t value);
    void set_input(std::uint32_t value) { input_ = value; }
    [[nodiscard]] std::uint32_t input() const { return input_; }
    [[nodiscard]] std::uint32_t output() const { return output_; }
    [[nodiscard]] std::uint32_t direction() const { return direction_; }
    void reset();

private:
    [[nodiscard]] static MmioFault validate_address(std::uint32_t address);

    std::uint32_t input_{};
    std::uint32_t output_{};
    std::uint32_t direction_{};
};

}  // namespace mini32
