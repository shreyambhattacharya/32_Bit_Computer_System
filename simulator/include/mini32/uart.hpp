#pragma once

#include <cstdint>
#include <functional>

#include "mini32/mmio.hpp"

namespace mini32 {

class Uart {
public:
    using TxCallback = std::function<void(std::uint8_t)>;

    inline static constexpr std::uint32_t kBaseAddress = 0x20000000U;
    inline static constexpr std::uint32_t kSizeBytes = 16U;
    inline static constexpr std::uint32_t kLastAddress = kBaseAddress + kSizeBytes - 1U;

    explicit Uart(TxCallback tx_callback = {});

    [[nodiscard]] MmioReadResult read32(std::uint32_t address) const;
    [[nodiscard]] MmioWriteResult write32(std::uint32_t address, std::uint32_t value);
    void reset();

private:
    [[nodiscard]] static MmioFault validate_address(std::uint32_t address);

    TxCallback tx_callback_;
};

}  // namespace mini32
